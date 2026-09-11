# Migração 0.1 → 0.2 — preparar agora, testar depois

Esta atualização amplia rastreabilidade sem integrar o Service na task da
Sequence. Preserve o projeto anterior como referência. Resultados da base 0.1
continuam históricos e não são resultados da 0.2.

## O que mudou

| Grupo | Alteração | Impacto |
|---|---|---|
| Identidade | `uiMachineID` e `uiProducerSourceID` em configuração/runtime/eventos | Não reutilizar `uiSourceID` do comando como produtor |
| Tempo | Novo `ST_SEQ_TRACE_TIME`; tempo/qualidade no runtime e no evento | Não informado = inválido; Demo = sintético, nunca UTC real |
| Eventos | Novos tipos e contexto de origem/antes/pedido/aplicado/recursos/tempos | Mais eventos usam a mesma fila de 32; atualizar consumidor e layout |
| Runtime | Revisão, perfil, `xTraceReady`, `xTraceHistoryComplete` | Leitores podem distinguir preparação de trace e perda conhecida; não são prova de persistência |
| Service | Adaptador opcional externo à demo, referência Service v0.2 fixada | Projeção parcial + origem completa; sem recibo de posse integral, sem ACK |

Os valores antigos de enum são preservados. Campos adicionados em STRUCT
alteram o layout: não reutilizar endereços, offsets, dumps retentivos ou
serialização binária 0.1 sem novo mapeamento. Isso também vale para uma mudança minor.

## Atualização futura do projeto de simulação

1. Use uma cópia separada do projeto de simulação e mantenha os mesmos quatro
   Watches; não é necessário recriá-los ou construir Visualization.
2. Atualize os tipos, funções, FBs e invólucros pela ordem gerada em
   `build/import_order.txt`. Inclua o novo `ST_SEQ_TRACE_TIME` antes de seus
   consumidores e atualize `ST_SEQ_CONFIG`, `ST_SEQ_RUNTIME`, `ST_SEQ_EVENT`,
   `E_SEQ_EVENT_KIND`, `FB_SEQ_EventBuilder`, `FB_Sequence`, `GVL_SEQ_IF`,
   `PRG_Task_Sequence` e a Demo.
   O bundle contém a lista exata de dependências; não mescle objetos 0.1/0.2.
3. Compile primeiro a Sequence e os POUs de ensaio escolhidos, sem importar
   `integration/service_v02/` e sem incluir Service ou Control de aplicação.
4. Quando retomar os testes, registre os resultados da nova revisão em
   `VALIDATION.md`; só depois dos testes isolados de ambos preparar a integração.

Ao incorporar texto no IDE, `END_FUNCTION_BLOCK` e `END_PROGRAM` delimitam
arquivos, não são instruções para o corpo de implementação. O projeto alvo
continua sendo Machine Expert 2.6; esta atualização não entrega `.project` compilado.

## Watches existentes, preservados

| Watch | Conteúdo já organizado | Acréscimos úteis, sem mover o restante |
|---|---|---|
| 1 | `PRG_SEQ_Demo` e `stCommand` | Observar a configuração de identidade e o tempo sintético da Demo |
| 2 | `fbSequence.stCommandResult` e `fbSequence.stRuntime` | Expandir `uiContractMinor`, `udiRevision`, `xTimeValid`, `xSyntheticTime`, `xTraceReady`, `xTraceHistoryComplete` |
| 3 | `fbControlMock`: autoridade, request, result e runtime | Nenhuma reorganização; continua reservado ao handshake |
| 4 | Evento disponível, contagem, perdas, sessão/ID de ACK | Expandir `stEvent`: produtor, tempo, contexto anterior e solicitado |

Na demo, `xTraceReady = FALSE` é esperado porque o tempo é sintético. Isso não
significa falha de execução. `xTraceHistoryComplete = FALSE` indica perda local
conhecida e não deve ser apagado com um ACK ou edição de Watch.

## Contrato parceiro e limites

O Service usado como referência é `refactor/service-core-v0.2` no commit
`b2140a5ab4756f1c435ebcf7848270dad2f097d5`, não o modelo antigo centrado em
equipment/process. O núcleo observa fatos; dispatcher de comandos e catálogo
de receitas serão externos. O adaptador desta revisão não implementa esses módulos.
O schema de transporte Service é 2.0; não é o número 0.2 do contrato Sequence.

Não ligar ACK de Sequence a um contador Service, a uma atribuição de struct ou
a MQTT PUBACK. O evento completo precisa de um consumidor responsável, com
recibo correlacionado e política explícita de retenção. A projeção genérica
Service, sozinha, não conserva a evidência integral.

Leitura complementar: [contrato](SERVICE_HANDOFF.md),
[limites normativos e requisitos](STANDARDS_ALIGNMENT.md) e [roadmap](ROADMAP.md).
