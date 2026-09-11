# Importação e demonstração offline

**Revisão 0.2:** material preparado; os ensaios nativos ficam para a próxima
sessão do usuário. Consulte [MIGRATION_0_2.md](MIGRATION_0_2.md) antes de atualizar
uma cópia do projeto. Não recrie os quatro Watches existentes.

O alvo de revisão é Structured Text do EcoStruxure Machine Expert 2.6/CODESYS.
Os arquivos são fontes legíveis, um objeto IEC por arquivo. A extensão `.st` não
constitui um formato de importação nativa garantido pelo IDE.

## Preparação no IDE

Use um projeto separado de simulação. Crie os DUTs seguindo a ordem de dependências
em `build/import_order.txt` (gerada por `python3 tools/build_bundle.py`), depois a função,
os FBs, a GVL e os programas que forem necessários.

Em cada DUT, copie a declaração `TYPE ... END_TYPE`. Em cada POU, separe a declaração
dos blocos VAR e a implementação executável. O cabeçalho `FUNCTION_BLOCK`/`PROGRAM`
identifica o objeto; `END_FUNCTION_BLOCK`/`END_PROGRAM` são delimitadores do arquivo,
não instruções para colar no corpo do editor. Em `F_SEQ_AddMs`, configure o retorno UDINT.
Para a GVL, use o nome `GVL_SEQ_IF` e sua declaração global.

Primeiro compile. Erros de dialeto/tipo no IDE precisam ser resolvidos antes de qualquer
conclusão sobre execução. Este repositório não inclui nem modifica o projeto original.

## Demonstração

`tests/PRG_SEQ_Demo.st` usa exclusivamente `FB_SEQ_ControlMock`, em memória, e uma receita
sintética de três etapas. O mock e a Sequence começam desabilitados. As três permissões
também começam falsas. Os perfis 100/200/300 são identificadores fictícios, sem IO.

O PRG é autocontido. Não chame `PRG_Task_Sequence` sobre a mesma instância ou contratos
ao usar a demonstração. A cada chamada ele simula 20 ms; esse valor é tempo virtual,
não medição de duração real da task. `stTraceTime` identifica explicitamente
esse tempo como sintético; máquina e produtor da Demo são 1. Assim,
`stRuntime.xTraceReady = FALSE` é esperado na Demo, sem invalidar seu ensaio funcional.

Para observar o exemplo no simulador, habilite o mock e a Sequence, conceda as permissões
do mock e permita a conclusão das ações sintéticas. Os comandos usam sessão 1, processo 1,
receita 1, revisão 1 e IDs de pedido crescentes. Envie LoadRecipe; após resultado Accepted,
envie Start com BatchID 1. Mantenha o payload de cada comando até observar seu resultado.

A primeira etapa acumula tempo quando `xQualified` é verdadeiro; a segunda depende
também de `xStepComplete`; a terceira exige ConfirmStep com BatchID, StepID e PromptID
iguais ao runtime atual. A conclusão final depende de Complete e Release confirmados
pelo mock. Para repetir, use Reset com o BatchID terminado e Start com BatchID maior.

`Accepted` significa que a Sequence admitiu o comando. Não significa que o Control
executou a ação nem que o processo terminou.

## POUs de testes

Execute os POUs abaixo somente na simulação, com instâncias novas e não retentivas:

| POU | Verificações esperadas | Escopo |
| --- | ---: | --- |
| `PRG_SEQ_SupportTests` | 40 | Timer, gate, receita e fila |
| `PRG_SEQ_IntegrationTests` | 28 | Concessão, ciclo completo e revogação |
| `PRG_SEQ_LifecycleTests` | 56 | Hold/Resume, confirmação, Stop/Abort, prazos e Reset |
| `PRG_SEQ_AuthorityTests` | 8 | Release entre gerações de autoridade |
| `PRG_SEQ_TraceTests` | 16 | Fixtures do construtor de eventos e campos de origem; sem fila |
| `PRG_SEQ_TraceEngineTests` | 33 | Produção de eventos pelo motor ao longo de 33 scans |

Use `python3 tools/build_bundle.py --source-dir src --source-dir tests` para
incluir os testes na ordem textual de incorporação.
Os POUs anteriores e `PRG_SEQ_TraceTests` expõem `uiChecks`, `uiFailures` e `xDone`.
`PRG_SEQ_TraceTests` espera `TRUE / 16 / 0 / 65535` para
`xDone / uiChecks / uiFailures / uiFirstFailureStep`.
`PRG_SEQ_TraceEngineTests` usa nomes diferentes e espera `TRUE / 33 / 0 / 65535`
para `xDone / uiTests / uiFailures / uiFirstFailure`.
O gate exige conclusão, zero falhas e a quantidade prevista. Os roteiros multiscans
têm quantidade fixa de chamadas; não esperam indefinidamente por um estado ausente.
Reinicialize a aplicação para repetir. Nenhum destes POUs foi executado neste ambiente.

## Watches da Demo

| Watch existente | Finalidade | Observação na 0.2 |
|---|---|---|
| 1 — Demo / `stCommand` | Comandos e entradas sintéticas | Manter como já configurado |
| 2 — command result / runtime | Admissão e execução da Sequence | Expandir versão, revisão, validade/tempo sintético e indicadores de trace |
| 3 — ControlMock | Autoridade, request, result e runtime do mock | Manter o handshake em sua própria aba |
| 4 — eventos / ACK | Evento, disponibilidade, contagem, perdas e IDs de ACK | Expandir o envelope 0.2; não misturar com retorno do comando |

Não realocar SupportTests/IntegrationTests para essas abas. Os quatro Watches
foram organizados para a Demo. Evidência automática e observação manual são registros diferentes.

## Integração futura

`PRG_Task_Sequence` é o invólucro para o projeto integrador. Configure sessão de boot,
processo e tempos antes da primeira chamada. A sessão 1 da GVL é apenas exemplo.
O chamador deve fornecer `udiDeltaMs` a partir de uma referência monotônica válida
e `stTraceTime` com origem/validade explícitas. Não marcar tempo virtual como real.
Os snapshots de autoridade, resultado e runtime precisam vir do Control com idade
calculada pelo receptor. O mock nunca faz parte da integração real.

Importe uma única definição de cada DUT no projeto final. O adaptador deve depender
do mesmo contrato, sem criar definições com nome igual e layout divergente.
`integration/service_v02/` é opcional e fica fora do ensaio isolado. Primeiro
Sequence e Service separados; depois integração; por último o futuro Control.
