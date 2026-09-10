# Próximos incrementos

| Ordem | Entrega | Dono | Critério de saída |
|---|---|---|---|
| 1 | Compilar fontes e executar os POUs offline | Sequence | Sem erros de compilação; contadores de falha zerados |
| 2 | Alinhar contratos 0.1 com Service | Integração | Mesmos IDs, layouts, correlação, permissões e política de ACK |
| 3 | Adaptar Control IF e projeção do runtime | Control | Rejeita autoridade inválida, perfis desconhecidos e pedidos vencidos; publica feedback correlacionado |
| 4 | Mailboxes e relógio monotônico no alvo | Integração | Snapshots coerentes entre tasks, frescor e reinício ensaiados |
| 5 | Primeira implementação de perfil de processo | Aplicação/Control | Critérios e parâmetros documentados; Sequence avança somente por feedback autorizado |
| 6 | Arbitragem compartilhada/CIP | Control e coordenador de recursos | Posse por sessão/lote/token, liberação confirmada e nenhuma concessão concorrente indevida |
| 7 | Fases compostas e ramificações | Sequence | Política de transição e retomada explícita; testes adicionais |
| 8 | Persistência e recuperação de lote | Integração | Reconciliação com Control, sessão nova e autorização antes de qualquer retomada |

A base atual não implementa o árbitro multiunidade/CIP, GRAFCET paralelo, persistência,
reconciliação pós-restart, relógio de calendário, historiador, MQTT, tela HMI ou Control
de equipamentos. O contrato deixa esses pontos visíveis para evoluir com seus donos.

O próximo incremento deve começar pelos gates de compilação e integração, sem ampliar
o catálogo de FBs antes de confirmar o comportamento da base.
