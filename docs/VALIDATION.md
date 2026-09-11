# Registro de validação — contrato Sequence 0.2

Data: 2026-09-11. Base: Sequence `0480b33`; dependência opcional:
Service `b2140a5` (branch `refactor/service-core-v0.2`, schema 2.0).

Esta página distingue resultados executados neste ambiente de testes ST apenas
preparados. A compilação e os testes que o usuário relatou na versão importada
anteriormente não são evidência de validação desta atualização 0.2.

| Verificação | Resultado executado | Limite |
|---|---|---|
| Checker estático de `src/` + `tests/` | 36 objetos; zero achados | Não compila nem executa ST |
| Testes Python do checker | 13 aprovados | Testam o verificador |
| Testes Python do adaptador opcional | 16 aprovados | Modelo de protocolo + inspeção estática; não executam o FB ST |
| Identidade dos DUTs Service | 9 blobs correspondem ao commit fixado | Verifica bytes, não compatibilidade binária ou runtime |
| Checker conjunto: núcleo, testes, adaptador e 9 DUTs Service | 50 objetos; zero achados | Dependências, enums e estrutura; não valida todas as expressões/assinaturas |
| Bundle textual e ordem de importação | Gerados para os 36 objetos isolados | Adaptador fica fora do bundle básico |
| Revisão independente | Proveniência de eventos, ACK e expectativas dos testes revisados | Inspeção, não execução |
| Compilação Machine Expert 2.6 da versão 0.2 | Pendente | IDE/compilador não disponível aqui |
| Execução dos PRGs ST atualizados | Pendente | Requer projeto separado no simulador |
| Integração real Sequence + Service | Bloqueada pelos itens do contrato | Falta retenção completa e recibo transacional no Service fixado |

## Testes nativos preparados, ainda não executados nesta versão

| Programa | Alvo esperado | Escopo |
|---|---|---|
| `PRG_SEQ_SupportTests` | 40 grupos, zero falhas | Timer, receita, gate, fila e ACK |
| `PRG_SEQ_IntegrationTests` | 28 verificações, zero falhas | Sequence com Control em memória; não integra Service |
| `PRG_SEQ_LifecycleTests` | 56 verificações, zero falhas | Hold/Resume, conclusão, Stop/Abort/Release, Reset |
| `PRG_SEQ_AuthorityTests` | 8 verificações, zero falhas | Correlação de autoridade |
| `PRG_SEQ_TraceTests` | `xDone=TRUE / uiChecks=16 / uiFailures=0 / uiFirstFailureStep=65535` | Fixtures diretas do builder; quiet scan, tempo, referências e eventos sem conclusão inventada |
| `PRG_SEQ_TraceEngineTests` | `xDone=TRUE / uiTests=33 / uiFailures=0 / uiFirstFailure=65535` | Núcleo completo em Idle/falha: relógio, origem, ACK, publicação, overflow e identidade imutável |
| `integration/service_v02/tests/PRG_SEQ_ServiceAdapterTests` | `xDone=TRUE / uiChecks=23 / uiFailures=0 / uiFirstFailure=0` | Recibo completo, confirmação mantida, revogação, novo head e origem sem horário |

Os novos fixtures não acionam equipamento e não medem tempo real. Nenhum valor
esperado acima deve ser apresentado como resultado observado antes da execução.

## Comandos reproduzíveis

Na raiz do Sequence:

```bash
python3 tools/check_sources.py --source-dir src --source-dir tests
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 -m unittest discover -s integration/service_v02/tests -v
python3 tools/build_bundle.py --source-dir src --source-dir tests
python3 integration/service_v02/verify_service_dependency.py PATH_TO_FB_SERVICE
```

Para a verificação estática conjunta, usar um diretório pai contendo o Sequence
e uma cópia exata dos nove DUTs fixados, sem duplicar tipos dentro do núcleo.
Executar o checker com `--root` nesse pai e quatro `--source-dir`: Sequence
`src`, Sequence `tests`, Sequence `integration/service_v02` e o diretório
dos DUTs do Service. No ambiente desta revisão isso verificou 50 objetos.

O checker verifica tipos conhecidos, membros e wire values de enums, nomes,
delimitadores, dependências/ciclos e ausência de endereçamento físico. Ele não
valida todas as expressões, conversões ou regras do compilador do destino.

## Pontos corrigidos na revisão 0.2

- Tempo e contexto da etapa concluída são capturados antes do reset do timer.
- Confirmação de prompt identifica a etapa/intenção anterior, não a seguinte.
- Eventos não atribuem todo fato do scan a um comando que pode ter sido rejeitado.
- A fila conserva sua cabeça não confirmada; perda por overflow é explícita e
  mantém `xTraceHistoryComplete=FALSE` pelo restante da instância.
- O adaptador mantém o ACK da identidade já assumida até o head mudar; uma
  revogação de publicação não pode perder um pulso e travar permanentemente a fila.
- Horário desconhecido invalida a projeção genérica; o envelope completo original
  permanece disponível. O Service não deve substituir a origem desconhecida por
  horário de ingestão como se fosse o horário do fato.
- A projeção genérica é declarada parcial. Não há recibo baseado apenas em
  `aEvents`, contagem de aceitos ou ACK de transporte.

Pendências: compilação/importação nativa, execução de todos os PRGs, medição de
custo/memória, coerência entre tasks, reinício/época, retenção completa, recibo
transacional e recuperação de perda. Ver [SERVICE_HANDOFF.md](SERVICE_HANDOFF.md),
[MIGRATION_0_2.md](MIGRATION_0_2.md) e [STANDARDS_ALIGNMENT.md](STANDARDS_ALIGNMENT.md).
Nenhuma certificação ou conformidade normativa é declarada.
