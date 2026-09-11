# Preparação para auditoria e rastreabilidade — contrato 0.2

Esta revisão melhora a evidência produzida pelo software; não declara conformidade
integral ISA/IEC, certificação, assinatura eletrônica ou segurança funcional.
As referências abaixo foram verificadas em fontes oficiais públicas em 11/09/2026.
Foi consultado o escopo público, não o texto licenciado completo das normas IEC.

## Referência normativa, decisão de engenharia e limite

| Referência e escopo público | Decisão deste projeto | O que ainda não pode ser afirmado |
|---|---|---|
| [IEC 61512-1:2026](https://webstore.iec.ch/en/publication/75287): modelos e terminologia de controle batch | Separar receita aplicada, execução procedural e comportamento dos equipamentos | O motor linear não implementa toda a hierarquia procedural, os modelos ou os critérios de conformidade da norma |
| [IEC 61512-4:2009](https://webstore.iec.ch/en/publication/5531): modelo de referência para registros de produção de lote | Preservar identidades, revisão, contexto de execução e fatos imutáveis de origem | A fila volátil não é um registro de lote completo, persistente ou validado |
| [IEC 61131-3:2025](https://webstore.iec.ch/en/publication/68533): sintaxe e semântica de linguagens de controladores | ST tipado, enums, FBs, funções e POUs separados | Compilar no Machine Expert 2.6 não demonstra suporte integral à edição nem conformidade da aplicação |
| [IEC 60848:2013](https://webstore.iec.ch/en/publication/3684): linguagem de especificação GRAFCET | Documentar etapas, receptividades e transições de um processo quando necessário | Uma lista linear pode ser descrita por GRAFCET; este FB não é um interpretador geral de GRAFCET/SFC nem suporta paralelismo arbitrário |
| [OPC 30050 PackML 1.01](https://reference.opcfoundation.org/specs/OPC-30050): modelo de informação OPC UA para PackML | Preparar uma futura matriz de correspondência de estados sem renomear o motor | Estados semelhantes não demonstram máquina de estados PackML completa; não há servidor OPC UA PackML neste repositório |

Os IDs de requisitos abaixo são **requisitos de engenharia do projeto**, não
números de cláusulas normativas. Uma avaliação formal exige norma aplicável,
escopo contratado, critérios explícitos e revisão das evidências no ambiente real.

## Requisito → implementação → evidência a registrar

“Nas fontes” não significa “executado no simulador”. Os resultados e limites
das verificações ficam em [VALIDATION.md](VALIDATION.md).

| ID | Requisito de engenharia | Implementação / artefato | Evidência necessária |
|---|---|---|---|
| SEQ-AUD-01 | Fato identifica máquina, produtor, processo e sessão sem confundir origem do comando | `ST_SEQ_CONFIG`, `ST_SEQ_EVENT`, `ST_SEQ_RUNTIME` | Capturar um evento de comando com produtor e origem distintos; verificar a chave de deduplicação |
| SEQ-AUD-02 | Tempo de ocorrência permanece distinto de recepção/persistência | `ST_SEQ_TRACE_TIME`, tempo congelado no evento | Simular amostra inválida, sintética e válida; leitura tardia não muda o tick original |
| SEQ-AUD-03 | Evento descreve contexto efetivo e solicitado sem misturá-los | Campos anteriores, receita/lote solicitados e aplicados; contexto de Reset preservado | Rejeitar receita/lote incorretos e conferir ambos os contextos; Reset conserva o lote encerrado no histórico |
| SEQ-AUD-04 | Mudanças relevantes são fatos tipados | Eventos de lote, etapa, prompt, recurso, falha, receita e comando | Conferir ocorrência única, contexto e ordem nos caminhos normal, Hold/Resume, Stop, Abort e Faulted |
| SEQ-AUD-05 | Perdas locais são detectáveis e não escondidas por drenagem | Fila de 32, drop-new, contador de perdas e `xTraceHistoryComplete` | Saturar a fila; ACK posterior não faz a indicação de integridade voltar a verdadeiro |
| SEQ-AUD-06 | Origem completa só sai da fila após posse correlacionada | ACK de sessão/evento; adaptador opcional com envelope integral e recibo | Recibo ausente, errado ou de projeção parcial não confirma; recibo completo correto confirma apenas a cabeça correspondente |
| SEQ-AUD-07 | Autoridade, aceitação, conclusão e liberação são distintas | Control IF, `FB_SEQ_CommandGate`, ciclo endurecido | Ensaios de geração trocada, feedback atrasado, Resume e encerramento sem Release correlacionado |
| SEQ-AUD-08 | Consumidores não alteram a execução ou a origem | Escritor único por contrato; Service de observação isolado | Revisão de atribuições; futura prova de snapshots coerentes e autorização de publicação |
| SEQ-AUD-09 | Receita aplicada é identificável e estável durante execução | Cópia validada e revisão aplicada | Alterar a candidata sem alterar o lote ativo; validação estrutural não equivale a aprovação de processo |

## Limites que permanecem explícitos

- Persistência, retenção, backup, detecção de lacunas entre reinícios e reconciliação
  de sessão/recursos ainda dependem de implementação e testes externos.
- `uiSourceID` não comprova identidade autenticada. Autenticação, autorização,
  gestão de usuários e assinatura não foram implementadas na Sequence.
- `xTraceReady` não é selo de auditoria; `xTraceHistoryComplete` cobre somente
  perdas locais conhecidas da sessão, não toda a cadeia de coleta.
- Parâmetros tipados, unidades/faixas, hash de receita, qualificação contínua
  configurável, hierarquia procedural e taxonomia de motivos continuam no roadmap.
- Condições de origem pertencem aos produtores. Gestão de alarmes, OEE/MES,
  comunicação e segurança funcional não são funções adicionadas ao motor.

## Gates de aceitação

1. Preparação desta revisão: fontes, contratos, migração e verificações locais.
2. Sequence isolada: compilação e ensaios ST no projeto de simulação, com revisão,
   alvo, versão do IDE, resultados observados e evidências dos quatro Watches.
3. Service isolado: evidência independente no seu repositório e revisão fixada.
4. Integração Sequence/Service: preservação do envelope, ACK, perdas, autoridade,
   tempo e concorrência; somente depois preparar o futuro Control da central CIP.

Os resultados da base anterior não fecham os gates da 0.2. Nenhum teste no IDE
foi solicitado para hoje. Preparação técnica não autoriza comissionamento de máquina.
