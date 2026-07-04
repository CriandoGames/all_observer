import 'package:flutter/foundation.dart';

/// A function that removes a previously registered listener.
///
/// Uma função que remove um listener previamente registrado.
typedef Disposer = void Function();

/// Callback invoked with the new value of an observable.
///
/// Callback invocado com o novo valor de um observável.
typedef ObserverCallback<T> = void Function(T value);

/// Signature reused across the package for "no arguments, no return"
/// notifications. Alias kept for readability at call sites.
///
/// Assinatura reutilizada no pacote para notificações "sem argumentos,
/// sem retorno". Alias mantido para legibilidade nos pontos de uso.
typedef ObserverVoidCallback = VoidCallback;
