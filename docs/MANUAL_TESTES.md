# Manual de testes do FB_Sequence

Manual de bancada para entender como as entradas da demonstração alteram
comandos, autoridade, intenções ao ControlMock, etapas, tempos e eventos.
As 14 fichas relacionam condição de partida, estímulo, componentes afetados,
resultado esperado, diagnóstico e reposição.

## Arquivos

| Arquivo | Uso |
| --- | --- |
| [Manual em PDF](manuals/FB_Sequence/manual.pdf) | Consulta e impressão das 14 fichas de teste |
| [Manual em Markdown](manuals/FB_Sequence/manual.md) | Conteúdo editável e revisão pelo Git |
| [Diagramas SVG](manuals/FB_Sequence/diagrams/) | Diagramas vetoriais editáveis do manual |

## Referência de código

- Branch: `codex/sequence-traceability-v0.2`.
- Corte inspecionado: [`00f2953808e267bfdbc637347fea88737466e5bd`](https://github.com/luisauguszvc95-dot/FB_Sequence/commit/00f2953808e267bfdbc637347fea88737466e5bd).
- Demo: `PRG_SEQ_Demo`, com `FB_SEQ_ControlMock`, exclusivamente em simulação.
- Contrato: Sequence 0.2; o corte antigo de `main` não contém todos os campos descritos.

Os critérios do manual são **expectativas derivadas do código**, não registros
de testes executados. Compilação, execução no simulador e coleta de evidências
continuam sendo etapas próprias, conforme [VALIDATION.md](VALIDATION.md).

## Como consultar

Use o mapa dos componentes para escolher o domínio que deseja observar e abra
a ficha correspondente. Preserve as quatro Watches já organizadas. Altere as
entradas superiores de `PRG_SEQ_Demo`; saídas, snapshots e estados internos são
observações, não pontos de injeção dos ensaios manuais.

A receita de observação proposta no manual amplia tempos para leitura humana
das Watches e deve ser carregada explicitamente; não altera a receita padrão
versionada na Demo. O tempo permanece sintético.

Service e Sequence continuam sendo testados separadamente. Este manual não
executa o adaptador opcional, não conclui integração entre os FBs e não envolve
equipamento real. Para o ciclo procedural e as fronteiras, consulte também
[LIFECYCLE.md](LIFECYCLE.md) e [IMPORT_AND_DEMO.md](IMPORT_AND_DEMO.md).
