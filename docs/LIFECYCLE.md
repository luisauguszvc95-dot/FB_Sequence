# Ciclo do motor e critérios verificáveis

Esta é a especificação do ciclo endurecido na base 0.1 e preservado no contrato 0.2.
A revisão 0.2 acrescenta eventos e proveniência; os critérios procedurais abaixo
não foram convertidos em uma nova máquina de estados. Ver também
[migração 0.2](MIGRATION_0_2.md) e [validação](VALIDATION.md).
Os nomes de estados apoiam a separação entre coordenação procedural e funções de
equipamento; não representam declaração de conformidade integral ISA-88 ou PackML.
O motor atual executa uma lista linear de até 16 etapas. Ramos, paralelismo,
recovery no meio do lote e receitas hierárquicas exigem extensão explícita.

## Estados e fronteiras

| Estado | Intenção ao Control | Próxima transição e condição |
| --- | --- | --- |
| Idle | Nenhuma | LoadRecipe aplica cópia estruturalmente validada; Start aceito vai a Starting |
| Starting | Acquire | Result Done + recurso/token coincidentes levam a Running |
| Running | Execute da etapa | Política da etapa concluída avança etapa ou vai a Completing |
| Holding | Hold | Done correlacionado e posse mantida levam a Held |
| Held | Hold mantido | Resume admitido leva a Running com nova intenção Execute |
| Completing | Complete, depois Release | Closure Done e Release confirmado levam a Complete |
| Complete | Nenhuma | Reset válido leva a Idle |
| Stopping | Stop, depois Release | Closure Done e Release confirmado levam a Stopped |
| Stopped | Nenhuma | Reset válido leva a Idle |
| Aborting | Abort, depois Release | Closure Done e Release confirmado levam a Aborted |
| Aborted | Nenhuma | Reset válido leva a Idle |
| Faulted | Abort, depois Release, se houver lote e requests permitidos | Conserva Faulted após liberação; Reset válido leva a Idle |

A Sequence não executa saídas físicas. O Control decide o significado e a
conclusão de Acquire, Execute, Hold, Complete, Stop, Abort e Release. `xDone` de
Complete/Stop/Abort não equivale à liberação: Release é uma intenção posterior.

## Admissão dos comandos

Todo comando exige sessão/processo corretos, ID novo crescente e requests
permitidos. Um ID rejeitado é consumido; corrigir o payload exige outro ID.

| Comando | Estado admitido | Requisitos adicionais |
| --- | --- | --- |
| LoadRecipe | Idle | Estrutura válida e receita/revisão exatamente iguais à candidata |
| Start | Idle | Enable, ciclo válido, execução permitida, receita aplicada correta, lote crescente, Control Ready e sem posse |
| Hold | Running | Lote corrente |
| Resume | Held | Lote corrente, Enable, ciclo/execução válidos, feedback correlacionado e posse vigente |
| Stop | Starting, Running, Holding, Held, Completing | Lote corrente |
| Abort | Starting, Running, Holding, Held, Completing, Stopping | Lote corrente |
| Reset | Complete, Stopped, Aborted, Faulted | Lote corrente, Control Ready sem falha/posse e liberação confirmada; lote zero permite recuperar uma falha sem lote |
| ConfirmStep | Running aguardando operador | Lote/etapa/prompt correntes; Execute aceito e qualificado, Ready, recurso/token válidos |

O resultado descreve **admissão**. O Service acompanha o runtime para saber se a
execução foi concluída. A restituição da autorização não retoma um lote Faulted.
Reset preserva a receita aplicada, remove o lote do runtime e conserva o lote
encerrado nos eventos que documentam o Reset.

## Etapas, relógios e evidência

| Item | Regra implementada |
| --- | --- |
| WaitQualified | Acumula duração qualificada observada sob Execute; pausas conservam o acumulado |
| WaitComplete | Exige qualificação corrente e xStepComplete do Execute corrente |
| WaitOperator | Exige confirmação contextual admitida no mesmo scan qualificado |
| Tempo da etapa | Acumula apenas em Running; inclui execução não qualificada; exclui Holding/Held |
| Tempo qualificado | Só adiciona intervalo com observações qualificadas consecutivas do Execute; não conta o intervalo inicial após Resume |
| Prazo transitório | Starting/Holding/Completing/Stopping/Aborting possuem limite por estado; novo estado inicia em zero |
| Feedback ausente | Espera limitada pelo timeout de transição, mesmo em Running/Held; mudança de estado inicia nova espera |
| Cleanup em Faulted | Não inventa liberação ao vencer tempo; conserva diagnóstico/recuperação pendentes até evidência do Control |
| Relação de feedback | SessionID, AuthorityID, ProcessID, BatchID e IntentID; posse confere também ResourceToken |
| Eventos | 32 posições, ACK da cabeça, IDs sem reutilização; overflow descarta novo e contabiliza perda |

Os três snapshots recebidos precisam de idade calculada no receptor. A simples
recópia de structs não comprova nova publicação. O integrador fornece sessão de
boot, relógio monotônico e coerência entre tasks; as POUs de teste usam uma task
simulada e tempo virtual.

## Matriz de rastreabilidade

Todos os cenários ST abaixo estão **preparados, com execução no IDE pendente**.
A verificação Python existente cobre apenas o checker estático.

| Requisito do template | Implementação | Cenário preparado |
| --- | --- | --- |
| SEQ-01: não executar pedido repetido | FB_SEQ_CommandGate | PRG_SEQ_SupportTests |
| SEQ-02: validar estrutura antes de indexar receita | FB_SEQ_RecipeValidator | PRG_SEQ_SupportTests |
| SEQ-03: congelar receita aplicada durante lote | FB_Sequence, LoadRecipe | PRG_SEQ_LifecycleTests, scans 9–10 |
| SEQ-04: não inferir autoridade de bits isolados | FB_Sequence, seção 01/02 | PRG_SEQ_IntegrationTests, scans 0–3 |
| SEQ-05: aceitar apenas feedback correlacionado | FB_Sequence, seção 01 | PRG_SEQ_IntegrationTests, scans 4–6; PRG_SEQ_AuthorityTests, scans 5–6 |
| SEQ-06: Hold não conta como Execute após Resume | FB_Sequence, seção 04 | PRG_SEQ_LifecycleTests, scans 5–10 |
| SEQ-07: confirmação contextual e executável | FB_Sequence, ConfirmStep | PRG_SEQ_LifecycleTests, scans 19–26 |
| SEQ-08: transição natural tem novo relógio | FB_Sequence, seção 05 | PRG_SEQ_LifecycleTests, scans 21–28 |
| SEQ-09: separar encerramento e liberação | FB_Sequence, seção 04/07 | PRG_SEQ_LifecycleTests, scans 11–15 e 32–35 |
| SEQ-10: não retomar após revogação | FB_Sequence, seção 02 | PRG_SEQ_IntegrationTests, scans 19–27 |
| SEQ-11: diagnosticar Hold sem conclusão | FB_Sequence, seção 05 | PRG_SEQ_LifecycleTests, scans 38–44 |
| SEQ-12: Reset auditável com lote | FB_Sequence, seção 08 | PRG_SEQ_LifecycleTests, scans 15–55 |
| SEQ-13: evento preservado até ACK/overflow explícito | FB_SEQ_EventQueue | PRG_SEQ_SupportTests |
| SEQ-14: publicação segue grant independente | FB_Sequence, seção 09 | PRG_SEQ_IntegrationTests, scans 21–22 |

A adequação a uma máquina e a aceitação normativa demandam requisitos da
aplicação, verificação da implementação e evidência no ambiente de destino.
