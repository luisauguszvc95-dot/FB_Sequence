# Importação e demonstração offline

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
não medição de duração real da task.

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

Execute `PRG_SEQ_SupportTests` e `PRG_SEQ_IntegrationTests` somente na simulação.
Cada um expõe `uiChecks`, `uiFailures` e `xDone`. O gate de aprovação é `xDone = TRUE`
e `uiFailures = 0`. Os testes de integração têm timeout de progresso para não ficarem
esperando indefinidamente um estado que não chegou.

## Integração futura

`PRG_Task_Sequence` é o invólucro para o projeto integrador. Configure sessão de boot,
processo e tempos antes da primeira chamada. A sessão 1 da GVL é apenas exemplo.
O chamador deve fornecer `udiDeltaMs` a partir de uma referência monotônica válida.
Os snapshots de autoridade, resultado e runtime precisam vir do Control com idade
calculada pelo receptor. O mock nunca faz parte da integração real.

Importe uma única definição de cada DUT no projeto final. O Service deve depender do
mesmo contrato, em vez de criar uma segunda definição com nome igual ou layout divergente.
