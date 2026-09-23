# Alinhamento técnico e evidências — FB_Sequence

**Escopo:** contrato Sequence 0.1, com integração ao Service por adaptação explícita.
Este documento registra decisões de engenharia e limites verificáveis. Não é uma
declaração de conformidade integral, certificação ISA/IEC ou validação de segurança.
Foram consultados escopos públicos e documentação oficial; não houve revisão
cláusula a cláusula do texto integral das normas pagas.

## Referências e aplicação

| Referência | Aplicação neste repositório | Limite da afirmação |
|---|---|---|
| [IEC 61131-3:2025](https://webstore.iec.ch/en/publication/68533) | Organização em tipos, funções, FBs e programas; contratos tipados e implementação em ST | A norma trata de sintaxe e semântica. Usar várias linguagens não comprova conformidade; suporte do compilador/target precisa ser verificado. |
| [ISA88 — escopo público](https://www.isa.org/standards-and-publications/isa-standards/isa-standards-committees/isa88), família ISA-88/IEC 61512 | Separação entre receita aplicada, execução sequencial e comportamento dos equipamentos | Há um motor linear de até 16 etapas, não um modelo S88 completo nem uma hierarquia procedure/unit procedure/operation/phase implementada. |
| [ISA95 — escopo público](https://www.isa.org/standards-and-publications/isa-standards/isa-standards-committees/isa95), família ISA-95/IEC 62264 | Identidades de processo, lote, receita e revisão para contextualização externa | A divisão Service/Sequence/Control é uma decisão do projeto. Não há implementação B2MML, MES nem modelo empresarial completo. |
| [ISA18 — escopo público](https://www.isa.org/standards-and-publications/isa-standards/isa-standards-committees/isa18), ISA-18.2/IEC 62682 | Distinguir ocorrências de processo, condição de origem e apresentação externa de alarmes | A fila de eventos não implementa um sistema completo de gestão de alarmes. |
| [OPC UA — conceitos de alarmes](https://reference.opcfoundation.org/specs/OPC-10000-9/4.8) | Referência pública para separar condição ativa, reconhecimento e retenção até reset | O uso conceitual não transforma esta implementação em servidor OPC UA nem certifica conformidade IEC 62682. |
| [Schneider — estados do M241](https://product-help.schneider-electric.com/Machine%20Expert/V2.2/en/m241prg/m241prg/D-SE-0008844.html) | Diferenciar estado do CLP, estado da sequência e validade dos dados | Fonte do manual V2.2; confirmar no ambiente Machine Expert 2.6. Em STOPPED, serviços de comunicação podem continuar alterando memória. |

## Matriz de implementação, evidência e pendência

“Implementado” significa presente nas fontes. Lint e inspeção não comprovam execução ST.

| Área | Implementado nas fontes | Evidência no repositório | Pendente |
|---|---|---|---|
| Fronteiras | Sequence solicita intenções; Control concede autoridade e devolve feedback; Service entrega pedidos e consome publicação | `docs/ARCHITECTURE.md`, `docs/SERVICE_HANDOFF.md`, `src/gvl/GVL_SEQ_IF.st` | Adaptador real de Control e validação de autoridade no consumidor |
| Ciclo | Estados de execução, suspensão, encerramento e falha; conclusão depende de feedback correlacionado | `src/fb/FB_Sequence.st`, `tests/`, `docs/VALIDATION.md` | Compilação e execução dos cenários no IDE; políticas físicas de cada perfil |
| Comandos | Identificação de sessão/comando, proteção contra repetição e resultado do pedido separado do estado do processo | `src/fb/FB_SEQ_CommandGate.st`, `src/dut/ST_SEQ_COMMAND_RESULT.st`, `docs/INTEGRATION.md` | Teste integrado com a ponte do Service, inclusive aceitação sem conclusão e reconciliação após timeout |
| Receita | Validação estrutural, cópia aplicada identificada por revisão, até 16 etapas lineares | `src/fb/FB_SEQ_RecipeValidator.st`, `src/dut/ST_SEQ_RECIPE.st`, `src/dut/ST_SEQ_STEP.st` | Hierarquia procedural, unidades/faixas, valores não finitos e validação dos parâmetros/perfis na máquina |
| Temporização | Tempo qualificado acumulado, política de Hold e limites de espera documentados | `src/fb/FB_SEQ_QualifiedTimer.st`, `src/functions/F_SEQ_AddMs.st`, `docs/ARCHITECTURE.md` | Fonte real do delta, medição temporal no target e qualificação dos critérios de processo |
| Eventos | Fila limitada, correlação/contexto congelado e sinalização de perda | `src/fb/FB_SEQ_EventQueue.st`, `src/dut/ST_SEQ_EVENT.st`, `tests/` | Persistência durável, política de retenção e tratamento operacional da saturação |
| Concorrência | Escritores e ordem de chamada identificados; demonstração em uma task | `docs/INTEGRATION.md`, `tests/PRG_SEQ_Demo.st` | Mailbox e snapshot coerente entre tasks separadas; atribuição de STRUCT não prova atomicidade |
| Reinício | Ausência de retomada automática de lote documentada; sessão integra a correlação | `docs/ARCHITECTURE.md`, `docs/INTEGRATION.md` | Protocolo coordenado de restart, destino dos requests antigos e reconciliação com o Control real |
| Segurança | Sem acesso a I/O físico; diagnóstico/autoridade operacional não são função de proteção | `docs/ARCHITECTURE.md`, verificações de fontes | Projeto e validação das funções de segurança pertencem à aplicação e aos componentes apropriados |
| Integração | Contrato 0.1 preservado e tradução externa prevista | `docs/SERVICE_HANDOFF.md`; ponte em `FB_Service/integrations/sequence/` no repositório parceiro | Compilação conjunta, compatibilidade das versões e execução integrada no simulador |

## Checklist de engenharia rastreável

Registrar em `docs/VALIDATION.md` e nos relatórios de `tests/` a versão dos fontes,
o cenário, o resultado observado e o ambiente. Não promover resultado esperado a observado.

- [ ] Compilar as fontes ST e a integração no Machine Expert 2.6, registrando target e bibliotecas.
- [ ] Executar os testes ST de suporte e integração, incluindo caminhos de falha.
- [ ] Demonstrar que ACK de transporte, aceite de comando, conclusão de etapa e liberação de recurso são distintos.
- [ ] Demonstrar deduplicação, resposta tardia e solicitação de sessão/lote/etapa incorretos.
- [ ] Verificar perda/retorno da autoridade, Hold/Resume e encerramento sem confirmação do Control.
- [ ] Verificar receita inválida e edição da candidata durante execução da cópia aplicada.
- [ ] Medir tempos e verificar a política do delta, Hold e perda de qualificação no target.
- [ ] Validar overflow de eventos e reinício com requests/ACKs remanescentes.
- [ ] Projetar e testar sincronização antes de separar Control, Sequence e Service em tasks.
- [ ] Vincular cada perfil de processo a especificação, parâmetros, permissivos, feedback e critérios de aceite.

Estas verificações são gates de engenharia do projeto, não uma lista de cláusulas
normativas. A etapa atual prepara revisão e simulação; não autoriza comissionamento
de uma máquina nem demonstra segurança funcional.
