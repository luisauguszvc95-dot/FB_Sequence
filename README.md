# FB_Sequence — contrato 0.2 de rastreabilidade

Base em Structured Text para uma Sequence subordinada à autoridade do **Control**.
Este repositório contém o motor de sequência, seus contratos e demonstrações offline.
O **Service é desenvolvido em outro repositório**.

**Status:** revisão preparada para testes isolados. Há verificações estáticas executáveis e
testes ST para o simulador; compilação e execução desta revisão 0.2 no
EcoStruxure Machine Expert 2.6 ainda são gates pendentes. Resultados relatados
para a base anterior não validam automaticamente esta alteração.
Não é um `.project` nativo nem uma biblioteca compilada. Nenhum arquivo acessa IO físico.

## Fronteiras acordadas

| Componente | É responsável por | Relação com Sequence |
|---|---|---|
| Control | Autoridade, arbitragem, equipamentos, diagnóstico de safety, alarmes de equipamento e runtime correspondente | Concede permissões, consome pedidos no Control IF e publica resultados e runtime |
| Sequence | Ciclo do processo, receita aplicada, etapas, critérios, tempos e ocorrências de processo | Solicita ações e publica somente quando Control permite |
| Service v0.2 | Observação, normalização e exposição de fatos para consumidores externos | Recebe uma projeção autorizada; não despacha comandos nem armazena receitas nesta referência |
| Integração externa futura | Dispatcher de comandos, catálogo de receitas e recibo de posse dos eventos completos | Um escritor por canal, sem assumir a autoridade do Control |

Diagnóstico de safety não substitui uma função de proteção. A Sequence não concede
permissões a si mesma, não contorna o Control e não escreve estados de equipamentos.

## O que está implementado

- `FB_Sequence`: ciclo Idle / Starting / Running / Holding / Held / Completing / Complete /
  Stopping / Stopped / Aborting / Aborted / Faulted.
- `FB_SEQ_CommandGate`: correlação por sessão, IDs crescentes e proteção contra repetição.
- `FB_SEQ_RecipeValidator`: validação estrutural; receita copiada em LoadRecipe e mantida
  imutável durante o lote. O Control valida os perfis e parâmetros aplicáveis antes de executar.
- `FB_SEQ_QualifiedTimer`: tempo acumulado somente com condições qualificadas; Hold conserva o saldo.
- `FB_SEQ_EventQueue`: 32 ocorrências com snapshot imutável, ACK e contador de perda;
  fila cheia descarta o novo evento. A fila é volátil, não um historiador.
- Eventos 0.2: identidade do produtor/máquina, tempo de origem e sua qualidade,
  contexto anterior, receita/lote pedidos e aplicados, intenção, recurso e prompt.
- Runtime 0.2: revisão de publicação, contexto de tempo, `xTraceReady` e
  `xTraceHistoryComplete`. Nenhum destes sinais certifica persistência ou auditoria completa.
- `F_SEQ_AddMs`: soma de milissegundos com saturação.
- `GVL_SEQ_IF` e `PRG_Task_Sequence`: ponto de integração dos contratos.
- Mock de Control, demonstração e POUs de testes em `tests/`, sem dependência de hardware.

Uma instância executa **um processo, um lote ativo e até 16 etapas lineares**.
Cada etapa tem `StepID`, `PhaseID`, `ProfileID` e um critério: tempo qualificado,
conclusão pelo Control ou confirmação correlacionada do operador.
O comportamento de cada perfil pertence ao adaptador da máquina no Control IF.

## Autoridade do Control

`ST_SEQ_CONTROL_AUTHORITY` identifica sessão, processo, geração da concessão e frescor.

| Permissão do Control | Efeito |
|---|---|
| `xAllowRequests` | Permite entregar um pedido válido ao Control IF |
| `xAllowExecution` | Junto com pedidos autorizados, permite executar/avançar a sequência |
| `xAllowPublication` | Permite expor runtime de processo, resultado de comando e eventos ao Service |

Sem concessão válida, saem envelopes vazios/inválidos. Revogar apenas publicação
oculta os dados públicos; as outras permissões continuam independentes.
Perder autorização de pedidos/execução ou trocar a geração durante um lote trava
Faulted. Reautorizar não retoma o lote automaticamente. Encerramento depende de
pedidos autorizados e respostas do Control; depois são necessários Reset e novo Start.
O Control precisa conferir a autorização novamente ao consumir cada pedido.

## Comece por estes arquivos

Para testar a revisão 0.2 pelo efeito de cada entrada, use o
[Manual de testes do FB_Sequence](docs/MANUAL_TESTES.md): 80 fichas com
um diagrama por teste, índices por componente e tipo, glossário e quatro
Watches da demonstração isolada. O PDF é específico da Sequence com seu
ControlMock; sua publicação registra expectativas e não declara os ensaios executados.

1. [Acordo para o Service](docs/SERVICE_HANDOFF.md): contratos e escritores por campo.
2. [Arquitetura](docs/ARCHITECTURE.md): responsabilidades, ciclo e limitações.
3. [Integração](docs/INTEGRATION.md): correlação, autoridade e snapshots entre tasks.
4. [Importação e demonstração](docs/IMPORT_AND_DEMO.md): organização no IDE e teste offline.
5. [Validação](docs/VALIDATION.md): o que foi verificado e o que falta executar.
6. [Inventário](docs/INVENTORY.md): fontes e dependências geradas.
7. [Roadmap](docs/ROADMAP.md): próximos incrementos sem invadir Service/Control.

## Evolução 0.2 e contrato com Service

Consulte [ciclo completo](docs/LIFECYCLE.md) e [alinhamento normativo](docs/STANDARDS_ALIGNMENT.md).
Esta revisão preserva o endurecimento de timeout de encerramento, correlação de
autoridade, qualificação após Resume e contexto de Reset da base `0480b33`.
Amplia o schema para 0.2; enums existentes conservam seus valores, mas layouts
binários antigos não são compatíveis por presunção.

A referência real de Service é a branch `refactor/service-core-v0.2`, commit
`b2140a5ab4756f1c435ebcf7848270dad2f097d5` (schema de transporte Service **2.0**).
Ela é de observação: não contém o
dispatcher antigo nem `ST_SVC_SequenceSnapshot`. A projeção opcional em
`integration/service_v02/` conserva o `ST_SEQ_EVENT` completo ao lado da visão
genérica parcial `ST_SVC_EventInput`. Sem recibo explícito da posse do envelope
completo, não há ACK para retirar o evento da Sequence.

O [contrato do adaptador](integration/service_v02/README.md) registra também a
lacuna de ingestão do Service: observar/deduplicar um evento não demonstra sua
entrada no outbox. A ligação automática permanece bloqueada até haver retenção
integral e recibo transacional definidos.

**Integração ainda não concluída.** A ordem permanece: Sequence isolada → Service
isolado → integração dos dois → futuro `FB_Central_Cip_Control`. Hoje é preparação;
nenhuma nova execução no IDE está sendo atribuída ao usuário.

Leia [migração 0.1 → 0.2](docs/MIGRATION_0_2.md) antes de atualizar os objetos.
Os quatro Watches existentes são preservados.

## Verificação local

Python 3, biblioteca padrão:

```bash
python3 tools/check_sources.py
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 tools/build_bundle.py
```

O bundle em `build/` é uma conveniência textual; não substitui a compilação no IDE.
O contrato 0.2 prepara rastreabilidade de origem. Persistência, autenticação,
retenção, reconciliação e integração real ainda exigem evidência própria.
Não reutilize IDs antigos da IHM sem um mapeamento explícito.


## Revisão dos diagramas

Os 80 diagramas do manual atual foram redesenhados para melhorar leitura, setas e ramificações. Consulte a [revisão visual](docs/manuals/FB_Sequence/REVISAO_VISUAL.md) e o [PDF atualizado](docs/manuals/FB_Sequence/manual.pdf).
