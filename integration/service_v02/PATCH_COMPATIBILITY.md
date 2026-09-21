# Compatibilidade v0.2: inserção, envelope completo e recibo

Candidato offline de 2026-09-21. O núcleo Sequence e os demos isolados continuam
com seus contratos de autoridade, comandos, resultados e eventos. As novas peças
são opcionais e ficam nesta pasta; nenhuma task existente foi conectada.

## Peças e responsabilidade

| Peça | Contrato |
|---|---|
| `FB_SEQ_ToServiceAdapter` existente | Retém o evento completo, cria uma projeção parcial e só confirma a cabeça após recibo de propriedade completa |
| `ST_SVC_EventReceipt` do Service corrigido | Confirma inserção da projeção em RAM, por identidade de origem e BootID/RecordID |
| `ST_SEQ_SVC_SINK_RECEIPT` novo | Vincula o recibo do envelope completo ao registro específico do Service |
| `FB_SEQ_ServiceReceiptGate` novo | Exige ambas as evidências e a transição de recibo bruto inválido para válido |
| `envelope_store.py` novo | Sink DEMO local: valida e grava o envelope integral no SQLite antes de retornar o recibo |

A dependência exata está em `service_dependency.json`. O schema de validação
`service_event.schema.json` é metadado derivado dos DUTs canônicos do Service,
com hashes de origem; não é um segundo conjunto de tipos ST.

## Ordem de composição no projeto offline futuro

1. Chame o mapper com a cabeça pública Sequence, permissão atual e o recibo do
   gate observado no ciclo anterior. Passe todos os inputs explicitamente.
2. Enquanto `xEnvelopeValid`, ofereça `stEnvelope.stServiceEvent` em um slot fixo
   de `aEvents`. Preserve também o envelope inteiro; somente a projeção não basta.
3. Após o Service, associe `aEventReceipts[slot]` ao envelope pela máquina,
   produtor, processo, sessão e EventID. Um sink designado guarda o envelope
   completo e essa associação. O sink DEMO retorna somente depois do COMMIT.
4. Chame o gate com envelope, recibo de inserção e recibo do sink. Primeiro
   apresente `stSink.stSourceReceipt.xValid=FALSE` enquanto a inserção estiver
   elegível; depois entregue o recibo efetivo. Encaminhe `stReceipt` ao mapper.
5. Somente o mapper produz o ACK de origem. Copie sua sessão/EventID para a
   entrada de ACK da instância Sequence correspondente. ACK de auditoria e
   ACK de transferência continuam nos canais próprios do Service.

Recibo bruto já válido antes de a inserção estar elegível não é aceito. Uma
saída mascarada por falta de permissão não conta como transição baixa desse
recibo. Identidade ou revisão divergente exige novo ciclo inválido→válido.
Depois de reconhecer a propriedade, o gate retém o recibo para repetição exata;
após suspensão, publica um ciclo inválido antes de retomá-lo, permitindo rearmar
um mapper que não tenha observado a entrega anterior. A cabeça seguinte exige
um novo recibo, incluindo o novo RecordID.

Não existe autenticação de recibos neste código. O escritor é o sink designado
pela aplicação; o contrato não permite simular propriedade por contador,
temporizador ou botão de operador. Uma cópia consistente deve ser estabelecida
na mesma task ou pela sincronização nativa da plataforma.

## Limites concretos

O sink Python recebe objetos locais; não lê PLC, publica MQTT ou escreve ACK no
Machine Expert. A integração precisa transportar o envelope integral e seu
recibo por um caminho próprio. A imagem atual de 160 words carrega somente o
registro genérico Service e não comporta todo `ST_SEQ_EVENT`.

O SQLite DEMO usa uma tabela própria e não substitui o historiador Service.
Identidade repetida com qualquer alteração de conteúdo, mapeamento ou vínculo
Service é conflito; o registro existente nunca é sobrescrito. Após reinício com
outro BootID, esse conflito exige reconciliação. As filas PLC permanecem voláteis.
Evento sem tempo de ocorrência válido continua bloqueado para a projeção
genérica; não se fabrica horário original a partir da ingestão.

## Verificação

Na raiz da Sequence:

```bash
python -m unittest discover -s integration/service_v02/tests -v
python integration/service_v02/verify_service_dependency.py CAMINHO_FB_SERVICE
```

Os testes incluem o mapper anterior, protocolo do gate, preenchimento de todos
os campos da origem, preservação de admissão/motivo/identidades, reabertura do
SQLite, conflitos e falhas de INSERT/COMMIT. A suíte usa modelos Python e
SQLite real; não executa ST.

Existe `tests/PRG_SEQ_ReceiptGateTests.st` para um projeto de teste offline.
Resultado nativo esperado, ainda não observado: `xDone=TRUE`, `uiChecks=9`,
`uiFailures=0`, `uiFirstFailure=0`. Execute também os 23 checks do programa
anterior `PRG_SEQ_ServiceAdapterTests` e os testes de autoridade/lifecycle da
Sequence, sem alterar os resultados de admissão para resultados de conclusão.

O FB_Control contém o verificador das três bases e o exercício do pipeline com
os modelos dos pares e SQLite. Esse exercício não representa execução conjunta
dos três FBs no PLC.
