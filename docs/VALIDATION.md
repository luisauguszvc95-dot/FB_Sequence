# Registro de validação — base 0.1

Data: 2026-09-10. Esta página separa evidência executada de cenários preparados.

| Verificação | Resultado | Limite da evidência |
|---|---|---|
| Checker estático sobre `src/` e fontes ST de `tests/` | 30 objetos, zero achados | Verifica o subconjunto documentado; não é compilador ST |
| Testes Python do checker | 13 testes aprovados | Exercitam o verificador, não o motor de sequência |
| Bundle e ordem de dependências | Gerados com 30 objetos | Arquivo textual; não comprova importação nativa |
| Revisão independente de contratos e lifecycle | Incorporada | Revisão manual, sem execução do runtime |
| `PRG_SEQ_SupportTests` | 40 grupos de verificações preparados | Ainda não executados no Machine Expert |
| `PRG_SEQ_IntegrationTests` | 28 verificações multiscans preparadas | Ainda não executadas no Machine Expert |
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

São cenários executáveis em ST, não resultados medidos de execução. A demonstração
manual também permite observar Hold/Resume e confirmação do operador; esses percursos
ainda precisam de ensaios adicionais no simulador antes de integrar um processo real.

## Ajustes incorporados na revisão

- Comandos de lifecycle conferem o BatchID corrente para evitar aplicar um pedido de
  lote antigo ao lote atual.
- LoadRecipe fica restrito a Idle, preservando a relação entre lote encerrado e receita.
- A fila admite múltiplas inserções serializadas no mesmo scan; o ACK é avaliado uma vez.
- Eventos carregam sua própria identidade de receita, concessão e pedido, sem depender
  de associar posteriormente um evento antigo ao runtime atual.

Não há alegação de conformidade ISA/IEC, certificação de segurança funcional ou
adequação a uma máquina específica. As escolhas de ciclo e contrato são deste projeto.
