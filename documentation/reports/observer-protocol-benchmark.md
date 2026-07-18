# Benchmark do Observer Protocol v1

English version: [observer-protocol-benchmark.en.md](observer-protocol-benchmark.en.md)

## Ambiente e método

- Data: 18 de julho de 2026.
- Dart 3.12.2 e Flutter 3.44.6 stable, Windows x64.
- CPU AMD Ryzen 7 5700X, 8 cores/16 threads.
- Harness: `Stopwatch`, aquecimento antes do trecho medido nos cenários de
  update e execução em processo local.
- Comando: `dart run benchmark/observer_protocol_benchmark.dart`.

Os números são uma amostra local, não um limite contratual. O harness mede
tempo decorrido; ele não fornece contagem confiável de alocações. O buffer foi
validado separadamente por testes contratuais nos limites 0, 1, 10 e 1000.

## Resultados

| Cenário | Iterações | µs/op | vs update desativado |
| --- | ---: | ---: | ---: |
| Protocolo desativado | 200000 | 0.0357 | 1.00x |
| Ativado, sem consumer | 200000 | 0.4384 | 12.29x |
| Um consumer vazio | 200000 | 1.1264 | 31.58x |
| Cinco consumers vazios | 200000 | 3.6986 | 103.70x |
| Registry, buffer zero | 200000 | 0.4117 | 11.54x |
| Registry + buffer 1000 | 200000 | 0.5097 | 14.29x |
| Captura segura de valor | 200000 | 0.4654 | 13.05x |
| Captura de stack | 20000 | 1.2175 | 34.14x |
| Geração de ID | 1000000 | 0.0024 | 0.07x |
| Snapshot de 1000 nós | 1000 | 64.0150 | 1794.90x |
| Cadeia de três computeds | 100000 | 7.1015 | 199.12x |
| Conjunto de 100 dependências | 10000 | 74.4131 | 2086.45x |
| Troca de dependência condicional | 100000 | 3.8317 | 107.44x |
| Dispose de scope com 1000 recursos | 200 | 178.1650 | 4995.51x |

As razões da última coluna usam o update desativado apenas como referência;
não comparam operações equivalentes para snapshots, IDs, dependências ou
scopes. Para updates equivalentes, ativar o protocolo sem consumer acrescentou
aproximadamente 0.4027 µs/op nesta execução. A captura de stack foi o recurso
por-update mais caro medido e continua desativada por padrão.

## Cobertura

O benchmark cobre protocolo desativado/ativado, zero/um/cinco consumers,
registry, buffer, captura de valores e stack, alta frequência, geração de IDs,
snapshot, computed encadeado, muitas dependências, dependência condicional e
scope com muitos recursos. Crescimento e descarte do ring buffer são
assertados na suíte, pois tempo isolado não prova limite de memória.

