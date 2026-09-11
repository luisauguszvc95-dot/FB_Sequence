# Roadmap após a revisão 0.2

Status atual: preparação para auditoria/rastreabilidade nas fontes. O usuário
atualizará o projeto e executará os ensaios em outra sessão. Não marcar a Sequence,
o Service ou a integração como aprovados apenas pela preparação dos arquivos.

| Ordem | Entrega | Dono | Critério de saída |
|---|---|---|---|
| 1 | Teste isolado da Sequence 0.2 | Sequence | Compilação no Machine Expert 2.6 e ensaios de ciclo/autoridade/trace com resultados observados registrados |
| 2 | Teste isolado do Service v0.2 | Service | Evidência independente de ingestão, observações, transporte e limites na revisão escolhida |
| 3 | Integração Sequence ↔ Service | Integração | Envelope integral preservado, projeção parcial identificada, recibo/ACK correto, tempo/perdas/reinício ensaiados |
| 4 | Preparação do futuro `FB_Central_Cip_Control` | Control/aplicação | Especificação de perfis, recursos e projeção de runtime; nenhum mock confundido com Control real |
| 5 | Ampliação após os gates anteriores | Donos dos módulos | Requisitos e testes próprios para os incrementos abaixo |

As etapas 1 e 2 são independentes; a etapa 3 depende das duas. A pasta opcional
`integration/service_v02/` prepara o encaixe, mas não fecha o gate 3. O Service
fixado em `b2140a5ab4756f1c435ebcf7848270dad2f097d5` é de observação; dispatcher
e catálogo de receitas continuam componentes externos futuros.

## Incrementos ainda não implementados

| Tema | Entrega futura | Fronteira |
|---|---|---|
| Receita | Parâmetros tipados, unidades, limites, revisão do schema, identificador/hash de conteúdo e aprovação | Catálogo externo + validação da Sequence e do perfil Control |
| Procedural | Origem hierárquica da receita, política de duração contínua, fases compostas/ramificações e mapa formal PackML | Sequence; sem mover comportamento de equipamento para o motor |
| Motivos | Separar rejeições, falhas e qualidade; motivos de parada com semântica documentada | Cada produtor classifica seus fatos; Service expõe, não inventa a condição |
| Rastreabilidade durável | Persistência integral, retenção, deduplicação, política de overflow e lacunas entre boots | Consumidor externo e Service; sem declarar entrega exatamente uma vez |
| Tempo, concorrência e recuperação | Relógio real, correlação UTC com qualidade, snapshots coerentes, sessão e reconciliação | Integração na plataforma; nova sessão não resolve posse nem restaura histórico |

A divisão do `FB_Sequence` em módulos menores pode ser considerada depois de
estabilizar o comportamento com testes. Esta revisão não faz uma refatoração
total do ciclo nem implementa equipamentos, funções de proteção, MES ou OEE.
