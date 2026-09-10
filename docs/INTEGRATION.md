# Integração do FB_Sequence — v0.1

## Ponto de partida

O alvo inicial é um projeto de simulação ou demonstração com uma única task
cíclica. A concessão Control de demonstração é um mock explícito, desabilitado
por padrão; não representa autoridade emitida por um Control de aplicação.
Os arquivos ST devem ser incorporados aos objetos correspondentes do
Machine Expert; eles não equivalem a um arquivo nativo `.project` já compilado.
Conservar separadas a declaração e a implementação conforme a forma de importação
do ambiente de destino.

Não existe neste repositório um adaptador físico de equipamentos. A integração
do motor com funções de Control existentes é uma etapa própria, com contrato
e critérios de aceitação definidos pela aplicação.

`src/prg/PRG_Task_Sequence.st` contém o programa de aplicação. Ele chama
`FB_Sequence` uma vez por ciclo e publica suas saídas em
`src/gvl/GVL_SEQ_IF.st`. A GVL começa com `xEnable := FALSE` e campos de
autoridade/feedback sem concessão fabricada. Configurar a identidade de sessão
na inicialização e fornecer `udiDeltaMs` a partir da origem de tempo da aplicação.
Testes e mocks pertencem a `tests`, separados do PRG de aplicação.

## Conectar o Service

Os nomes efetivos e a matriz de escritores estão em
[SERVICE_HANDOFF.md](SERVICE_HANDOFF.md). Este repositório não altera nem
reestrutura o repositório Service.

A Sequence só fornece os payloads públicos enquanto o Control permite a
publicação por `ST_SEQ_CONTROL_AUTHORITY.xAllowPublication`. Sem publicação
válida, o Service não dispõe de um resultado de comando para presumir aceitação
nem de um runtime atual. Deve invalidar sua apresentação e tratar a pendência
no próprio canal. Autorização do usuário pelo Service não substitui essa
concessão operacional do Control.

Retirar apenas a permissão de publicação não equivale a parar o processo: ele
pode continuar se requests/execução seguirem autorizados. Os eventos permanecem
na fila local até consumo permitido, sujeitos à sua capacidade. A supressão
dos contadores públicos não indica que a fila interna esteja vazia.

O Service entrega um pedido completo e coerente: comando, identificação da
origem/execução e os campos exigidos para aquele comando. A receita candidata
deve estar integralmente publicada antes do pedido que solicita sua aplicação.

O Service deve preservar a identidade do pedido durante retransmissões. Um
clique reenviado após perda de comunicação não deve virar um novo `Start`.
Novo pedido e repetição do mesmo pedido são situações distintas.

No contrato atual, o dispatcher único do Service fornece `udiRequestID`
estritamente crescente, sem wrap dentro de `udiSessionID`. Mantém `xValid`
ativo e os campos estáveis até observar `ST_SEQ_COMMAND_RESULT` da mesma sessão
e pedido. Há um slot de pedido e um resultado de admissão, não uma fila de
comandos concorrentes nem um histórico de resultados arbitrários.

A sequência de integração é:

1. Publicar a receita candidata e seus identificadores/revisão.
2. Em `Idle`, entregar `LoadRecipe` e acompanhar o resultado do pedido correspondente.
3. Entregar `Start` com o contexto de execução requerido.
4. Acompanhar estado, fase/etapa e receita aplicada no status.
5. Tratar `Hold`, `Resume`, `Stop`, `Abort` e `ConfirmStep` como pedidos sujeitos
   a validação no estado corrente.
6. Usar o estado terminal e os diagnósticos para reconhecer o encerramento.

Não usar o ACK do canal como confirmação do passo 6. O resultado que aceita
`Stop`, por exemplo, pode anteceder por vários ciclos a entrada em `Stopped`.

`Hold`, `Resume`, `Stop`, `Abort` e `Reset` exigem o lote corrente. `Reset`
com lote zero só se aplica à recuperação sem lote. Para `ConfirmStep`, ecoar
lote, etapa e prompt correntes; o motor ainda verifica feedback e qualificação.
Depois de um estado terminal, usar `Reset` para retornar a `Idle` antes de
carregar outra receita ou iniciar outro lote. O novo `BatchID` deve ser não
nulo e estritamente maior que o último aceito na sessão.

Um buffer de eventos em memória não é um historiador. O consumidor no Service
deve considerar capacidade, consumo e eventual perda conforme o contrato
implementado. Não presumir persistência, entrega exatamente uma vez ou horário
de calendário somente porque existe um evento da Sequence.

## Conectar o Control por um adaptador

Primeiro, o Control fornece `ST_SEQ_CONTROL_AUTHORITY`: contexto, geração,
frescor e permissões separadas para requests, execução e publicação. A Sequence
não escreve nesse grant. Sua revogação é uma decisão do Control, que conserva
a responsabilidade pelas funções de equipamento e pela recuperação da posse.

Durante um lote, a perda de requests/execução ou a mudança de geração da
concessão levam a `Faulted`, sem retomada automática. Se requests continuarem
permitidos ou forem restabelecidos, a Sequence solicita `Abort` e depois
`Release`, exige os results correspondentes e conserva `Faulted` até o `Reset`.
Não usar regrant como substituto de recuperação e novo `Start`.

`ST_SEQ_CONTROL_REQUEST` é escrito pela Sequence. `ST_SEQ_CONTROL_RESULT` é
escrito pelo Control/adaptador que processa essa intenção. O runtime de
equipamentos continua pertencendo ao Control, que fornece à Sequence somente
a projeção `ST_SEQ_CONTROL_RUNTIME` necessária ao processo.

O adaptador conhece o catálogo de `uiPhaseID`/`uiProfileID`. Para cada perfil,
documenta a operação solicitada, sua disponibilidade, o significado da
qualificação, a evidência de conclusão e as políticas de suspensão/encerramento.
Perfil desconhecido deve produzir rejeição/diagnóstico, nunca uma ação implícita.

| Sinal conceitual | Responsabilidade do adaptador |
| --- | --- |
| Aceitação | Indicar se a intenção identificada foi aceita |
| Qualificação | Consolidar as condições válidas para contar tempo da etapa |
| Conclusão | Informar conclusão observada da intenção identificada |
| Suspensão | Informar que a política solicitada de hold foi atingida |
| Encerramento | Informar conclusão da política Complete, Stop ou Abort |
| Recursos | Informar concessão/token e liberação confirmada pelo dono |
| Diagnóstico | Distinguir rejeição, execução com falha e dado inválido |

O feedback precisa corresponder a `SessionID`, `AuthorityID`, `ProcessID`,
`BatchID` e `IntentID`. Quando existe posse, deve corresponder também ao token esperado.
Feedback de intenção antiga não pode encerrar uma intenção nova.

Result e runtime devem corresponder à mesma geração de autoridade da intenção.
Essa regra também vale para `Abort`/`Release` em `Faulted`; um resultado da
geração anterior não pode se combinar com runtime da geração nova para confirmar
a liberação. A nova concessão exige um novo request/result correlacionado.

A contagem qualificada só usa feedback do `Execute` atual. Em `Resume`, o motor
emite uma intenção Execute nova e espera seu feedback; o intervalo anterior em
Hold não entra no tempo qualificado. Cada estado transitório inicia seu próprio
relógio, independentemente do tempo que o lote passou em Running.

No result, `xDone` conclui a **ação de ciclo de execução** solicitada; no runtime,
`xStepComplete` informa a **conclusão da etapa** de processo. `xAccepted` não
substitui nenhum desses sinais. `xReleased` confirma que o contexto não conserva
recursos; não é sinônimo de recepção de um pedido de liberação.

Um adaptador de simulação pode produzir essas respostas para testar a máquina
de estados. Ele deve permanecer identificado como simulação: respostas
simuladas não são evidência de execução dos equipamentos.

## Recursos compartilhados e CIP

A Sequence solicita os recursos de que necessita ao árbitro definido pela
aplicação. O árbitro decide concessão e exclusividade. O token retornado vincula
intenções posteriores à concessão vigente.

Para CIP compartilhado, manter separadas:

- A solicitação da unidade que precisa de limpeza.
- A reserva dos recursos compartilhados.
- A execução do processo pela Sequence responsável pelo CIP.
- A comunicação do resultado e a liberação confirmada.

O transporte do pedido por Service não significa aceitação ou início do CIP.
Timeout, desconexão e reinício exigem reconciliação com o dono do recurso. O
cliente não deve declarar o recurso livre porque deixou de receber mensagens.

## Ordem de execução em uma task

Todos os contratos da demonstração pertencem à mesma task. Uma integração
coerente captura os pedidos, chama a Sequence e depois processa sua intenção no
adaptador; o feedback resultante pode ser consumido no ciclo seguinte. Outra
ordem é possível, mas precisa ser escolhida e documentada de forma consistente.

Essa latência de um ciclo faz parte do modelo e não constitui falha de ACK.
Evitar chamar a mesma instância do FB em mais de uma task ou mais de uma vez por
ciclo sem especificar expressamente o comportamento esperado.

O período fornecido à temporização deve representar o ciclo adotado pela
aplicação. Uma constante de demonstração não mede jitter, atraso de agendamento
ou tempo de calendário. Caso a aplicação precise dessas medições, a integração
deve fornecer uma origem de tempo monotônica apropriada ao ambiente.

## Migração para tasks separadas

O motor não fornece uma primitiva portátil de concorrência. Antes de separar
Service, Sequence e Control em tasks, implementar e revisar:

| Requisito | Evidência necessária |
| --- | --- |
| Um escritor por contrato | Mapa de produtores e consumidores |
| Publicação coerente | Mailbox, troca de buffers ou primitiva da plataforma com semântica comprovada |
| Consumo de pedidos | Retenção e reconhecimento sem depender de pulsos curtos |
| Frescor | Origem de tempo/heartbeat e limite definidos |
| Correlação | Validação de sessão, lote, intenção e concessão |
| Reinício | Nova sessão e reconciliação de pedidos/posses pendentes |
| Autoridade | Concessão Control válida, geração e permissões respeitadas |

Não considerar uma estrutura inteira atômica por ser declarada em uma GVL.
Também não considerar um contador de versão suficiente sem demonstrar o
protocolo completo de publicação e leitura na plataforma utilizada.

O campo `udiAgeMs` em authority, result e runtime é metadado local calculado pelo receptor desde
a observação de uma publicação coerente. Não é uma idade enviada pelo produtor.
O envelope de transporte/mailbox precisa distinguir novas publicações de uma
recópia do mesmo snapshot; recopiá-lo não deve zerar a idade. Essa geração ou
heartbeat de transporte não está incluída no DUT v0.1 e pertence à integração
entre tasks. Todos os demais sinais da projeção têm origem no Control.

## Verificação da integração

Os casos abaixo devem ser executados primeiro com feedback simulado e registros
de comandos, status e intenções. A existência dos casos não significa que todos
já foram executados no Machine Expert.

| Caso | Resultado esperado |
| --- | --- |
| Ausência de concessão Control | Não emitir requests, avançar execução ou expor payloads não autorizados |
| Revogação de publicação | Invalidar/suprimir runtime, resultado e eventos públicos |
| Revogação somente de publicação | Suprimir saídas públicas sem assumir parada do processo |
| Revogação de requests/execução ou nova geração durante lote | Não retomar automaticamente; recuperação explícita |
| Receita inválida ou acima de 16 etapas | Rejeição sem iniciar execução |
| Alteração da candidata durante execução | Receita aplicada permanece inalterada |
| Repetição de um pedido | Ausência de repetição indevida da ação |
| Feedback de lote/intenção anterior | Não permite avanço da execução corrente |
| Perda de qualificação | Não acumula tempo qualificado inválido |
| `Hold` e `Resume` | Estados intermediários e política de tempo respeitados |
| Confirmação fora do contexto | Não conclui indevidamente outra etapa |
| `Stop`/`Abort` sem liberação confirmada | Não declara encerramento/liberação concluídos |
| Reinício com contexto antigo | Não retoma nem executa pedido antigo automaticamente |
| Perfil desconhecido | Rejeição diagnosticável no adaptador |

Registrar separadamente três evidências: revisão estática dos STs, execução de
testes em simulador e compilação/execução no ambiente de destino. Nenhuma delas
deve ser apresentada como se comprovasse as outras.

A tabela de transições e a rastreabilidade dos cenários preparados estão em
[LIFECYCLE.md](LIFECYCLE.md).
