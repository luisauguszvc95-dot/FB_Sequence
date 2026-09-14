# Manual de testes por comportamento — FB_Sequence

80 fichas, organizadas em 14 grupos, com um diagrama próprio para cada teste. O manual relaciona a alteração de uma entrada, os componentes afetados e o resultado que deve ser observado. Índices por componente e tipo, glossário e formulário de evidências apoiam a consulta pelo setor.

## Arquivos

| Arquivo | Uso |
| --- | --- |
| [Manual em PDF](manuals/FB_Sequence/manual.pdf) | Consulta, impressão e navegação por índices |
| [Manual em Markdown](manuals/FB_Sequence/manual.md) | Leitura e revisão do conteúdo no Git |
| [Catálogo JSON](manuals/FB_Sequence/catalog.json) | Fichas estruturadas, classificações e fontes |
| [Diagramas SVG](manuals/FB_Sequence/diagrams/) | Diagramas vetoriais específicos de cada ficha |

Este repositório mantém um único PDF do seu FB. A atualização substitui a edição anterior no mesmo caminho.

## Índice por componente

| Componente / grupo | Fichas | Quantidade |
| --- | --- | ---: |
| Inicialização e configuração | [SEQ-001](manuals/FB_Sequence/manual.md#seq-001), [SEQ-002](manuals/FB_Sequence/manual.md#seq-002), [SEQ-003](manuals/FB_Sequence/manual.md#seq-003), [SEQ-004](manuals/FB_Sequence/manual.md#seq-004) | 4 |
| Receita aplicada | [SEQ-005](manuals/FB_Sequence/manual.md#seq-005), [SEQ-006](manuals/FB_Sequence/manual.md#seq-006), [SEQ-007](manuals/FB_Sequence/manual.md#seq-007) | 3 |
| Admissão de comandos | [SEQ-008](manuals/FB_Sequence/manual.md#seq-008), [SEQ-009](manuals/FB_Sequence/manual.md#seq-009), [SEQ-010](manuals/FB_Sequence/manual.md#seq-010), [SEQ-011](manuals/FB_Sequence/manual.md#seq-011), [SEQ-012](manuals/FB_Sequence/manual.md#seq-012), [SEQ-013](manuals/FB_Sequence/manual.md#seq-013), [SEQ-014](manuals/FB_Sequence/manual.md#seq-014) | 7 |
| Critérios de etapa | [SEQ-015](manuals/FB_Sequence/manual.md#seq-015), [SEQ-016](manuals/FB_Sequence/manual.md#seq-016), [SEQ-017](manuals/FB_Sequence/manual.md#seq-017), [SEQ-018](manuals/FB_Sequence/manual.md#seq-018), [SEQ-019](manuals/FB_Sequence/manual.md#seq-019) | 5 |
| Pausa e encerramento | [SEQ-020](manuals/FB_Sequence/manual.md#seq-020), [SEQ-021](manuals/FB_Sequence/manual.md#seq-021), [SEQ-022](manuals/FB_Sequence/manual.md#seq-022), [SEQ-023](manuals/FB_Sequence/manual.md#seq-023), [SEQ-024](manuals/FB_Sequence/manual.md#seq-024), [SEQ-025](manuals/FB_Sequence/manual.md#seq-025), [SEQ-026](manuals/FB_Sequence/manual.md#seq-026), [SEQ-027](manuals/FB_Sequence/manual.md#seq-027) | 8 |
| Falhas e recuperação | [SEQ-028](manuals/FB_Sequence/manual.md#seq-028), [SEQ-036](manuals/FB_Sequence/manual.md#seq-036), [SEQ-037](manuals/FB_Sequence/manual.md#seq-037) | 3 |
| Limites e prazos | [SEQ-029](manuals/FB_Sequence/manual.md#seq-029), [SEQ-030](manuals/FB_Sequence/manual.md#seq-030), [SEQ-031](manuals/FB_Sequence/manual.md#seq-031) | 3 |
| Autoridade e correlação | [SEQ-032](manuals/FB_Sequence/manual.md#seq-032), [SEQ-033](manuals/FB_Sequence/manual.md#seq-033), [SEQ-034](manuals/FB_Sequence/manual.md#seq-034), [SEQ-035](manuals/FB_Sequence/manual.md#seq-035), [SEQ-038](manuals/FB_Sequence/manual.md#seq-038), [SEQ-039](manuals/FB_Sequence/manual.md#seq-039), [SEQ-040](manuals/FB_Sequence/manual.md#seq-040) | 7 |
| Publicação e rastreabilidade | [SEQ-041](manuals/FB_Sequence/manual.md#seq-041), [SEQ-042](manuals/FB_Sequence/manual.md#seq-042), [SEQ-043](manuals/FB_Sequence/manual.md#seq-043), [SEQ-044](manuals/FB_Sequence/manual.md#seq-044), [SEQ-045](manuals/FB_Sequence/manual.md#seq-045) | 5 |
| Validação estrutural de receitas | [SEQ-046](manuals/FB_Sequence/manual.md#seq-046), [SEQ-047](manuals/FB_Sequence/manual.md#seq-047), [SEQ-048](manuals/FB_Sequence/manual.md#seq-048), [SEQ-049](manuals/FB_Sequence/manual.md#seq-049), [SEQ-050](manuals/FB_Sequence/manual.md#seq-050), [SEQ-051](manuals/FB_Sequence/manual.md#seq-051), [SEQ-052](manuals/FB_Sequence/manual.md#seq-052) | 7 |
| Temporizadores e aritmética | [SEQ-053](manuals/FB_Sequence/manual.md#seq-053), [SEQ-054](manuals/FB_Sequence/manual.md#seq-054), [SEQ-055](manuals/FB_Sequence/manual.md#seq-055), [SEQ-056](manuals/FB_Sequence/manual.md#seq-056), [SEQ-057](manuals/FB_Sequence/manual.md#seq-057), [SEQ-058](manuals/FB_Sequence/manual.md#seq-058) | 6 |
| Admissão de comandos no suporte | [SEQ-059](manuals/FB_Sequence/manual.md#seq-059), [SEQ-060](manuals/FB_Sequence/manual.md#seq-060), [SEQ-061](manuals/FB_Sequence/manual.md#seq-061), [SEQ-062](manuals/FB_Sequence/manual.md#seq-062), [SEQ-063](manuals/FB_Sequence/manual.md#seq-063) | 5 |
| Fila de eventos no suporte | [SEQ-064](manuals/FB_Sequence/manual.md#seq-064), [SEQ-065](manuals/FB_Sequence/manual.md#seq-065), [SEQ-066](manuals/FB_Sequence/manual.md#seq-066), [SEQ-067](manuals/FB_Sequence/manual.md#seq-067), [SEQ-068](manuals/FB_Sequence/manual.md#seq-068), [SEQ-069](manuals/FB_Sequence/manual.md#seq-069), [SEQ-070](manuals/FB_Sequence/manual.md#seq-070) | 7 |
| Construção de fatos de rastreabilidade | [SEQ-071](manuals/FB_Sequence/manual.md#seq-071), [SEQ-072](manuals/FB_Sequence/manual.md#seq-072), [SEQ-073](manuals/FB_Sequence/manual.md#seq-073), [SEQ-074](manuals/FB_Sequence/manual.md#seq-074), [SEQ-075](manuals/FB_Sequence/manual.md#seq-075), [SEQ-076](manuals/FB_Sequence/manual.md#seq-076), [SEQ-077](manuals/FB_Sequence/manual.md#seq-077), [SEQ-078](manuals/FB_Sequence/manual.md#seq-078), [SEQ-079](manuals/FB_Sequence/manual.md#seq-079), [SEQ-080](manuals/FB_Sequence/manual.md#seq-080) | 10 |

## Índice por tipo de teste

| Tipo | Fichas | Quantidade |
| --- | --- | ---: |
| Funcional | [SEQ-001](manuals/FB_Sequence/manual.md#seq-001), [SEQ-005](manuals/FB_Sequence/manual.md#seq-005), [SEQ-009](manuals/FB_Sequence/manual.md#seq-009), [SEQ-017](manuals/FB_Sequence/manual.md#seq-017), [SEQ-018](manuals/FB_Sequence/manual.md#seq-018), [SEQ-020](manuals/FB_Sequence/manual.md#seq-020), [SEQ-022](manuals/FB_Sequence/manual.md#seq-022), [SEQ-023](manuals/FB_Sequence/manual.md#seq-023), [SEQ-024](manuals/FB_Sequence/manual.md#seq-024), [SEQ-053](manuals/FB_Sequence/manual.md#seq-053), [SEQ-064](manuals/FB_Sequence/manual.md#seq-064), [SEQ-071](manuals/FB_Sequence/manual.md#seq-071) | 12 |
| Contrato e validação | [SEQ-002](manuals/FB_Sequence/manual.md#seq-002), [SEQ-003](manuals/FB_Sequence/manual.md#seq-003), [SEQ-006](manuals/FB_Sequence/manual.md#seq-006), [SEQ-007](manuals/FB_Sequence/manual.md#seq-007), [SEQ-008](manuals/FB_Sequence/manual.md#seq-008), [SEQ-010](manuals/FB_Sequence/manual.md#seq-010), [SEQ-011](manuals/FB_Sequence/manual.md#seq-011), [SEQ-012](manuals/FB_Sequence/manual.md#seq-012), [SEQ-013](manuals/FB_Sequence/manual.md#seq-013), [SEQ-014](manuals/FB_Sequence/manual.md#seq-014), [SEQ-019](manuals/FB_Sequence/manual.md#seq-019), [SEQ-021](manuals/FB_Sequence/manual.md#seq-021), [SEQ-027](manuals/FB_Sequence/manual.md#seq-027), [SEQ-034](manuals/FB_Sequence/manual.md#seq-034), [SEQ-038](manuals/FB_Sequence/manual.md#seq-038), [SEQ-046](manuals/FB_Sequence/manual.md#seq-046), [SEQ-047](manuals/FB_Sequence/manual.md#seq-047), [SEQ-049](manuals/FB_Sequence/manual.md#seq-049), [SEQ-050](manuals/FB_Sequence/manual.md#seq-050), [SEQ-052](manuals/FB_Sequence/manual.md#seq-052), [SEQ-056](manuals/FB_Sequence/manual.md#seq-056), [SEQ-059](manuals/FB_Sequence/manual.md#seq-059), [SEQ-060](manuals/FB_Sequence/manual.md#seq-060), [SEQ-061](manuals/FB_Sequence/manual.md#seq-061), [SEQ-062](manuals/FB_Sequence/manual.md#seq-062), [SEQ-065](manuals/FB_Sequence/manual.md#seq-065), [SEQ-069](manuals/FB_Sequence/manual.md#seq-069), [SEQ-070](manuals/FB_Sequence/manual.md#seq-070), [SEQ-075](manuals/FB_Sequence/manual.md#seq-075), [SEQ-079](manuals/FB_Sequence/manual.md#seq-079) | 30 |
| Limites e temporização | [SEQ-004](manuals/FB_Sequence/manual.md#seq-004), [SEQ-015](manuals/FB_Sequence/manual.md#seq-015), [SEQ-016](manuals/FB_Sequence/manual.md#seq-016), [SEQ-029](manuals/FB_Sequence/manual.md#seq-029), [SEQ-030](manuals/FB_Sequence/manual.md#seq-030), [SEQ-031](manuals/FB_Sequence/manual.md#seq-031), [SEQ-040](manuals/FB_Sequence/manual.md#seq-040), [SEQ-048](manuals/FB_Sequence/manual.md#seq-048), [SEQ-051](manuals/FB_Sequence/manual.md#seq-051), [SEQ-055](manuals/FB_Sequence/manual.md#seq-055), [SEQ-057](manuals/FB_Sequence/manual.md#seq-057), [SEQ-058](manuals/FB_Sequence/manual.md#seq-058), [SEQ-063](manuals/FB_Sequence/manual.md#seq-063), [SEQ-067](manuals/FB_Sequence/manual.md#seq-067), [SEQ-068](manuals/FB_Sequence/manual.md#seq-068) | 15 |
| Falhas e recuperação | [SEQ-025](manuals/FB_Sequence/manual.md#seq-025), [SEQ-028](manuals/FB_Sequence/manual.md#seq-028), [SEQ-032](manuals/FB_Sequence/manual.md#seq-032), [SEQ-033](manuals/FB_Sequence/manual.md#seq-033), [SEQ-035](manuals/FB_Sequence/manual.md#seq-035), [SEQ-036](manuals/FB_Sequence/manual.md#seq-036), [SEQ-037](manuals/FB_Sequence/manual.md#seq-037), [SEQ-039](manuals/FB_Sequence/manual.md#seq-039), [SEQ-054](manuals/FB_Sequence/manual.md#seq-054), [SEQ-066](manuals/FB_Sequence/manual.md#seq-066), [SEQ-077](manuals/FB_Sequence/manual.md#seq-077) | 11 |
| Rastreabilidade e persistência | [SEQ-026](manuals/FB_Sequence/manual.md#seq-026), [SEQ-041](manuals/FB_Sequence/manual.md#seq-041), [SEQ-042](manuals/FB_Sequence/manual.md#seq-042), [SEQ-043](manuals/FB_Sequence/manual.md#seq-043), [SEQ-044](manuals/FB_Sequence/manual.md#seq-044), [SEQ-045](manuals/FB_Sequence/manual.md#seq-045), [SEQ-072](manuals/FB_Sequence/manual.md#seq-072), [SEQ-073](manuals/FB_Sequence/manual.md#seq-073), [SEQ-074](manuals/FB_Sequence/manual.md#seq-074), [SEQ-076](manuals/FB_Sequence/manual.md#seq-076), [SEQ-078](manuals/FB_Sequence/manual.md#seq-078), [SEQ-080](manuals/FB_Sequence/manual.md#seq-080) | 12 |

## Seleção de execução

| Seleção | Quantidade | Uso |
| --- | ---: | --- |
| Essencial | 47 | Percursos iniciais para conhecer o comportamento e estabelecer a base. |
| Completa | 30 | Variações, rejeições e recuperação das interfaces. |
| Aprofundamento | 3 | Fronteiras ou condições que exigem uma bancada específica. |

Esses rótulos orientam a seleção dos ensaios e não representam severidade de máquina. A ficha diferencia a demonstração existente de uma bancada dedicada de software a preparar. Um ambiente ainda não preparado mantém o ensaio como Não executado.

## Correspondência da edição anterior

Os IDs anteriores são referências de consulta. Sua correspondência abaixo não transfere aprovação de execução para as novas fichas.

| ID anterior | Novas fichas relacionadas |
| --- | --- |
| SEQ-01 | [SEQ-001](manuals/FB_Sequence/manual.md#seq-001), [SEQ-040](manuals/FB_Sequence/manual.md#seq-040) |
| SEQ-02 | [SEQ-005](manuals/FB_Sequence/manual.md#seq-005), [SEQ-006](manuals/FB_Sequence/manual.md#seq-006), [SEQ-007](manuals/FB_Sequence/manual.md#seq-007), [SEQ-046](manuals/FB_Sequence/manual.md#seq-046), [SEQ-047](manuals/FB_Sequence/manual.md#seq-047), [SEQ-048](manuals/FB_Sequence/manual.md#seq-048), [SEQ-049](manuals/FB_Sequence/manual.md#seq-049), [SEQ-050](manuals/FB_Sequence/manual.md#seq-050), [SEQ-051](manuals/FB_Sequence/manual.md#seq-051), [SEQ-052](manuals/FB_Sequence/manual.md#seq-052) |
| SEQ-03 | [SEQ-008](manuals/FB_Sequence/manual.md#seq-008), [SEQ-009](manuals/FB_Sequence/manual.md#seq-009), [SEQ-010](manuals/FB_Sequence/manual.md#seq-010), [SEQ-011](manuals/FB_Sequence/manual.md#seq-011), [SEQ-012](manuals/FB_Sequence/manual.md#seq-012) |
| SEQ-04 | [SEQ-015](manuals/FB_Sequence/manual.md#seq-015), [SEQ-016](manuals/FB_Sequence/manual.md#seq-016), [SEQ-053](manuals/FB_Sequence/manual.md#seq-053), [SEQ-054](manuals/FB_Sequence/manual.md#seq-054), [SEQ-055](manuals/FB_Sequence/manual.md#seq-055), [SEQ-056](manuals/FB_Sequence/manual.md#seq-056), [SEQ-057](manuals/FB_Sequence/manual.md#seq-057) |
| SEQ-05 | [SEQ-017](manuals/FB_Sequence/manual.md#seq-017) |
| SEQ-06 | [SEQ-018](manuals/FB_Sequence/manual.md#seq-018), [SEQ-019](manuals/FB_Sequence/manual.md#seq-019), [SEQ-022](manuals/FB_Sequence/manual.md#seq-022) |
| SEQ-07 | [SEQ-020](manuals/FB_Sequence/manual.md#seq-020), [SEQ-021](manuals/FB_Sequence/manual.md#seq-021) |
| SEQ-08 | [SEQ-013](manuals/FB_Sequence/manual.md#seq-013), [SEQ-023](manuals/FB_Sequence/manual.md#seq-023), [SEQ-024](manuals/FB_Sequence/manual.md#seq-024), [SEQ-026](manuals/FB_Sequence/manual.md#seq-026), [SEQ-027](manuals/FB_Sequence/manual.md#seq-027) |
| SEQ-09 | [SEQ-025](manuals/FB_Sequence/manual.md#seq-025), [SEQ-032](manuals/FB_Sequence/manual.md#seq-032), [SEQ-033](manuals/FB_Sequence/manual.md#seq-033), [SEQ-034](manuals/FB_Sequence/manual.md#seq-034), [SEQ-035](manuals/FB_Sequence/manual.md#seq-035) |
| SEQ-10 | [SEQ-036](manuals/FB_Sequence/manual.md#seq-036), [SEQ-037](manuals/FB_Sequence/manual.md#seq-037) |
| SEQ-11 | [SEQ-029](manuals/FB_Sequence/manual.md#seq-029), [SEQ-030](manuals/FB_Sequence/manual.md#seq-030), [SEQ-031](manuals/FB_Sequence/manual.md#seq-031), [SEQ-038](manuals/FB_Sequence/manual.md#seq-038), [SEQ-039](manuals/FB_Sequence/manual.md#seq-039) |
| SEQ-12 | [SEQ-041](manuals/FB_Sequence/manual.md#seq-041) |
| SEQ-13 | [SEQ-059](manuals/FB_Sequence/manual.md#seq-059), [SEQ-060](manuals/FB_Sequence/manual.md#seq-060), [SEQ-061](manuals/FB_Sequence/manual.md#seq-061), [SEQ-062](manuals/FB_Sequence/manual.md#seq-062), [SEQ-063](manuals/FB_Sequence/manual.md#seq-063) |
| SEQ-14 | [SEQ-042](manuals/FB_Sequence/manual.md#seq-042), [SEQ-043](manuals/FB_Sequence/manual.md#seq-043), [SEQ-044](manuals/FB_Sequence/manual.md#seq-044), [SEQ-045](manuals/FB_Sequence/manual.md#seq-045), [SEQ-064](manuals/FB_Sequence/manual.md#seq-064), [SEQ-065](manuals/FB_Sequence/manual.md#seq-065), [SEQ-066](manuals/FB_Sequence/manual.md#seq-066), [SEQ-067](manuals/FB_Sequence/manual.md#seq-067), [SEQ-068](manuals/FB_Sequence/manual.md#seq-068), [SEQ-069](manuals/FB_Sequence/manual.md#seq-069), [SEQ-070](manuals/FB_Sequence/manual.md#seq-070), [SEQ-071](manuals/FB_Sequence/manual.md#seq-071), [SEQ-072](manuals/FB_Sequence/manual.md#seq-072), [SEQ-073](manuals/FB_Sequence/manual.md#seq-073), [SEQ-074](manuals/FB_Sequence/manual.md#seq-074), [SEQ-075](manuals/FB_Sequence/manual.md#seq-075), [SEQ-076](manuals/FB_Sequence/manual.md#seq-076), [SEQ-077](manuals/FB_Sequence/manual.md#seq-077), [SEQ-078](manuals/FB_Sequence/manual.md#seq-078), [SEQ-079](manuals/FB_Sequence/manual.md#seq-079), [SEQ-080](manuals/FB_Sequence/manual.md#seq-080) |

## Referência e evidências

Fonte técnica de referência: luisauguszvc95-dot/FB_Sequence, branch codex/sequence-traceability-v0.2, commit 00f2953808e267bfdbc637347fea88737466e5bd, contrato 0.2. Expectativas extraídas dos fontes, testes nativos e demo com ControlMock; nenhuma aprovação de execução nova é atribuída por este manual.

As fichas contêm expectativas verificáveis derivadas das fontes. A publicação do manual não declara novos testes executados. Cada execução deve registrar versão, programa raiz, pré-condições, valores antes/depois e evidências próprias. Todos os ensaios deste manual pertencem à simulação fechada, sem saídas físicas.

A demo usa PRG_SEQ_Demo e FB_SEQ_ControlMock. Comando admitido, intenção aceita, etapa concluída e recurso liberado são critérios distintos. Os IntegrationTests deste repositório não representam integração com outro FB. A [validação](VALIDATION.md) e a [importação da demo](IMPORT_AND_DEMO.md) continuam como referências complementares.

## Uso e manutenção

Escolha uma ficha pela dúvida ou pelo componente alterado. Compare cada critério da ficha e registre Aprovado, Falhou, Inconclusivo ou Não executado. Altere as entradas declaradas; estados e saídas calculadas servem à observação. Ao mudar contrato, prazo, enum ou regra de consumo, revise a ficha, o diagrama e as referências e regenere o PDF.
