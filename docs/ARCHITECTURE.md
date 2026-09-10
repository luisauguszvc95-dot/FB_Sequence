# Arquitetura do FB_Sequence — v0.1

## Objetivo e alcance

O `FB_Sequence` coordena a execução de um processo **sob autoridade concedida
pelo Control**: recebe pedidos, aplica uma receita validada e percorre suas
etapas dentro dessa concessão. Só emite requests, avança a execução ou publica
resultados quando a permissão correspondente do Control está válida. Cada
instância representa uma execução de um processo/unidade.

A v0.1 é um motor sequencial **linear, com até 16 etapas**. Cada etapa identifica
sua fase por `uiPhaseID` e seu perfil por `uiProfileID`. O perfil deve ser
interpretado por um adaptador de processo conhecido pelo Control; o número
sozinho não define equipamentos, saídas ou comportamento físico.

Este repositório fornece uma base de software em Structured Text. A compilação
no projeto de destino do EcoStruxure Machine Expert, a integração com os tipos
existentes e a aceitação da aplicação precisam ser verificadas nesse ambiente.
O projeto não declara conformidade ISA/IEC nem constitui lógica de segurança.

## Fronteiras e autoridade

| Camada | O que decide e mantém | O que troca com a Sequence |
| --- | --- | --- |
| Service | Canais de acesso, roteamento, identidade da origem, publicação e persistência externa | Entrega pedidos/receita; consome resultado, status e eventos |
| Sequence | Ciclo de execução, receita aplicada, etapa atual, transições e tempo qualificado, dentro da concessão do Control | Publica intenções autorizadas; consome autoridade e feedback correlacionado |
| Adaptador de processo | Tradução de fase/perfil para as funções já existentes no Control | Interpreta intenções; consolida execução, conclusão e liberação |
| Control | Autoridade operacional, disponibilidade e arbitragem dos equipamentos, funções de equipamento e feedback | Concede/revoga permissões; aceita/rejeita intenções e informa execução real |
| Árbitro de recursos | Único proprietário da concessão de recursos compartilhados | Concede, identifica e confirma liberação da posse |

### Acordo de autoria com o projeto Service

Service e Sequence são desenvolvidos em paralelo. O ponto de integração com o
Control futuro é o **Control IF**, com buffers separados de requests e results.

- Control escreve o runtime de equipamentos, os diagnósticos de dispositivos de
  safety, os alarmes de equipamentos e os estados gerais sob sua autoridade.
- Sequence lê os results do Control IF e uma projeção coerente do runtime
  publicado pelo Control. Escreve somente seus requests no Control IF e seu
  próprio runtime de processo/lote/etapa/temporizadores/ocorrências.
- Service entrega comandos externos e publica os runtimes de seus respectivos
  donos quando autorizados. Não assume a escrita dos estados publicados por
  Control ou Sequence e não concede autoridade operacional à Sequence.

`ST_SEQ_CONTROL_RUNTIME` é uma projeção de leitura para o processo, não uma
segunda base de equipamentos. `ST_SEQ_RUNTIME` é o runtime da Sequence. O
detalhamento dos tipos e escritores está em [SERVICE_HANDOFF.md](SERVICE_HANDOFF.md).

O Service não escolhe a próxima etapa. O Control não escolhe a receita. A
Sequence não escreve I/O, não implementa drivers e não substitui os
permissivos/intertravamentos locais dos equipamentos.

O árbitro de recursos pode ser implementado junto à camada de controle ou em um
módulo operacional próprio. Deve ter um único dono. Cada Sequence é cliente
desse árbitro; duas instâncias não podem conceder o mesmo recurso a si próprias.

## Contratos

| Direção | Conteúdo | Significado |
| --- | --- | --- |
| Service → Sequence | Comando identificado e receita candidata | Pedido sujeito à validação pela Sequence |
| Sequence → Service | Resultado do pedido | Aceitação/rejeição do comando identificado |
| Sequence → Service | Status | Estado observado da execução, receita aplicada e etapa |
| Sequence → Service | Eventos | Mudanças e ocorrências produzidas pela execução |
| Control → Sequence | `ST_SEQ_CONTROL_AUTHORITY` | Concessão vigente para requests, execução e publicação |
| Sequence → Control IF | `ST_SEQ_CONTROL_REQUEST` | Intenção solicitada ao adaptador, identidade e posse associadas |
| Control IF → Sequence | `ST_SEQ_CONTROL_RESULT` | Aceitação, conclusão da ação e liberação correlacionadas |
| Runtime Control → Sequence | `ST_SEQ_CONTROL_RUNTIME` | Projeção de disponibilidade, qualificação, conclusão da etapa e posse |

Os contratos utilizam `SessionID`, `ProcessID`, `BatchID` e `IntentID` para
identificar a execução e a intenção, além de `AuthorityID` para vincular as
trocas à concessão operacional vigente. A concessão de recursos inclui um token.
O adaptador deve devolver as identidades da intenção efetivamente processada e
o token pertinente; não pode apenas copiar as identidades atuais sobre um
resultado antigo.

**Aceitar um pedido não conclui o processo.** O resultado de comando informa a
decisão sobre o pedido; o status informa o ciclo de execução; o feedback do
Control comprova o avanço permitido. Um ACK de HMI, rede ou fila não comprova
a conclusão de uma etapa.

## Autoridade concedida pelo Control

`ST_SEQ_CONTROL_AUTHORITY` é emitida exclusivamente pelo Control. Sua validade
depende de sessão, processo, `udiAuthorityID` não nulo e frescor do dado. A
geração da concessão não deve ser reutilizada dentro da mesma sessão.

| Permissão | Comportamento autorizado |
| --- | --- |
| `xAllowRequests` | Emissão de requests no Control IF |
| `xAllowExecution` | Avanço da execução da Sequence |
| `xAllowPublication` | Exposição de runtime, resultado de comando e eventos ao Service |

Sem permissão válida, a Sequence não fabrica uma concessão nem usa a aceitação
de um comando externo como substituta. A perda da autorização de publicação
suprime/invalida os payloads públicos; o diagnóstico permanece no estado
interno do FB. O Service deve tratar a invalidez como indisponibilidade do dado,
sem reapresentar a última imagem como se ainda fosse atual/autorizada.

Revogar apenas `xAllowPublication` suprime a publicação; a execução pode
continuar se as demais permissões e condições permanecerem válidas. O avanço
exige simultaneamente `xAllowRequests` e `xAllowExecution`.

Revogar requests/execução, invalidar a concessão ou trocar sua geração durante
uma execução interrompe o avanço e leva a um estado interno de falha. A volta
de uma concessão não retoma automaticamente a receita:
recuperação exige `Reset` e um novo `Start` após resolver o contexto pendente.
Requests de encerramento também dependem de `xAllowRequests`; se essa
permissão for revogada, o Control é responsável por sua própria política de
tratamento das funções e recursos sob sua autoridade.

Em `Faulted`, a Sequence pode solicitar `Abort` e depois `Release` quando o
Control permite requests. Exige confirmação correlacionada das duas ações e
permanece em `Faulted` após a liberação; somente um `Reset` admitido retorna a
`Idle`. A restituição das permissões, isoladamente, nunca faz essa recuperação.

A autoridade operacional e o token de recursos são conceitos separados. Ter
permissão para pedir uma operação não significa já possuir os recursos.

## Receita e etapas

A receita candidata e a receita aplicada são conceitos diferentes. A Sequence
valida a candidata e mantém uma cópia interna para a execução. Alterações no
buffer externo não devem alterar parâmetros de uma execução já iniciada.
`LoadRecipe` só é admitido em `Idle`. O runtime identifica a receita aplicada,
incluindo sua revisão. Cada evento congela o contexto de processo/lote,
receita/revisão e concessão no momento da sua produção, permitindo que o
Service receba o evento depois sem associá-lo indevidamente ao contexto atual.

`FB_SEQ_RecipeValidator` faz validação estrutural: identificadores não nulos,
cardinalidade, identidade de etapa sem duplicação, critério conhecido e limites
de tempo coerentes. Não aprova os parâmetros para uma máquina. Perfis, unidades,
faixas, relações entre parâmetros e valores REAL não finitos devem ser tratados
pelo adaptador Control IF responsável pelo perfil.

Cada etapa seleciona um critério de término:

| Critério | Uso | Evidência necessária |
| --- | --- | --- |
| `WaitQualified` | Acumular duração válida da etapa | Feedback correspondente e condições qualificadas pelo adaptador |
| `WaitComplete` | Aguardar conclusão da operação | Feedback de conclusão da intenção corrente |
| `WaitOperator` | Aguardar confirmação externa | Pedido `ConfirmStep` válido para o contexto corrente |

Uma confirmação do operador autoriza o comportamento previsto na sequência;
ela não substitui feedback de equipamento nem uma proteção local.

Os três critérios dependem de feedback correlacionado. `WaitComplete` também
exige qualificação, e `WaitOperator` exige lote, etapa e `PromptID` correntes,
além da qualificação. Não basta escrever uma flag de confirmação sem contexto.

O tempo qualificado representa somente o intervalo em que as condições exigidas
pela etapa são consideradas válidas. Timeout de espera, tempo total do lote e
tempo qualificado são medidas distintas. A política de pausa e de perda de
qualificação deve ser explícita no código e no perfil de processo.

No contrato atual, `udiTimeoutMs` mede o tempo ativo da etapa, inclui intervalos
de `Running` sem qualificação e exclui `Held`. `udiQualifiedMs` é a duração alvo
do critério `WaitQualified`. O runtime expõe `udiStepElapsedMs`,
`udiQualifiedElapsedMs` e `udiStateElapsedMs`; não há um totalizador de duração
de lote nesta v0.1.

`FB_SEQ_QualifiedTimer` conserva o acumulado quando desabilitado ou sem
qualificação; o reset prevalece e zera o valor. A v0.1 implementa, portanto,
tempo qualificado acumulado, não uma exigência genérica de duração contínua.
Uma fase que exija reiniciar a contagem a cada perda de condição precisa dessa
política explicitamente implementada.

O motor só acrescenta o delta ao tempo qualificado quando a qualificação
corrente e a do ciclo anterior são válidas. Isso evita atribuir todo o último
intervalo a uma condição que acabou de aparecer; continua sendo uma avaliação
discreta do software, não uma medição contínua entre amostras.

## Ciclo de execução

O estado do ciclo de execução é independente da fase e da etapa. Os comandos
são `None`, `LoadRecipe`, `Start`, `Hold`, `Resume`, `Stop`, `Abort`, `Reset` e
`ConfirmStep`.

| Estado | Interpretação |
| --- | --- |
| `Idle` | Instância sem execução ativa |
| `Starting` | Preparação e obtenção das condições de início |
| `Running` | Avaliação e execução das etapas |
| `Holding` | Pedido de suspensão em andamento |
| `Held` | Suspensão confirmada conforme política do adaptador |
| `Completing` | Encerramento normal e liberação em andamento |
| `Complete` | Encerramento normal confirmado |
| `Stopping` | Encerramento solicitado por Stop em andamento |
| `Stopped` | Encerramento por Stop confirmado |
| `Aborting` | Política de aborto em andamento |
| `Aborted` | Encerramento por Abort confirmado |
| `Faulted` | Falha que impede a execução normal; diagnóstico exige tratamento |

`Hold` admite retomada conforme as condições da execução. `Stop` solicita
encerramento ordenado. `Abort` solicita a política de aborto implementada pelo
adaptador. Esses comandos não têm uma interpretação física universal.

`Completing`, `Stopping` e `Aborting` são estados de espera reais. A passagem ao
estado terminal depende de feedback correspondente e liberação confirmada dos
recursos. Um timeout não constitui confirmação de liberação.

O significado de `Faulted` também não é “equipamentos parados”. Enquanto houver
posse ou uma intenção sem conclusão, a aplicação deve conservar esse contexto e
tratar a recuperação pelo contrato. `Reset` não pode fabricar feedback nem
autorizar nova execução sobre uma posse ainda não resolvida.

`Hold`, `Resume`, `Stop`, `Abort` e `Reset` devem referenciar o `BatchID`
corrente. `Reset` com lote zero só se aplica à recuperação de uma instância que
não tem lote. `Start` é admitido apenas em `Idle` e exige um lote não nulo,
estritamente maior que o último lote aceito na sessão.

`udiTransitionTimeoutMs` limita a permanência em `Starting`, `Holding`,
`Completing`, `Stopping` e `Aborting`, além da espera por feedback correlacionado
nos estados ativos. Trocar a ação de encerramento para `Release` não reinicia o
tempo do estado. `Faulted` não ganha um encerramento fictício quando esse prazo
passa: a confirmação real e a recuperação continuam necessárias.

## Organização e evolução

O conjunto mínimo separa os tipos públicos, a temporização qualificada, o motor
de execução e um programa de demonstração. No crescimento da aplicação, podem
ser extraídos módulos de validação de comandos, receita, ciclo de execução,
recursos, eventos e fases sem mudar a fronteira pública.

O ponto de aplicação é `PRG_Task_Sequence`, que chama uma instância do motor e
troca seus contratos por `GVL_SEQ_IF`. Testes e mocks ficam em `tests`; não
fazem parte do adaptador Control de uma aplicação.

Não fazem parte desta v0.1:

- GRAFCET/SFC arbitrário, bifurcações, paralelismo ou etapas hierárquicas.
- Implementação de controle de motores, válvulas, aquecimento ou I/O.
- Gerenciador de recursos de planta ou sequenciador CIP completo.
- Persistência e retomada automática de lote após reinício.
- Historiador, MQTT, driver HMI, catálogo central de alarmes ou autenticação.
- Camada portátil de sincronização entre tasks.

Alarme de equipamento nasce no Control; condição de processo nasce na Sequence;
falha de canal nasce no Service. A exposição comum desses diagnósticos pelo
Service não transfere a ele a autoridade sobre a condição de origem.

## Concorrência

A demonstração usa uma única task cíclica. Isso permite definir uma ordem de
chamada e a visibilidade dos buffers sem presumir cópia atômica entre tasks.

Na integração com tasks separadas, cada contrato precisa de um único escritor
e de uma mailbox/sincronização adequada à plataforma. São necessários snapshots
coerentes, identificação da geração da publicação, critério de frescor e
política de reinício. Um campo de sequência isolado ou uma atribuição de uma
estrutura ST não prova atomicidade.

Pedidos não devem depender de um pulso de um scan ser observado por outra task.
O canal precisa preservar o pedido e sua identidade até o consumo reconhecido.

## Referência de sintaxe

A sintaxe dos enums e dos atributos `qualified_only`/`strict` pode ser
consultada na documentação oficial de
[Enumeration — CODESYS](https://content.helpme-codesys.com/en/CODESYS%20Development%20System/_cds_datatype_enum.html),
consultada em 10/09/2026. As fronteiras e decisões deste repositório são uma
proposta de arquitetura própria; essa referência não certifica a arquitetura
nem comprova compilação no Machine Expert.
