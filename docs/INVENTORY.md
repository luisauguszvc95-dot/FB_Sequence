# Inventário ST

Gerado por `python tools/build_bundle.py --source-dir src --source-dir tests`; não editar manualmente.

30 objetos. A ordem abaixo respeita as dependências identificadas.

| Ordem | Objeto | Tipo | Dependências | Fonte |
| --- | --- | --- | --- | --- |
| 1 | `E_SEQ_ACTION` | enum | — | [E_SEQ_ACTION.st](../src/dut/E_SEQ_ACTION.st) |
| 2 | `E_SEQ_CMD` | enum | — | [E_SEQ_CMD.st](../src/dut/E_SEQ_CMD.st) |
| 3 | `E_SEQ_EVENT_KIND` | enum | — | [E_SEQ_EVENT_KIND.st](../src/dut/E_SEQ_EVENT_KIND.st) |
| 4 | `E_SEQ_REASON` | enum | — | [E_SEQ_REASON.st](../src/dut/E_SEQ_REASON.st) |
| 5 | `E_SEQ_RESULT` | enum | — | [E_SEQ_RESULT.st](../src/dut/E_SEQ_RESULT.st) |
| 6 | `E_SEQ_STATE` | enum | — | [E_SEQ_STATE.st](../src/dut/E_SEQ_STATE.st) |
| 7 | `E_SEQ_STEP_KIND` | enum | — | [E_SEQ_STEP_KIND.st](../src/dut/E_SEQ_STEP_KIND.st) |
| 8 | `ST_SEQ_COMMAND_REQUEST` | struct | `E_SEQ_CMD` | [ST_SEQ_COMMAND_REQUEST.st](../src/dut/ST_SEQ_COMMAND_REQUEST.st) |
| 9 | `ST_SEQ_COMMAND_RESULT` | struct | `E_SEQ_CMD`, `E_SEQ_REASON`, `E_SEQ_RESULT`, `E_SEQ_STATE` | [ST_SEQ_COMMAND_RESULT.st](../src/dut/ST_SEQ_COMMAND_RESULT.st) |
| 10 | `ST_SEQ_CONFIG` | struct | — | [ST_SEQ_CONFIG.st](../src/dut/ST_SEQ_CONFIG.st) |
| 11 | `ST_SEQ_CONTROL_AUTHORITY` | struct | — | [ST_SEQ_CONTROL_AUTHORITY.st](../src/dut/ST_SEQ_CONTROL_AUTHORITY.st) |
| 12 | `ST_SEQ_CONTROL_REQUEST` | struct | `E_SEQ_ACTION` | [ST_SEQ_CONTROL_REQUEST.st](../src/dut/ST_SEQ_CONTROL_REQUEST.st) |
| 13 | `ST_SEQ_CONTROL_RESULT` | struct | — | [ST_SEQ_CONTROL_RESULT.st](../src/dut/ST_SEQ_CONTROL_RESULT.st) |
| 14 | `ST_SEQ_CONTROL_RUNTIME` | struct | — | [ST_SEQ_CONTROL_RUNTIME.st](../src/dut/ST_SEQ_CONTROL_RUNTIME.st) |
| 15 | `ST_SEQ_EVENT` | struct | `E_SEQ_CMD`, `E_SEQ_EVENT_KIND`, `E_SEQ_REASON`, `E_SEQ_RESULT`, `E_SEQ_STATE` | [ST_SEQ_EVENT.st](../src/dut/ST_SEQ_EVENT.st) |
| 16 | `ST_SEQ_STEP` | struct | `E_SEQ_STEP_KIND` | [ST_SEQ_STEP.st](../src/dut/ST_SEQ_STEP.st) |
| 17 | `ST_SEQ_RECIPE` | struct | `ST_SEQ_STEP` | [ST_SEQ_RECIPE.st](../src/dut/ST_SEQ_RECIPE.st) |
| 18 | `ST_SEQ_RUNTIME` | struct | `E_SEQ_REASON`, `E_SEQ_STATE` | [ST_SEQ_RUNTIME.st](../src/dut/ST_SEQ_RUNTIME.st) |
| 19 | `F_SEQ_AddMs` | function | — | [F_SEQ_AddMs.st](../src/functions/F_SEQ_AddMs.st) |
| 20 | `FB_SEQ_CommandGate` | fb | `E_SEQ_REASON`, `ST_SEQ_COMMAND_REQUEST` | [FB_SEQ_CommandGate.st](../src/fb/FB_SEQ_CommandGate.st) |
| 21 | `FB_SEQ_EventQueue` | fb | `F_SEQ_AddMs`, `ST_SEQ_EVENT` | [FB_SEQ_EventQueue.st](../src/fb/FB_SEQ_EventQueue.st) |
| 22 | `FB_SEQ_QualifiedTimer` | fb | `F_SEQ_AddMs` | [FB_SEQ_QualifiedTimer.st](../src/fb/FB_SEQ_QualifiedTimer.st) |
| 23 | `FB_SEQ_RecipeValidator` | fb | `E_SEQ_REASON`, `E_SEQ_STEP_KIND`, `ST_SEQ_RECIPE` | [FB_SEQ_RecipeValidator.st](../src/fb/FB_SEQ_RecipeValidator.st) |
| 24 | `FB_Sequence` | fb | `E_SEQ_ACTION`, `E_SEQ_CMD`, `E_SEQ_EVENT_KIND`, `E_SEQ_REASON`, `E_SEQ_RESULT`, `E_SEQ_STATE`, `E_SEQ_STEP_KIND`, `FB_SEQ_CommandGate`, `FB_SEQ_EventQueue`, `FB_SEQ_QualifiedTimer`, `FB_SEQ_RecipeValidator`, `F_SEQ_AddMs`, `ST_SEQ_COMMAND_REQUEST`, `ST_SEQ_COMMAND_RESULT`, `ST_SEQ_CONFIG`, `ST_SEQ_CONTROL_AUTHORITY`, `ST_SEQ_CONTROL_REQUEST`, `ST_SEQ_CONTROL_RESULT`, `ST_SEQ_CONTROL_RUNTIME`, `ST_SEQ_EVENT`, `ST_SEQ_RECIPE`, `ST_SEQ_RUNTIME` | [FB_Sequence.st](../src/fb/FB_Sequence.st) |
| 25 | `FB_SEQ_ControlMock` | fb | `E_SEQ_ACTION`, `ST_SEQ_CONFIG`, `ST_SEQ_CONTROL_AUTHORITY`, `ST_SEQ_CONTROL_REQUEST`, `ST_SEQ_CONTROL_RESULT`, `ST_SEQ_CONTROL_RUNTIME` | [FB_SEQ_ControlMock.st](../tests/FB_SEQ_ControlMock.st) |
| 26 | `GVL_SEQ_IF` | gvl | `ST_SEQ_COMMAND_REQUEST`, `ST_SEQ_COMMAND_RESULT`, `ST_SEQ_CONFIG`, `ST_SEQ_CONTROL_AUTHORITY`, `ST_SEQ_CONTROL_REQUEST`, `ST_SEQ_CONTROL_RESULT`, `ST_SEQ_CONTROL_RUNTIME`, `ST_SEQ_EVENT`, `ST_SEQ_RECIPE`, `ST_SEQ_RUNTIME` | [GVL_SEQ_IF.st](../src/gvl/GVL_SEQ_IF.st) |
| 27 | `PRG_SEQ_Demo` | program | `E_SEQ_STEP_KIND`, `FB_Sequence`, `FB_SEQ_ControlMock`, `ST_SEQ_COMMAND_REQUEST`, `ST_SEQ_CONFIG`, `ST_SEQ_RECIPE` | [PRG_SEQ_Demo.st](../tests/PRG_SEQ_Demo.st) |
| 28 | `PRG_SEQ_IntegrationTests` | program | `E_SEQ_ACTION`, `E_SEQ_CMD`, `E_SEQ_REASON`, `E_SEQ_RESULT`, `E_SEQ_STATE`, `E_SEQ_STEP_KIND`, `FB_Sequence`, `FB_SEQ_ControlMock`, `ST_SEQ_COMMAND_REQUEST`, `ST_SEQ_CONFIG`, `ST_SEQ_CONTROL_RESULT`, `ST_SEQ_CONTROL_RUNTIME`, `ST_SEQ_RECIPE` | [PRG_SEQ_IntegrationTests.st](../tests/PRG_SEQ_IntegrationTests.st) |
| 29 | `PRG_SEQ_SupportTests` | program | `E_SEQ_CMD`, `E_SEQ_REASON`, `E_SEQ_STEP_KIND`, `FB_SEQ_CommandGate`, `FB_SEQ_EventQueue`, `FB_SEQ_QualifiedTimer`, `FB_SEQ_RecipeValidator`, `F_SEQ_AddMs`, `ST_SEQ_COMMAND_REQUEST`, `ST_SEQ_EVENT`, `ST_SEQ_RECIPE` | [PRG_SEQ_SupportTests.st](../tests/PRG_SEQ_SupportTests.st) |
| 30 | `PRG_Task_Sequence` | program | `FB_Sequence`, `GVL_SEQ_IF` | [PRG_Task_Sequence.st](../src/prg/PRG_Task_Sequence.st) |

Verificação estática: declarações e nomes de arquivo, tipos utilizados, membros e valores
de enums, delimitadores, ausência de endereçamento físico AT/%I/%Q e ciclos de dependência.

O bundle é texto para revisão/importação manual por objeto; não é XML PLCopen nem projeto nativo.
O checker cobre o subconjunto textual deste repositório. Não verifica assinaturas de chamada,
campos de instância, expressões, escalonamento, concorrência ou comportamento em execução.
Compilação, simulação e validação no Machine Expert permanecem pendentes.
