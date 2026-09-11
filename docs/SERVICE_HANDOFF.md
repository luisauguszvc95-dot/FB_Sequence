# Acordo de integração Sequence 0.2 ↔ Service 0.2 ↔ Control IF

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
se o Control permitir a respectiva ação. O Service de referência observa fatos;
dispatcher de comandos e catálogo de receitas são componentes externos futuros.

## Referência verificada e limite de integração

Service: branch `refactor/service-core-v0.2`, commit
`b2140a5ab4756f1c435ebcf7848270dad2f097d5`. O núcleo atual oferece
`ST_SVC_EventInput` para observações. Não oferece o dispatcher/catalogador antigo,
`ST_SVC_SequenceSnapshot`, armazenamento integral de `ST_SEQ_EVENT` ou recibo
nativo de entrada específico para o produtor Sequence. A branch `main` antiga
e sua ponte não são a referência deste acordo. A versão de repositório Service
v0.2 utiliza schema de transporte **2.0**, enquanto a Sequence publica **0.2**;
esses números não devem ser igualados por suposição.

`integration/service_v02/` contém uma projeção opcional: visão Service genérica
**parcial** e cópia imutável **completa** do evento de origem em paralelo.
Esse adaptador não muda o Service, não autentica o `uiSourceID` e não conclui
a integração. Seu ACK permanece falso sem recibo explícito para o envelope completo.
Depois de recibo válido, o ACK é retido enquanto a mesma cabeça existir, evitando
perda por pulso de um scan. Publicação revogada suprime ACK e payload; na volta,
somente a mesma identidade já assumida pode ser confirmada. Tempo de origem
inválido impede marcar a projeção Service como válida, sem adulterar a qualidade
ou o conteúdo do evento completo.

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

O contrato desta revisão é **0.2**, informado no runtime e nos eventos por
`uiContractMajor` e `uiContractMinor`. O número descreve tipos e semântica; ele
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

Essas regras são o acordo de integração proposto. Esta v0.2 não implementa
negociação dinâmica de schema nem gera o mapeamento de endereços do Service.

## Escritores e consumidores

Cada campo listado pertence ao escritor da linha. Campos de correlação copiados
para um result continuam sendo escritos pelo produtor desse result; o receptor
nunca os preenche retroativamente.

| Contrato/buffer | Escritor único | Consumidor |
| --- | --- | --- |
| `ST_SEQ_COMMAND_REQUEST` | Dispatcher externo futuro; Demo no ensaio isolado | Sequence |
| `ST_SEQ_RECIPE`, candidata | Catálogo/publicador externo futuro; Demo no ensaio isolado | Sequence |
| Receita aplicada interna | Sequence, por cópia validada | Motor de etapas |
| `ST_SEQ_COMMAND_RESULT` | Sequence | Service |
| `ST_SEQ_RUNTIME` | Sequence | Service e outros leitores |
| `ST_SEQ_EVENT` | Sequence | Consumidor de eventos no Service |
| ACK público, `udiEventAckSessionID`/`udiEventAckID` | Consumidor que assumiu o envelope completo, por recibo correlacionado | Sequence, que encaminha à fila interna |
| `ST_SEQ_CONTROL_AUTHORITY`, sinais publicados | Control | Sequence |
| `ST_SEQ_CONTROL_AUTHORITY.udiAgeMs`, cópia local | Receptor/mailbox na task consumidora | Sequence |
| `ST_SEQ_CONTROL_REQUEST` | Sequence | Control IF/adaptador |
| `ST_SEQ_CONTROL_RESULT`, sinais publicados | Control IF/adaptador | Sequence |
| `ST_SEQ_CONTROL_RESULT.udiAgeMs`, cópia local | Receptor/mailbox na task consumidora | Sequence |
| `ST_SEQ_CONTROL_RUNTIME`, sinais publicados | Control/adaptador de projeção | Sequence |
| `ST_SEQ_CONTROL_RUNTIME.udiAgeMs`, cópia local | Receptor/mailbox na task consumidora | Sequence |
| `ST_SEQ_CONFIG` | Inicialização da aplicação | Sequence |
| `ST_SEQ_TRACE_TIME` | Origem de tempo da aplicação; explicitamente sintética na Demo | Sequence |

### Ligação no programa: `GVL_SEQ_IF`

`PRG_Task_Sequence` chama a instância `fbSequence` e copia suas saídas para a
GVL. Essa cópia é a publicação da Sequence; não cria um segundo dono semântico.
O programa não fabrica autoridade nem feedback do Control.

| Campo da GVL | Escritor único | Contrato/uso |
| --- | --- | --- |
| `stConfig` | Inicialização da aplicação | `ST_SEQ_CONFIG`, estável na vida da instância |
| `xEnable` | Integração da aplicação | Habilitação local; não concede autoridade Control |
| `udiDeltaMs` | Integração/origem de tempo | Delta monotônico validado do ciclo |
| `stTraceTime` | Origem de tempo da aplicação | Amostra monotônica, validade e indicação de simulação |
| `stCommand` | Dispatcher externo | `ST_SEQ_COMMAND_REQUEST` |
| `stRecipeCandidate` | Publicador externo de receita | `ST_SEQ_RECIPE` |
| `udiEventAckSessionID` | Consumidor de envelope completo | Sessão do evento assumido pelo consumidor |
| `udiEventAckID` | Consumidor de envelope completo | ID do evento assumido pelo consumidor |
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

### Dispatcher externo → Sequence: `ST_SEQ_COMMAND_REQUEST`

Todos os campos deste buffer são escritos somente pelo dispatcher externo.
Esse componente não existe no núcleo Service v0.2 usado como referência.

| Campo | Significado |
| --- | --- |
| `xValid` | Pedido completo disponível; manter até seu resultado de admissão |
| `udiSessionID` | Sessão da instância de destino |
| `udiRequestID` | Identificador crescente do dispatcher, sem wrap na sessão |
| `uiSourceID` | Origem declarada do comando; autenticação/autorização são responsabilidade do canal externo |
| `uiProcessID` | Processo de destino |
| `eCommand` | Comando de `E_SEQ_CMD` |
| `udiBatchID` | Identidade do lote requerida pelo comando |
| `udiRecipeID` | Referência da receita requerida pelo comando |
| `udiRecipeRevision` | Revisão da receita requerida pelo comando |
| `uiStepID` | Contexto da etapa, quando aplicável |
| `udiPromptID` | Identidade da confirmação solicitada, quando aplicável |

O dispatcher externo deve serializar origens HMI, supervisório e outras num único canal
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
de `Held`, o cliente deve aguardar a execução corrente; o ACK anterior de `Hold`
não comprova retomada. O PromptID identifica a mesma etapa durante Hold/Resume.

### Receita candidata: `ST_SEQ_RECIPE` e `ST_SEQ_STEP`

Todos os campos da candidata são escritos pelo publicador externo de receita.
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
| `uiMachineID`, `uiProducerSourceID` | Máquina e produtor do runtime, distintos da origem do comando |
| `uiProfileID` | Perfil da etapa aplicada |
| `udiRevision` | Geração monotônica de publicação; satura, sem wrap silencioso |
| `udiTickMs`, `xTimeValid`, `xSyntheticTime` | Tempo monotônico de origem e sua qualidade, não UTC |
| `xTraceReady` | Identidade configurada, tempo válido não sintético, revisão disponível e nenhuma perda local conhecida; não prova persistência |
| `xTraceHistoryComplete` | Nenhuma perda local conhecida na sessão; falso fica latente após perda |

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
| `eKind` | Ocorrência tipada; valores anteriores preservados, novos tipos adicionados |
| `eState` | Estado registrado no evento |
| `uiStepID` | Etapa registrada no evento |
| `udiRequestID` | Pedido associado quando aplicável |
| `udiCommandSessionID` | Sessão do pedido associado; pode diferir da sessão de origem se o pedido foi rejeitado |
| `uiSourceID` | Origem do pedido associado quando aplicável |
| `eCommand` | Comando associado quando aplicável |
| `eCommandResult` | Resultado de admissão quando aplicável |
| `eReason` | Motivo registrado |
| `uiContractMajor`, `uiContractMinor` | Versão do envelope de origem, atualmente 0.2 |
| `uiMachineID`, `uiProducerSourceID` | Origem do fato; não confundir produtor com `uiSourceID` do comando |
| `udiOccurrenceTickMs` | Tick monotônico no instante de produção, não no consumo |
| `xOccurrenceTimeValid`, `xSyntheticTime` | Validade declarada da amostra e indicação de tempo sintético |
| `eStateBefore`, `uiStepIDBefore` | Contexto anterior à transição |
| `udiBatchIDBefore`, `udiRecipeIDBefore`, `udiRecipeRevisionBefore` | Identidade aplicada antes da mudança |
| `uiPhaseID`, `uiProfileID` | Fase e perfil da ocorrência |
| `udiIntentID`, `udiPromptID` | Correlação com intenção Control e prompt |
| `udiResourceTokenBefore`, `udiResourceToken` | Posse anterior e posse registrada no fato |
| `udiStepElapsedMs`, `udiQualifiedElapsedMs` | Tempos congelados da etapa associada |
| `udiRequestedRecipeID`, `udiRequestedRecipeRevision`, `udiRequestedBatchID` | Contexto solicitado pelo comando, mesmo quando rejeitado |
| `uiRequestedStepID`, `udiRequestedPromptID` | Etapa/prompt solicitados, separados do contexto efetivo |

O consumidor externo deve acrescentar timestamps de recebimento/persistência em seu próprio
envelope, sem preencher retroativamente a struct de origem. A chave externa de
deduplicação inclui máquina, produtor, processo, sessão e ID do evento.
Uma sessão de boot não pode ser reutilizada ao reiniciar o produtor.
A v0.2 não fornece log persistente ou horário de calendário do fato. O receptor
não pode promover seu horário de chegada a horário de ocorrência sem declarar
o método de correlação e a incerteza.

Os tipos adicionados explicitam início/fim de lote e etapa, emissão/confirmação
de prompt, aquisição/liberação de recurso, levantamento/limpeza de falha e
rejeição de receita. São fatos da execução; não são confirmação de persistência,
assinatura de operador ou comprovação de qualidade do produto.

| Evento | Significado preciso na 0.2 |
|---|---|
| `BatchStarted` | Start admitido com novo lote; não comprova aquisição ou execução pelo Control |
| `BatchFinished` | Entrada em Complete, Stopped ou Aborted; Faulted não é conclusão do lote |
| `StepStarted` | Seleção de execução após Starting ou avanço de etapa; Resume não reinicia a etapa |
| `StepFinished` | Critério da etapa satisfeito; fase, perfil, intenção e tempos são os da etapa concluída |
| `PromptIssued` / `PromptConfirmed` | Novo PromptID / confirmação consumida com conclusão, mantendo contexto do prompt anterior |
| `ResourceAcquired` / `ResourceReleased` | Mudança observada de token; correlacionada à intenção anterior, não à próxima intenção Execute |
| `FaultRaised` / `FaultCleared` | Entrada/saída de Faulted; limpeza conserva o motivo anterior no evento |
| `RecipeRejected` | LoadRecipe rejeitado; referência solicitada permanece separada da aplicada |

Todos os fatos do scan compartilham o tick de origem; não representam medição
de instantes intermediários. A ordem mantém StateChanged, StepChanged,
RecipeLoaded e CommandResult primeiro. Nos fatos adicionais, StepFinished vem
antes de StepStarted e ResourceReleased antes de ResourceAcquired. Não usar a
ordem numérica do enum como ordem causal universal nem somar eventos genéricos
e semânticos como se fossem duas execuções distintas.

Receita/revisão, concessão e contexto do comando ficam congelados no evento.
Usar esses campos para o histórico, sem associar um evento antigo ao runtime
atual. `udiSessionID` identifica a origem do evento; `udiCommandSessionID`
identifica o pedido avaliado e preserva a explicação de uma rejeição por sessão
incorreta. Os campos de comando são preenchidos em `CommandResult` e nos fatos
diretamente ligados ao comando: RecipeLoaded, RecipeRejected, BatchStarted e
PromptConfirmed. Um comando rejeitado no mesmo scan não é atribuído como causa
de uma transição independente do Control.

Ao aceitar `Reset`, o runtime passa a `Idle` e `udiBatchID = 0`. Os eventos dessa
operação conservam o lote que foi encerrado/resetado. Não substituir esse BatchID
pelo valor do runtime atual ao persistir o evento.

A fila interna é volátil, tem 32 posições e expõe a cabeça para consumo. Seu consumidor
escreve `udiEventAckSessionID` e `udiEventAckID` somente após assumir a
responsabilidade pelo **evento completo** exposto no processo correspondente.
Essa posse deve estar documentada na integração: durável ou em buffer assumido
com política explícita de perda. Copiar a projeção parcial, incrementar contadores
do Service ou receber MQTT PUBACK não basta. O adaptador opcional verifica um
recibo correlacionado; sem esse recibo não confirma. A Sequence
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
registradas pelo produtor. `xTraceHistoryComplete` torna a perda local visível
no runtime e não volta a verdadeiro porque a fila foi drenada. Nova sessão não
reconstitui o histórico anterior. É necessário preservar e investigar a lacuna
no consumidor externo.

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
| `uiMachineID` | Identidade de máquina; zero não bloqueia execução, mas deixa rastreabilidade não pronta |
| `uiProducerSourceID` | Identidade estável do produtor, distinta do usuário/canal de comando |

## O que ainda precisa de implementação externa

O [README do adaptador](../integration/service_v02/README.md) descreve uma lacuna
adicional na revisão fixada do Service: cursor de deduplicação pode avançar antes
do sucesso de entrada no outbox. O contador de aceitação não fecha essa lacuna,
e o ACK de auditoria Service não identifica a posse de todo o evento Sequence.
Não há ligação automática autorizada por este contrato.

- Dispatcher e publicador coerente de receita, externos ao Service de observação.
- Consumidor do envelope completo com recibo, deduplicação, retenção e tratamento de perdas.
- Projeção de runtime e mapa HMI versionado, sem escrita externa no estado da Sequence.
- Envelope externo de recepção/persistência e correlação temporal verificável.
- Invalidação das imagens públicas quando o Control não concede publicação.

O Control futuro implementará autoridade, results e a projeção de runtime
conforme seu catálogo de perfis. Até lá, a demonstração trabalha com buffers de
simulação; sua concessão mock é explícita e desabilitada por padrão.
O trabalho de integração entre repositórios não implica que a comunicação,
mailbox multi-task ou execução em Machine Expert já tenham sido validadas.
