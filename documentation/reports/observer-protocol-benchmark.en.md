# Observer Protocol v1 benchmark

Portuguese version: [observer-protocol-benchmark.md](observer-protocol-benchmark.md)

## Environment and method

- Date: July 18, 2026.
- Dart 3.12.2 and Flutter 3.44.6 stable, Windows x64.
- AMD Ryzen 7 5700X CPU, 8 cores/16 threads.
- Harness: `Stopwatch`, warm-up before timed update sections, local process.
- Command: `dart run benchmark/observer_protocol_benchmark.dart`.

These figures are one local sample, not a contractual threshold. The harness
measures elapsed time and cannot provide a reliable allocation count. Buffer
bounds are verified separately by contract tests for sizes 0, 1, 10, and 1000.

## Results

| Scenario | Iterations | µs/op | vs disabled update |
| --- | ---: | ---: | ---: |
| Protocol disabled | 200000 | 0.0357 | 1.00x |
| Enabled, no consumer | 200000 | 0.4384 | 12.29x |
| One empty consumer | 200000 | 1.1264 | 31.58x |
| Five empty consumers | 200000 | 3.6986 | 103.70x |
| Registry, zero buffer | 200000 | 0.4117 | 11.54x |
| Registry + buffer 1000 | 200000 | 0.5097 | 14.29x |
| Safe value capture | 200000 | 0.4654 | 13.05x |
| Stack capture | 20000 | 1.2175 | 34.14x |
| ID generation | 1000000 | 0.0024 | 0.07x |
| Snapshot of 1000 nodes | 1000 | 64.0150 | 1794.90x |
| Three-computed chain | 100000 | 7.1015 | 199.12x |
| Set of 100 dependencies | 10000 | 74.4131 | 2086.45x |
| Conditional dependency switch | 100000 | 3.8317 | 107.44x |
| Scope disposal with 1000 resources | 200 | 178.1650 | 4995.51x |

The last-column ratios use a disabled update only as a reference; snapshots,
IDs, dependency sets, and scopes are not equivalent operations. Among matching
update scenarios, enabling the protocol without a consumer added about
0.4027 µs/op in this run. Stack capture was the most expensive per-update
feature measured and remains disabled by default.

## Coverage

The benchmark covers disabled/enabled operation, zero/one/five consumers,
registry, buffer, value and stack capture, high-frequency updates, ID creation,
snapshot, chained computed values, many dependencies, conditional dependencies,
and scopes with many resources. Ring-buffer growth and eviction are asserted by
the test suite because timing alone does not prove a memory bound.

