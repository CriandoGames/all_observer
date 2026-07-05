/// A function that removes a previously registered listener.
///
/// Uma função que remove um listener previamente registrado.
typedef Disposer = void Function();

/// Callback invoked with the new value of an observable.
///
/// Callback invocado com o novo valor de um observável.
typedef ObserverCallback<T> = void Function(T value);

/// Signature reused across the package for "no arguments, no return"
/// notifications. Alias kept for readability at call sites. Structurally
/// identical to Flutter's `VoidCallback` (`void Function()`), so any
/// `Observable`/`Computed` still satisfies `ValueListenable`'s
/// `addListener`/`removeListener` contract without this file needing to
/// import Flutter.
///
/// Assinatura reutilizada no pacote para notificações "sem argumentos,
/// sem retorno". Alias mantido para legibilidade nos pontos de uso.
/// Estruturalmente idêntico ao `VoidCallback` do Flutter (`void
/// Function()`), então qualquer `Observable`/`Computed` continua
/// satisfazendo o contrato `addListener`/`removeListener` de
/// `ValueListenable` sem que este arquivo precise importar Flutter.
typedef ObserverVoidCallback = void Function();
