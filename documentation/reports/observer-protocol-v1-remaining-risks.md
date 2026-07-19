# Validação dos riscos restantes — Observer Protocol v1

Data: 2026-07-18  
Branch: `protocol-v1`  
HEAD inicial: `ab7af70803275f8d4274cb401a33e3ca0a6b78ed`

## Recomendação

**READY WITH RESTRICTIONS.** O protocolo preserva a atualização reativa mesmo
quando diagnostics falham, não retém valores crus ou objetos da aplicação e
agora informa quando um snapshot não é reconciliável. Ainda não deve ser
apresentado como grafo completo: collections não possuem identidade v1 e uma
sessão iniciada depois da criação de objetos tem baseline incompleto.

## Baseline

Ambiente: Flutter 3.44.6 stable, Dart 3.12.2, Windows x64.

| Comando | Resultado | Testes | Duração externa |
| --- | --- | ---: | ---: |
| `flutter pub get` | passou; 6 updates incompatíveis com as constraints | — | 1,82 s |
| `flutter analyze` | sem issues | — | 4,65 s |
| `flutter test` | passou | 426 | 14,79 s |
| `flutter test test/audit/` | passou | 22 | 4,43 s |
| `flutter test test/regressions/` | passou | 54 | 7,50 s |
| `flutter test test/devtools/` | passou | 21 | 3,97 s |
| `flutter test benchmark/performance_guard_test.dart` | passou | 2 | 6,89 s |
| `flutter pub publish --dry-run` | passou, 0 warnings | — | 4,47 s |

## Hipóteses e classificação

| Hipótese | Resultado | Gravidade | Evidência/decisão |
| --- | --- | --- | --- |
| Ativação tardia emite referências ausentes | confirmada | alta | Observable, Computed, effect, worker e scope mantiveram IDs ausentes do snapshot |
| `startNewSession()` com objetos vivos perde o baseline | confirmada | alta | updates, deltas e disposes posteriores não eram reconciliáveis |
| `configure()` durante a vida dos objetos perde o baseline | confirmada | alta | o registry era limpo sem aviso ao consumer |
| Falha de inspector interrompe aplicação ou peers | refutada | crítica se existisse | isolamento e ordem já estavam corretos |
| Falhas de inspector são observáveis com segurança | confirmada como lacuna | média | não havia contador, categoria ou código sanitizado |
| Reporter de erro pode reentrar no protocolo | confirmada | alta | reprodução mostrou duas chamadas; guard reduziu para uma |
| Resumos retêm objetos/valores crus | refutada | crítica se existisse | registry mantém apenas metadados e summaries |
| Heurística cobre credenciais e dados pessoais sintéticos | confirmada como lacuna | alta | JWT sem Bearer, API key, e-mail, CPF e token puro escapavam |
| Truncamento de Unicode é seguro | confirmada como lacuna | média | `substring` dividia surrogate pair |
| `redactValue` que lança quebra update | refutada | alta se existisse | já falhava fechado; ganhou cobertura explícita |
| Labels são seguras para produção | confirmada como lacuna | alta | label era armazenada integralmente; preset opt-in agora redige |
| Collections têm identidade e grafo v1 completo | refutada | média | continuam reativas pelo fluxo legado, sem nó/aresta v1 |
| Overhead sofre regressão catastrófica | refutada | média | guards relativos passaram; matriz reproduzível registrada |
| Alocações podem ser medidas pelo harness atual | inconclusiva | baixa | Stopwatch não mede heap com confiabilidade |
| CI cobre `protocol-v1` e suítes explícitas | confirmada como lacuna | média | workflow cobria apenas `main` e suíte agregada |

## Correções mínimas

- Estratégia de sessão escolhida: contrato explícito de baseline. O snapshot
  expõe `baselineStatus` e `isBaselineComplete`; não há re-registro silencioso
  nem retenção forte de objetos quando o protocolo está desativado.
- `instrumentationCoverage: partial` e a limitação `reactiveCollections`
  impedem consumers de apresentarem o grafo v1 como completo.
- Falhas isoladas expõem total, mapa por categoria e último código fixo. Nenhuma
  mensagem de exceção é armazenada; a contabilização não emite eventos.
- A heurística sintética cobre JWT, chaves prefixadas, e-mail, CPF e tokens
  compactos longos. Truncamento passou a respeitar escalares Unicode.
- `ObserverProtocolConfig.productionSafe()` desativa valores/stacks e redige
  labels. O construtor normal preserva o comportamento anterior.
- CI passa a cobrir pushes/PRs de `protocol-v1`, DevTools e regressões
  explicitamente, mantendo analyze, suíte completa, guards, web release e
  publish dry-run.

## Antes/depois

| Indicador | Antes | Depois |
| --- | ---: | ---: |
| Suíte completa | 426 testes | 442 testes |
| DevTools/protocolo | 21 testes | 37 testes |
| Guards de performance | 2 testes | 3 testes |
| Baseline perdido | silencioso | status explícito no snapshot |
| Falha interna | somente reporter do host | total + categoria + código sanitizado |
| Coverage de collections | somente documentação | campo estruturado `partial` |
| Unicode truncado | unidade UTF-16 | escalar Unicode |

## Resultado final

| Comando | Resultado | Testes | Duração externa |
| --- | --- | ---: | ---: |
| `flutter analyze` | sem issues | — | 4,13 s |
| `flutter test` | passou | 442 | 14,59 s |
| `flutter test test/audit/` | passou | 22 | 4,10 s |
| `flutter test test/regressions/` | passou | 54 | 6,95 s |
| `flutter test test/devtools/` | passou | 37 | 4,75 s |
| `flutter test benchmark/performance_guard_test.dart` | passou | 3 | 12,28 s |
| `flutter build web --release` no exemplo | passou | — | 25,75 s |
| `flutter pub publish --dry-run` | pacote validado; warning de worktree suja | — | 3,85 s |
| `flutter pub publish --dry-run --ignore-warnings` | passou | — | 3,92 s |

O build web avisou que a fonte de `cupertino_icons` não foi encontrada e
sugeriu testar `--wasm`; o artefato web foi gerado. O warning do publish é
esperado enquanto os arquivos desta validação ainda não estão commitados. O
baseline limpo teve zero warnings.

## Performance

Na amostra local: desativado 0,0348 µs/update; ativado sem consumer 0,4097;
um consumer vazio 1,1139; buffer 100.000 0,5405; captura de valores 0,4376;
captura de stack 1,2729; churn create/dispose 1,7702 µs/op. O guard usa mediana
e limite relativo amplo de 50x para protocolo ativado, evitando sensibilidade
excessiva à máquina. Resultados completos estão em `benchmark/RESULTS.md`.

## Riscos residuais

1. Collections não possuem identidade de operação ou arestas v1.
2. Baselines tardios são detectados conservadoramente; o consumer deve rejeitar
   reconciliação completa quando `isBaselineComplete` for falso.
3. Heurísticas de segredo reduzem exposição acidental, mas não substituem um
   redator específico da aplicação. Para produção, usar `productionSafe`.
4. Stack traces são opt-in e podem conter dados do código/aplicação.
5. Alocações de heap não foram quantificadas.
6. O custo cresce linearmente com consumers e tamanho do grafo; o buffer de
   100.000 eventos aumenta tempo e memória retida.

## Arquivos modificados

- `.github/workflows/ci.yml`
- `benchmark/RESULTS.md`
- `benchmark/observer_protocol_benchmark.dart`
- `benchmark/performance_guard_test.dart`
- `documentation/en/observer_protocol.md`
- `documentation/pt-BR/observer_protocol.md`
- `documentation/reports/observer-protocol-v1-remaining-risks.md`
- `lib/src/protocol/internal/node_protocol_runtime.dart`
- `lib/src/protocol/internal/protocol_registry.dart`
- `lib/src/protocol/internal/protocol_runtime_state.dart`
- `lib/src/protocol/internal/scope_protocol_runtime.dart`
- `lib/src/protocol/internal/value_summary_policy.dart`
- `lib/src/protocol/observer_protocol_config.dart`
- `lib/src/protocol/snapshot/observer_protocol_snapshot.dart`
- `test/devtools/collection_protocol_contract_test.dart`
- `test/devtools/protocol_internal_error_contract_test.dart`
- `test/devtools/session_baseline_contract_test.dart`
- `test/devtools/value_safety_contract_test.dart`
