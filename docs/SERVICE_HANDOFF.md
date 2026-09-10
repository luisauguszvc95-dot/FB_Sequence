# Acordo de integração Sequence ↔ Service ↔ Control IF

## Finalidade

Este documento permite desenvolver Service e Sequence em repositórios separados
sem duplicar autoridade sobre comandos ou runtimes. A referência dos campos é
o conjunto de tipos em [`src/dut`](../src/dut). Os valores numéricos de enums
também fazem parte do contrato.

A Sequence mantém a execução do processo **sob autoridade operacional do
Control**. O Control futuro é dono do runtime dos equipamentos, diagnósticos de
dispositivos de safety, alarmes de equipamentos e estados gerais sob sua
responsabilidade. A Sequence consome a concessão de autoridade, uma projeção
desse runtime e os results do Control IF. Só escreve requests, avança e publica
se o Control permitir a respectiva ação. O Service recebe comandos externos,
encaminha pedidos e publica os dados disponibilizados por seus donos.

## Regra de autoridade

O único emissor da concessão `ST_SEQ_CONTROL_AUTHORITY` é o Control. A Sequence
verifica contexto, geração e frescor, e usa separadamente `xAllowRequests`,
`xAllowExecution` e `xAllowPublication`. Permissão de publicar não concede posse
de equipamento; posse não autoriza publicação ou avanço sem a concessão válida.

Sem permissão de publicação, runtime, resultado e eventos destinados ao Service
são suprimidos/invalidados. O Service não deve continuar expondo a última imagem
como atual. O diagnóstico interno da Sequence não é uma rota alternativa para
publicar quando o Control proibiu essa publicação.

Revogar somente publicação suprime os payloads; a execução pode continuar
enquanto requests e execução continuarem autorizados. O avanço requer essas
duas permissões simultaneamente.

Revogar requests/execução ou trocar a geração da concessão durante execução
deixa falha interna e impede retomada automática.
Depois de restabelecer a concessão e resolver a situação pendente, são exigidos
`Reset` e novo `Start`. Requests de encerramento só podem sair enquanto
`xAllowRequests` estiver válida. O Control conserva sua política própria de
tratamento dos equipamentos e recursos ao revogar a autoridade.

Em `Faulted`, a Sequence solicita `Abort` e, após sua conclusão, `Release` se
requests forem permitidos. A liberação confirmada não limpa a falha nem retoma
a receita: o estado permanece até `Reset` e um novo `Start` admitidos.

## Versão e compatibilidade

O contrato inicial é **0.1**, informado por `ST_SEQ_RUNTIME.uiContractMajor` e
`uiContractMinor`. O número descreve a versão dos tipos e de sua semântica; ele
não comprova atomicidade, frescor nem compatibilidade binária de structs.

Proposta de trabalho entre os repositórios:

1. Usar os mesmos DUTs/enums da revisão acordada, com referência ao commit de
   origem ao incorporá-los no outro projeto.
2. Não renumerar enums, trocar tipos ou reinterpretar campos sem revisar a
   interface dos dois consumidores.
3. Tratar alteração incompatível como mudança de versão major. Documentar
   mudança aditiva como minor somente quando a estratégia de transporte
   realmente permitir a compatibilidade; não presumir isso para memória crua.
4. O adaptador Service verifica a versão publicada antes de habilitar seu
   mapeamento. O request atual não carrega uma versão negociada própria.
5. Transportes HMI/Ethernet/MQTT definem seu próprio mapeamento. Não transmitir
   a representação binária da struct ST sem especificar tipos, ordem de bytes,
   tamanho e coerência da publicação.

Essas regras são o acordo de integração proposto. Esta v0.1 não implementa
negociação dinâmica de schema nem gera o mapeamento de endereços do Service.

## Escritores e consumidores

Cada campo listado pertence ao escritor da linha. Campos de correlação copiados
para um result continuam sendo escritos pelo produtor desse result; o receptor
nunca os preenche retroativamente.

| Contrato/buffer | Escritor único | Consumidor |
| --- | --- | --- |
| `ST_SEQ_COMMAND_REQUEST` | Dispatcher do Service | Sequence |
| `ST_SEQ_RECIPE`, candidata | Publicador de receita do Service | Sequence |
| Receita aplicada interna | Sequence, por cópia validada | Motor de etapas |
| `ST_SEQ_COMMAND_RESULT` | Sequence | Service |
| `ST_SEQ_RUNTIME` | Sequence | Service e outros leitores |
| `ST_SEQ_EVENT` | Sequence | Consumidor de eventos no Service |
| ACK público, `udiEventAckSessionID`/`udiEventAckID` | Consumidor do Service | Sequence, que encaminha à fila interna |
| `ST_SEQ_CONTROL_AUTHORITY`, sinais publicados | Control | Sequence |
| `ST_SEQ_CONTROL_AUTHORITY.udiAgeMs`, cópia local | Receptor/mailbox na task consumidora | Sequence |
| `ST_SEQ_CONTROL_REQUEST` | Sequence | Control IF/adaptador |
| `ST_SEQ_CONTROL_RESULT`, sinais publicados | Control IF/adaptador | Sequence |
| `ST_SEQ_CONTROL_RESULT.udiAgeMs`, cópia local | Receptor/mailbox na task consumidora | Sequence |
| `ST_SEQ_CONTROL_RUNTIME`, sinais publicados | Control/adaptador de projeção | Sequence |
| `ST_SEQ_CONTROL_RUNTIME.udiAgeMs`, cópia local | Receptor/mailbox na task consumidora | Sequence |
| `ST_SEQ_CONFIG` | Inicialização da aplicação | Sequence |

### Ligação no programa: `GVL_SEQ_IF`

`PRG_Task_Sequence` chama a instância `fbSequence` e copia suas saídas para a
GVL. Essa cópia é a publicação da Sequence; não cria um segundo dono semântico.
O programa não fabrica autoridade nem feedback do Control.

| Campo da GVL | Escritor único | Contrato/uso |
| --- | --- | --- |
| `stConfig` | Inicialização da aplicação | `ST_SEQ_CONFIG`, estável na vida da instância |
| `xEnable` | Integração da aplicação | Habilitação local; não concede autoridade Control |
| `udiDeltaMs` | Integração/origem de tempo | Delta monotônico validado do ciclo |
| `stCommand` | Dispatcher do Service | `ST_SEQ_COMMAND_REQUEST` |
| `stRecipeCandidate` | Publicador de receita do Service | `ST_SEQ_RECIPE` |
| `udiEventAckSessionID` | Consumidor do Service | Sessão do evento assumido pelo consumidor |
| `udiEventAckID` | Consumidor do Service | ID do evento assumido pelo consumidor |
| `stAuthority` | Receptor Control IF | Snapshot de `ST_SEQ_CONTROL_AUTHORITY` |
| `stControlResult` | Receptor Control IF | Snapshot de `ST_SEQ_CONTROL_RESULT` |
| `stControlRuntime` | Receptor Control IF | Projeção de `ST_SEQ_CONTROL_RUNTIME` |
| `stControlRequest` | PRG/Sequence | `ST_SEQ_CONTROL_REQUEST` autorizado |
| `stRuntime` | PRG/Sequence | `ST_SEQ_RUNTIME` publicável |
| `stCommandResult` | PRG/Sequence | `ST_SEQ_COMMAND_RESULT` publicável |
| `xEventAvailable` | PRG/Sequence | Cabeça disponível e publicação permitida |
| `stEvent` | PRG/Sequence | Cabeça da fila, `ST_SEQ_EVENT` |
| `uiEventCount` | PRG/Sequence | Contagem da fila exposta quando autorizada |
| `udiEventsDropped` | PRG/Sequence | Contador de perdas exposto quando autorizado |

Nos snapshots recebidos, os sinais têm autoria no Control e `udiAgeMs` tem
autoria no receptor. A mailbox publica a cópia completa de modo coerente na
task da Sequence; não divide uma mesma struct compartilhada entre escritores
concorrentes. A demonstração usa uma task, sem implementar essa mailbox.

### Service → Sequence: `ST_SEQ_COMMAND_REQUEST`

Todos os campos deste buffer são escritos somente pelo dispatcher do Service.

| Campo | Significado |
| --- | --- |
| `xValid` | Pedido completo disponível; manter até seu resultado de admissão |
| `udiSessionID` | Sessão da instância de destino |
| `udiRequestID` | Identificador crescente do dispatcher, sem wrap na sessão |
| `uiSourceID` | Origem para auditoria; autorização fica no Service |
| `uiProcessID` | Processo de destino |
| `eCommand` | Comando de `E_SEQ_CMD` |
| `udiBatchID` | Identidade do lote requerida pelo comando |
| `udiRecipeID` | Referência da receita requerida pelo comando |
| `udiRecipeRevision` | Revisão da receita requerida pelo comando |
| `uiStepID` | Contexto da etapa, quando aplicável |
| `udiPromptID` | Identidade da confirmação solicitada, quando aplicável |

O Service serializa as origens HMI, supervisório e outras num único dispatcher
por instância. Dois produtores não escrevem esse slot diretamente. Uma
retransmissão conserva o mesmo pedido e os mesmos campos; um novo comando
recebe um novo identificador. Não substituir um pedido pendente antes de seu
resultado correspondente.

`LoadRecipe` e `Start` só são admitidos em `Idle`. `Start` exige receita/revisão
aplicadas e lote não nulo, crescente na sessão. `Hold`, `Resume`, `Stop`,
`Abort` e `Reset` devem ecoar o lote corrente; lote zero em `Reset` só é válido
quando a instância não possui lote. `ConfirmStep` também exige etapa e prompt
correntes, além do feedback qualificado.

Uma confirmação só é admitida enquanto o feedback corresponde à intenção `Execute`
da etapa atual, com `xReady`, qualificação e token de recurso válidos. Ao retomar
de `Held`, o Service deve aguardar a execução corrente; o ACK anterior de `Hold`
não comprova retomada. O PromptID identifica a mesma etapa durante Hold/Resume.

### Receita candidata: `ST_SEQ_RECIPE` e `ST_SEQ_STEP`

Todos os campos da candidata são escritos pelo publicador de receita do Service.
A cópia interna aplicada pertence à Sequence e não deve ser exposta como buffer
de escrita externa.

| Tipo | Campo | Significado |
| --- | --- | --- |
| `ST_SEQ_RECIPE` | `udiRecipeID` | Identidade da receita |
| `ST_SEQ_RECIPE` | `udiRevision` | Revisão da candidata |
| `ST_SEQ_RECIPE` | `uiStepCount` | Quantidade de etapas, entre 1 e 16 |
| `ST_SEQ_RECIPE` | `astSteps` | Array `[1..16]` de `ST_SEQ_STEP` |
| `ST_SEQ_STEP` | `uiStepID` | Identidade da etapa |
| `ST_SEQ_STEP` | `uiPhaseID` | Identidade da fase |
| `ST_SEQ_STEP` | `uiProfileID` | Perfil conhecido pelo adaptador Control IF |
| `ST_SEQ_STEP` | `eKind` | `WaitQualified`, `WaitComplete` ou `WaitOperator` |
| `ST_SEQ_STEP` | `udiQualifiedMs` | Duração qualificada alvo |
| `ST_SEQ_STEP` | `udiTimeoutMs` | Limite do tempo ativo da etapa |
| `ST_SEQ_STEP` | `rParameter1` | Parâmetro de demonstração definido pelo perfil |
| `ST_SEQ_STEP` | `rParameter2` | Parâmetro de demonstração definido pelo perfil |

`rParameter1` e `rParameter2` não são um modelo completo de parâmetros de receita.
A integração precisa documentar nome, unidade, domínio e significado por perfil.
O contrato não deve adivinhar esses significados pela posição do parâmetro.

### Sequence → Service: `ST_SEQ_COMMAND_RESULT`

Todos os campos são escritos somente pela Sequence.

| Campo | Significado |
| --- | --- |
| `xValid` | Resultado disponível |
| `udiSessionID` | Sessão do pedido avaliado |
| `udiRequestID` | Pedido avaliado |
| `uiSourceID` | Origem do pedido avaliado |
| `uiProcessID` | Processo de destino |
| `eCommand` | Comando avaliado |
| `eResult` | `Accepted` ou `Rejected`; resultado de admissão |
| `eReason` | Motivo da decisão |
| `eStateAfter` | Estado ao produzir o resultado; não substitui o status corrente |

`Accepted` **não significa lote/etapa concluído**. Não há enum `Completed` no
resultado de comando desta versão. Acompanhar o runtime para observar a
execução posterior e o encerramento.

### Sequence → Service: `ST_SEQ_RUNTIME`

Todos os campos são escritos somente pela Sequence.

| Campo | Significado |
| --- | --- |
| `xDataValid` | Runtime publicável segundo a instância |
| `uiContractMajor` | Versão major do contrato |
| `uiContractMinor` | Versão minor do contrato |
| `uiProcessID` | Processo |
| `udiSessionID` | Sessão da instância |
| `udiAuthorityID` | Concessão Control associada ao runtime publicado |
| `eState` | Estado do ciclo de execução |
| `eReason` | Motivo/diagnóstico da Sequence |
| `xRecipeLoaded` | Existência de receita aplicada |
| `udiRecipeID` | Receita aplicada |
| `udiRecipeRevision` | Revisão aplicada |
| `udiBatchID` | Lote |
| `uiStepIndex` | Posição da etapa na receita |
| `uiStepCount` | Quantidade de etapas aplicadas |
| `uiStepID` | Identidade da etapa |
| `uiPhaseID` | Identidade da fase |
| `udiStepElapsedMs` | Tempo ativo acumulado da etapa |
| `udiQualifiedElapsedMs` | Tempo qualificado acumulado |
| `udiStateElapsedMs` | Tempo acumulado no estado corrente |
| `xWaitingOperator` | Confirmação externa pendente |
| `udiPromptID` | Identidade do prompt corrente |
| `udiResourceToken` | Concessão associada à execução |
| `udiLastControlIntentID` | Última intenção publicada ao Control IF |
| `uiControlReasonID` | Motivo recebido do Control |

O Service pode criar uma imagem de publicação própria, preservando os valores
e a autoria. Não deve escrever `eState`, zerar temporizadores ou editar
`udiPromptID` no runtime da Sequence para comandá-la.

### Sequence → Service: `ST_SEQ_EVENT`

Todos os campos são escritos somente pela Sequence.

| Campo | Significado |
| --- | --- |
| `udiEventID` | Identificador do evento dentro da sessão |
| `udiSessionID` | Sessão de origem |
| `udiAuthorityID` | Geração da concessão registrada na produção do evento |
| `uiProcessID` | Processo de origem |
| `udiBatchID` | Lote associado |
| `udiRecipeID` | Receita aplicada no contexto do evento |
| `udiRecipeRevision` | Revisão aplicada no contexto do evento |
| `eKind` | Mudança de estado/etapa, resultado de comando ou carga de receita |
| `eState` | Estado registrado no evento |
| `uiStepID` | Etapa registrada no evento |
| `udiRequestID` | Pedido associado quando aplicável |
| `udiCommandSessionID` | Sessão do pedido associado; pode diferir da sessão de origem se o pedido foi rejeitado |
| `uiSourceID` | Origem do pedido associado quando aplicável |
| `eCommand` | Comando associado quando aplicável |
| `eCommandResult` | Resultado de admissão quando aplicável |
| `eReason` | Motivo registrado |

O Service acrescenta timestamps de recebimento/persistência em seu próprio
envelope, sem preencher retroativamente a struct de origem. A chave de
deduplicação de eventos inclui processo, sessão e ID do evento. A v0.1 não
fornece por si um log persistente ou um horário de calendário do fato.

Receita/revisão, concessão e contexto do comando ficam congelados no evento.
Usar esses campos para o histórico, sem associar um evento antigo ao runtime
atual. `udiSessionID` identifica a origem do evento; `udiCommandSessionID`
identifica o pedido avaliado e preserva a explicação de uma rejeição por sessão
incorreta. Os campos de comando são preenchidos nos eventos `CommandResult`.

Ao aceitar `Reset`, o runtime passa a `Idle` e `udiBatchID = 0`. Os eventos dessa
operação conservam o lote que foi encerrado/resetado. Não substituir esse BatchID
pelo valor do runtime atual ao persistir o evento.

A fila interna tem 32 posições e expõe a cabeça para consumo. Seu consumidor
escreve `udiEventAckSessionID` e `udiEventAckID` somente após assumir a
responsabilidade pelo evento exposto no processo correspondente. A Sequence
valida a sessão e a permissão de publicação antes de encaminhar o ID ao
`udiAckEventID` da fila interna. O ACK repetido não
deve consumir outra identidade. A política de fila cheia é descartar o evento
novo e contabilizar a perda; os eventos mais antigos não confirmados são
preservados. Limpar ACKs antigos ao iniciar uma nova sessão. Esses sinais só
podem ser consumidos/publicados através da saída autorizada da Sequence.

A revogação de publicação não apaga a fila interna nem permite consumi-la pelo
ACK. Enquanto revogada, o Service recebe payloads vazios e contadores públicos
zerados; isso não prova fila interna vazia. Depois do restabelecimento da
publicação, o consumo pode continuar, sujeito às perdas de capacidade já
registradas pelo produtor.

### Control → Sequence: `ST_SEQ_CONTROL_AUTHORITY`

O Control é o único emissor dos sinais de concessão. A idade é metadado
calculado na cópia local do receptor, como nas outras projeções recebidas.

| Campo | Escritor/origem | Significado |
| --- | --- | --- |
| `xValid` | Control | Concessão publicada válida |
| `udiSessionID` | Control | Sessão da Sequence autorizada |
| `uiProcessID` | Control | Processo autorizado |
| `udiAuthorityID` | Control | Geração não nula da concessão; não reutilizar na sessão |
| `udiAgeMs` | Receptor/mailbox local | Idade desde nova publicação coerente observada |
| `xAllowRequests` | Control | Permissão de emitir requests ao Control IF |
| `xAllowExecution` | Control | Permissão de avançar a execução |
| `xAllowPublication` | Control | Permissão de publicar runtime, resultado e eventos |

Os três canais de recepção — authority, result e runtime — exigem tratamento de
frescor. Um result antigo não se torna atual porque chegou uma nova publicação
de runtime. Uma concessão antiga não se torna válida porque a receita continua
carregada.

### Sequence → Control IF: `ST_SEQ_CONTROL_REQUEST`

Todos os campos são escritos somente pela Sequence.

| Campo | Significado |
| --- | --- |
| `xValid` | Intenção publicada |
| `udiSessionID` | Sessão do proprietário |
| `udiAuthorityID` | Concessão Control sob a qual o request é emitido |
| `uiProcessID` | Processo proprietário |
| `udiBatchID` | Lote proprietário |
| `udiIntentID` | Identificador da intenção; muda com a ação/etapa |
| `eAction` | Ação de `E_SEQ_ACTION` |
| `uiStepID` | Etapa associada |
| `uiPhaseID` | Fase solicitada |
| `uiProfileID` | Perfil a interpretar pelo adaptador |
| `udiResourceToken` | Concessão sob a qual a intenção opera |
| `rParameter1` | Parâmetro aplicado definido pelo perfil |
| `rParameter2` | Parâmetro aplicado definido pelo perfil |

O Service pode observar essa interface para diagnóstico; não escreve nela.
Comandos externos entram pelo contrato de comandos da Sequence. Solicitações
manuais diretamente ao Control precisam de outro canal e arbitragem definida
pelo Control; não podem sobrescrever o request de processo.

### Control IF → Sequence: `ST_SEQ_CONTROL_RESULT`

Os sinais publicados são escritos somente pelo Control/adaptador responsável.
`udiAgeMs` é metadado de recepção escrito apenas na cópia local da mailbox.

| Campo | Significado |
| --- | --- |
| `xValid` | Result disponível |
| `udiSessionID` | Sessão da intenção efetivamente processada |
| `udiAuthorityID` | Concessão da intenção efetivamente processada |
| `uiProcessID` | Processo da intenção efetivamente processada |
| `udiBatchID` | Lote da intenção efetivamente processada |
| `udiIntentID` | Intenção efetivamente processada |
| `udiAgeMs` | Idade calculada pelo receptor desde nova publicação do result |
| `xAccepted` | Intenção aceita |
| `xRejected` | Intenção rejeitada; não combinar com aceitação |
| `uiReasonID` | Motivo da decisão/diagnóstico |
| `xDone` | Ação de ciclo de execução concluída |
| `xReleased` | Nenhum recurso permanece concedido ao contexto |
| `xResourceGranted` | Posse concedida ao contexto |
| `udiResourceToken` | Token da concessão |

O result não é um local onde a Sequence escreve a conclusão que gostaria de
obter. O feedback deve refletir o processamento real do adaptador e a decisão
do árbitro. Conclusão de `Complete`, `Stop` ou `Abort` e liberação de recursos
são evidências distintas.

### Runtime Control → Sequence: `ST_SEQ_CONTROL_RUNTIME`

Este buffer é uma projeção de leitura. Não contém uma lista duplicada de
equipamentos nem transfere a autoria do runtime Control à Sequence.

| Campo | Escritor/origem | Significado |
| --- | --- | --- |
| `xValid` | Control/adaptador | Projeção válida |
| `udiSessionID` | Control/adaptador | Contexto observado |
| `udiAuthorityID` | Control/adaptador | Concessão sob a qual o contexto foi observado |
| `uiProcessID` | Control/adaptador | Processo observado |
| `udiBatchID` | Control/adaptador | Lote observado |
| `udiIntentID` | Control/adaptador | Intenção observada |
| `udiAgeMs` | Receptor/mailbox local | Idade desde nova publicação coerente observada |
| `xReady` | Control/adaptador | Disponibilidade consolidada para o processo |
| `xFaulted` | Control/adaptador | Falha consolidada pertinente ao processo |
| `xQualified` | Control/adaptador | Condições qualificadas para a etapa |
| `xStepComplete` | Control/adaptador | Conclusão observada da etapa |
| `xResourceGranted` | Control/adaptador | Posse vigente observada |
| `udiResourceToken` | Control/adaptador | Token da posse observada |
| `uiReasonID` | Control/adaptador | Motivo/diagnóstico consolidado |

A exceção de `udiAgeMs`, nos três contratos recebidos, é metadado de uma cópia local de recepção. Ela não
autoriza o receptor a editar o runtime publicado pelo Control. Entre tasks,
uma geração/heartbeat no envelope da mailbox é necessária para reconhecer
publicação nova; recópia de dados congelados não renova o frescor. A primitiva
de mailbox e esse envelope ainda dependem da integração na plataforma.

### Inicialização: `ST_SEQ_CONFIG`

Todos os campos são escritos pela inicialização da aplicação e mantidos
estáveis durante o uso da instância.

| Campo | Significado |
| --- | --- |
| `uiProcessID` | Identidade não ambígua do processo |
| `udiSessionID` | Época de inicialização não nula; estável na vida da instância |
| `udiMaxFeedbackAgeMs` | Limite de idade do feedback |
| `udiTransitionTimeoutMs` | Limite de espera das transições |
| `udiMaxCycleMs` | Limite admitido para duração informada do ciclo |

## O que o outro projeto pode implementar agora

- Um dispatcher que preencha `ST_SEQ_COMMAND_REQUEST` e aguarde o result
  correspondente.
- Um publicador coerente de `ST_SEQ_RECIPE` antes de `LoadRecipe`.
- A publicação de `ST_SEQ_RUNTIME`, sem escrita externa no runtime.
- O consumo de eventos e seu envelope de timestamp/persistência.
- O mapa HMI de estado, receita aplicada, lote, etapa, tempos, motivo e prompt.
- O tratamento visual separado entre pedido aceito, execução e encerramento.
- A invalidação das imagens públicas quando o Control não concede publicação.

O Control futuro implementará autoridade, results e a projeção de runtime
conforme seu catálogo de perfis. Até lá, a demonstração trabalha com buffers de
simulação; sua concessão mock é explícita e desabilitada por padrão.
O trabalho de integração entre repositórios não implica que a comunicação,
mailbox multi-task ou execução em Machine Expert já tenham sido validadas.
