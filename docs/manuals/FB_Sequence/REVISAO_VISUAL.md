# Revisão visual — FB_Sequence

Data: 2026-09-21. Base documental: `48db5f9bc5b934ede14094e6c5f432d88baee3ed`.

O [manual PDF](manual.pdf) recebeu novos desenhos para os **80 casos atuais** do [catálogo](catalog.json). O [Markdown](manual.md) continua sendo a fonte textual. Os SVGs em `diagrams/` conservam os IDs dos casos.

## O que mudou

- Fluxos organizados de cima para baixo, com ramos e retornos em faixas próprias.
- Letras Helvetica maiores, espaçamento consistente, caixas alinhadas e cotovelos arredondados.
- Pontas de seta e tracejados vetoriais explícitos, preservados na exportação para PDF.
- Título e descrição acessível em cada SVG; metadados mantêm o grafo original para comparação.

Os rótulos, papéis dos nós, sentidos das relações e tipos de aresta vieram do catálogo existente. O catálogo e o texto técnico do manual não foram reescritos.

## Evidência da revisão

| Verificação documental | Resultado |
|---|---|
| Diagramas substituídos | 80/80 |
| Páginas preservadas | 95 |
| Links e destinos preservados | 638 |
| Marcadores preservados | 89 |
| Texto e posições fora dos diagramas | Iguais ao PDF original |
| Pixels fora dos diagramas, a 72 dpi | Iguais; margem de 2 pixels excluída |
| Grafos do catálogo e metadados SVG | Iguais |
| Rótulos visíveis e pesquisáveis | Preservados |
| Sobreposição e limites geométricos verificados | Nenhum conflito detectado |

O [relatório de preservação](visual-preservation.json) registra hashes e verificações por página e caso. A igualdade do grafo é conferida nos metadados; a revisão visual complementa essa comparação para avaliar o desenho das setas. As páginas de amostra também foram renderizadas após a inserção no PDF.

Esta evidência é de apresentação documental. Não declara execução dos casos, compilação ST, simulação no IDE ou integração funcional.

## Fontes e reprodução

As ferramentas em [tools](../tools/) redesenham o catálogo e substituem somente as regiões dos diagramas de um PDF original. Dependência usada nesta revisão: Python 3 e PyMuPDF 1.26.6, registrada em [requirements.txt](../tools/requirements.txt).

A partir da raiz deste repositório:

```bash
python docs/manuals/tools/render_diagrams.py --catalog docs/manuals/FB_Sequence/catalog.json --output build/visual-review/diagrams
```

A saída contém SVGs, geometria, relatório e galeria HTML local. Para aplicar a um PDF anterior, preserve uma cópia do original fora do destino. O comando abaixo exige que o diretório `build/visual-review/` exista e que o PDF de saída ainda não exista:

```bash
python docs/manuals/tools/patch_manual_pdf.py original.pdf build/visual-review/diagrams build/visual-review/manual.pdf --catalog docs/manuals/FB_Sequence/catalog.json --qa build/visual-review/preservation.json
```

Confira o relatório e abra o PDF resultante antes de substituir o arquivo publicado. O verificador exige cobertura completa do catálogo, rótulos compatíveis e preservação do restante do documento.

## Histórico

Os 14 SVGs legados, com identificadores anteriores ao catálogo atual, permanecem como histórico. Eles não compõem os 80 diagramas desta edição. O antigo PDF combinado de Service e Sequence também permanece histórico; os manuais atuais são separados por FB.
