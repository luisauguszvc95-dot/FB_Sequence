# Registro de validação — base 0.1

Data: 2026-09-10. Esta página separa evidência executada de cenários preparados.

| Verificação | Resultado | Limite da evidência |
|---|---|---|
| Checker estático sobre `src/` e fontes ST de `tests/` | 32 objetos, zero achados | Verifica o subconjunto documentado; não é compilador ST |
| Testes Python do checker | 13 testes aprovados | Exercitam o verificador, não o motor de sequência |
| Bundle e ordem de dependências | Gerados com 32 objetos | Arquivo textual; não comprova importação nativa |
| Revisão independente de contratos e lifecycle | Incorporada | Revisão manual, sem execução do runtime |
| `PRG_SEQ_SupportTests` | 40 grupos de verificações preparados | Ainda não executados no Machine Expert |
| `PRG_SEQ_IntegrationTests` | 28 verificações multiscans preparadas | Ainda não executadas no Machine Expert |
| `PRG_SEQ_LifecycleTests` | 56 verificações multiscans preparadas; rastros revisados | Ainda não executadas no Machine Expert |
| `PRG_SEQ_AuthorityTests` | 8 verificações multiscans preparadas | Ainda não executadas no Machine Expert |
| Compilação Machine Expert 2.6 | Pendente | IDE/compilador indisponível neste ambiente |
| Temporização, reinício e comunicação no alvo | Pendente | Dependem do projeto integrador e de mailboxes/relógio reais |

Comandos executados:

```bash
python3 tools/check_sources.py --source-dir src --source-dir tests
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 tools/build_bundle.py --source-dir src --source-dir tests
```

O checker verifica tipos conhecidos, membros de enums, valores numéricos duplicados,
nomes de objetos, delimitadores estruturais, dependências/ciclos e ausência de
endereçamento físico. Ele não valida todas as expressões, conversões numéricas,
assinaturas de chamadas ou regras do compilador de destino.

## Casos cobertos pelos testes ST preparados

Os testes de suporte usam diretamente os FBs: timer qualificado, saturação, limites
da receita, duplicatas, fila cheia, ACK repetido e idempotência do gate de comandos.

Os testes de integração usam um Control em memória: ausência de autorização,
concessão incompleta, carga/start, feedback não correlacionado, tempo qualificado,
Complete/Release distintos, reset, revogação durante lote, reautorização sem retomada,
supressão de publicação, nova geração de autoridade e encerramento da falha.

Os testes adicionais cobrem Hold/Resume sem contar feedback da intenção Hold,
confirmação com Ready falso/prompt incorreto, receita aplicada imutável, término
após Running longo, Stop/Abort/Release, timeout de Holding, Reset com lote no evento
e rejeição de feedback de encerramento composto de duas gerações de autoridade.

São cenários executáveis em ST, não resultados medidos de execução. Os 56 scans
de lifecycle tiveram também revisão manual independente das expectativas.

## Ajustes incorporados na revisão

- Comandos de lifecycle conferem o BatchID corrente para evitar aplicar um pedido de
  lote antigo ao lote atual.
- LoadRecipe fica restrito a Idle, preservando a relação entre lote encerrado e receita.
- A fila admite múltiplas inserções serializadas no mesmo scan; o ACK é avaliado uma vez.
- Eventos carregam sua própria identidade de receita, concessão e pedido, sem depender
  de associar posteriormente um evento antigo ao runtime atual.
- Uma transição natural para Completing reinicia o relógio antes de conferir o prazo;
  o tempo anterior em Running não provoca timeout falso no encerramento.
- Result e runtime precisam pertencer à mesma AuthorityID da intenção, inclusive
  durante Abort/Release de um lote em Faulted.
- Tempo qualificado e confirmação de operador exigem feedback do Execute corrente,
  Ready e token de recurso correspondente. Feedback de Hold/Acquire não é execução.
- Os eventos de Reset conservam o BatchID encerrado, embora o runtime volte a lote zero.

A matriz requisito/código/cenário está em [LIFECYCLE.md](LIFECYCLE.md). O layout dos
DUTs e os valores numéricos públicos da versão 0.1 foram preservados nesta revisão.

Não há alegação de conformidade ISA/IEC, certificação de segurança funcional ou
adequação a uma máquina específica. As escolhas de ciclo e contrato são deste projeto.
