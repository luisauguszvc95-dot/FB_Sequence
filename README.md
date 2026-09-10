# FB_Sequence — base 0.1

Base em Structured Text para uma Sequence subordinada à autoridade do **Control**.
Este repositório contém o motor de sequência, seus contratos e demonstrações offline.
O **Service é desenvolvido em outro repositório**.

**Status:** fontes para revisão e integração. Há verificações estáticas executáveis e
testes ST para o simulador; a compilação no EcoStruxure Machine Expert 2.6 ainda é um gate pendente.
Não é um `.project` nativo nem uma biblioteca compilada. Nenhum arquivo acessa IO físico.

## Fronteiras acordadas

| Componente | É responsável por | Relação com Sequence |
|---|---|---|
| Control | Autoridade, arbitragem, equipamentos, diagnóstico de safety, alarmes de equipamento e runtime correspondente | Concede permissões, consome pedidos no Control IF e publica resultados e runtime |
| Sequence | Ciclo do processo, receita aplicada, etapas, critérios, tempos e ocorrências de processo | Solicita ações e publica somente quando Control permite |
| Service | Entrada de comandos externos, entrega de receita, exposição de dados, transporte de eventos e auditoria | Consome o contrato público autorizado da Sequence |

Diagnóstico de safety não substitui uma função de proteção. A Sequence não concede
permissões a si mesma, não contorna o Control e não escreve estados de equipamentos.

## O que está implementado

- `FB_Sequence`: ciclo Idle / Starting / Running / Holding / Held / Completing / Complete /
  Stopping / Stopped / Aborting / Aborted / Faulted.
- `FB_SEQ_CommandGate`: correlação por sessão, IDs crescentes e proteção contra repetição.
- `FB_SEQ_RecipeValidator`: validação estrutural; receita copiada em LoadRecipe e mantida
  imutável durante o lote. O Control valida os perfis e parâmetros aplicáveis antes de executar.
- `FB_SEQ_QualifiedTimer`: tempo acumulado somente com condições qualificadas; Hold conserva o saldo.
- `FB_SEQ_EventQueue`: 32 ocorrências com ID, snapshot de identidade, ACK e contador de perda.
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

1. [Acordo para o Service](docs/SERVICE_HANDOFF.md): contratos e escritores por campo.
2. [Arquitetura](docs/ARCHITECTURE.md): responsabilidades, ciclo e limitações.
3. [Integração](docs/INTEGRATION.md): correlação, autoridade e snapshots entre tasks.
4. [Importação e demonstração](docs/IMPORT_AND_DEMO.md): organização no IDE e teste offline.
5. [Validação](docs/VALIDATION.md): o que foi verificado e o que falta executar.
6. [Inventário](docs/INVENTORY.md): fontes e dependências geradas.
7. [Roadmap](docs/ROADMAP.md): próximos incrementos sem invadir Service/Control.

## Verificação local

Python 3, biblioteca padrão:

```bash
python3 tools/check_sources.py
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 tools/build_bundle.py
```

O bundle em `build/` é uma conveniência textual; não substitui a compilação no IDE.
Os contratos 0.1 são uma proposta implementada aqui, ainda a alinhar com o adaptador
do Service e com o futuro Control. Não reutilize IDs antigos da IHM sem um mapeamento explícito.
