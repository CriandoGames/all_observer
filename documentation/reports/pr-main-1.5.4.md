# Relatório de testes e release — all_observer 1.5.4

## Objetivo

Preparar a versão `1.5.4` como patch release focado em segurança do
scheduler de `effect()` e endurecimento da suíte de regressão do motor
reativo.

## O que foi feito

1. A versão do pacote foi atualizada para `1.5.4`.
2. README em inglês e português foram atualizados para instalar
   `all_observer: ^1.5.4`.
3. `CHANGELOG.md` recebeu a entrada da versão `1.5.4`.
4. A documentação de arquitetura, motor, conceitos, avançado, FAQ e testes
   foi atualizada para explicar:
   - writes intencionais dentro de `effect()`;
   - supressão de autoinvalidação no mesmo flush;
   - descarte seguro de effects durante execução;
   - regressões de mutação de grafo e Dart2JS.
5. O estudo do motor v2 foi atualizado para marcar os testes de mutação de
   grafo como cobertos na `1.5.4`.

## Recursos impactados

- `effect()` e integração com `DependencyTracker`;
- `BatchScope` e flush em ondas;
- `ReactiveScope` ao descartar effects durante callback;
- `CoreComputed` e ponte com `ReactiveEngine`;
- documentação pública EN/PT-BR.

## Sugestão de testes

Antes de publicar, rode:

```bash
flutter analyze
flutter test test/effects
flutter test test/core
flutter test test/regressions
flutter test
flutter pub publish --dry-run
```

## Riscos de regressão

- Effects que escrevem em observáveis lidos no mesmo callback;
- descarte de effect ou `ReactiveScope` durante uma execução ativa;
- mutação de grafo durante dirty checking;
- exceção durante flush de batch;
- compilação Dart2JS dos entrypoints `core.dart` e `engine.dart`.

## Compatibilidade

Sem breaking changes e sem novas dependências.
