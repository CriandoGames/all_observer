import 'observable.dart';
import 'observable_subscription.dart';

/// Bounded undo/redo history for an [Observable]: records every value
/// change as it happens (skipping changes made by [undo]/[redo] themselves,
/// so redoing after an undo restores the exact value that was undone,
/// instead of recording a brand-new history entry), and lets you step
/// backward ([undo]) and forward ([redo]) through them.
///
/// Bounded by [limit]: once more than [limit] values have been recorded,
/// the oldest ones are dropped — undo can never go back further than
/// [limit] steps, keeping memory use flat for long-lived observables (a
/// text field, a canvas position, ...).
///
/// Independent of the [Observable] it wraps: closing an [ObservableHistory]
/// (via [dispose]) does not close the underlying [Observable], and the
/// [Observable] keeps working as a normal, unhistoried value afterward —
/// symmetric with `ObservableStoreBinding.persistWith`.
///
/// Histórico limitado de desfazer/refazer para um [Observable]: registra
/// toda mudança de valor conforme ela acontece (ignorando mudanças feitas
/// pelo próprio [undo]/[redo], para que refazer depois de desfazer restaure
/// exatamente o valor que foi desfeito, em vez de registrar uma entrada de
/// histórico totalmente nova), e permite navegar para trás ([undo]) e para
/// frente ([redo]) por elas.
///
/// Limitado por [limit]: assim que mais de [limit] valores tiverem sido
/// registrados, os mais antigos são descartados — desfazer nunca pode
/// voltar mais do que [limit] passos, mantendo o uso de memória estável
/// para observáveis de vida longa (um campo de texto, uma posição de
/// canvas, ...).
///
/// Independente do [Observable] que envolve: descartar um
/// [ObservableHistory] (via [dispose]) não fecha o [Observable] subjacente,
/// e o [Observable] continua funcionando como um valor normal, sem
/// histórico, depois disso — simétrico a `ObservableStoreBinding.persistWith`.
///
/// Example / Exemplo:
/// ```dart
/// final text = Observable<String>('');
/// final history = text.withHistory(limit: 50);
/// text.value = 'hello';
/// text.value = 'hello world';
/// history.undo(); // text.value == 'hello'
/// history.undo(); // text.value == ''
/// history.redo(); // text.value == 'hello'
/// history.dispose();
/// ```
class ObservableHistory<T> {
  /// Creates an [ObservableHistory] tracking [observable] from its current
  /// value onward, keeping at most [limit] recorded values (the current one
  /// included). [limit] must be at least `1`.
  ///
  /// Cria um [ObservableHistory] rastreando [observable] a partir de seu
  /// valor atual em diante, mantendo no máximo [limit] valores registrados
  /// (incluindo o atual). [limit] deve ser no mínimo `1`.
  ObservableHistory(this.observable, {this.limit = 100})
    : assert(limit > 0, 'limit must be at least 1') {
    _stack.add(observable.value);
    _subscription = observable.listen(_onExternalChange);
  }

  /// The [Observable] this history tracks.
  ///
  /// O [Observable] que este histórico rastreia.
  final Observable<T> observable;

  /// Maximum number of recorded values, current one included.
  ///
  /// Número máximo de valores registrados, incluindo o atual.
  final int limit;

  final List<T> _stack = <T>[];
  int _index = 0;
  bool _applyingHistoryChange = false;
  late final ObservableSubscription _subscription;

  void _onExternalChange(T value) {
    if (_applyingHistoryChange) {
      return;
    }
    if (_index < _stack.length - 1) {
      _stack.removeRange(_index + 1, _stack.length);
    }
    _stack.add(value);
    _index = _stack.length - 1;
    while (_stack.length > limit) {
      _stack.removeAt(0);
      _index--;
    }
  }

  /// Whether [undo] would have any effect right now.
  ///
  /// Se [undo] teria algum efeito agora.
  bool get canUndo => _index > 0;

  /// Whether [redo] would have any effect right now.
  ///
  /// Se [redo] teria algum efeito agora.
  bool get canRedo => _index < _stack.length - 1;

  /// Steps [observable] back to its previous recorded value. A no-op if
  /// [canUndo] is `false`.
  ///
  /// Volta [observable] para seu valor anterior registrado. Não faz nada se
  /// [canUndo] for `false`.
  void undo() {
    if (!canUndo) {
      return;
    }
    _index--;
    _applyingHistoryChange = true;
    try {
      observable.value = _stack[_index];
    } finally {
      _applyingHistoryChange = false;
    }
  }

  /// Steps [observable] forward to the value it had before the last [undo].
  /// A no-op if [canRedo] is `false`.
  ///
  /// Avança [observable] para o valor que tinha antes do último [undo]. Não
  /// faz nada se [canRedo] for `false`.
  void redo() {
    if (!canRedo) {
      return;
    }
    _index++;
    _applyingHistoryChange = true;
    try {
      observable.value = _stack[_index];
    } finally {
      _applyingHistoryChange = false;
    }
  }

  /// Clears all recorded history, keeping only [observable]'s current
  /// value as the sole entry — [canUndo] and [canRedo] are both `false`
  /// immediately after.
  ///
  /// Limpa todo o histórico registrado, mantendo apenas o valor atual de
  /// [observable] como única entrada — [canUndo] e [canRedo] ficam ambos
  /// `false` imediatamente depois.
  void clear() {
    _stack
      ..clear()
      ..add(observable.value);
    _index = 0;
  }

  /// Stops tracking [observable]. Does not close [observable] itself — it
  /// keeps working as a normal, unhistoried value afterward. Safe to call
  /// more than once.
  ///
  /// Para de rastrear [observable]. Não fecha o [observable] em si — ele
  /// continua funcionando como um valor normal, sem histórico, depois
  /// disso. Seguro chamar mais de uma vez.
  void dispose() {
    _subscription.cancel();
  }
}

/// Sugar for attaching an [ObservableHistory] to an [Observable] — see that
/// class's doc for the full undo/redo contract.
///
/// Açúcar sintático para anexar um [ObservableHistory] a um [Observable] —
/// ver o doc daquela classe para o contrato completo de desfazer/refazer.
extension ObservableHistoryExtension<T> on Observable<T> {
  /// Returns a new [ObservableHistory] tracking this [Observable], keeping
  /// at most [limit] recorded values. The caller owns the result and is
  /// responsible for calling [ObservableHistory.dispose] on it when done —
  /// mirrors `select`'s ownership contract.
  ///
  /// Retorna um novo [ObservableHistory] rastreando este [Observable],
  /// mantendo no máximo [limit] valores registrados. Quem chama é dono do
  /// resultado e é responsável por chamar [ObservableHistory.dispose] nele
  /// quando terminar — espelha o contrato de posse de `select`.
  ObservableHistory<T> withHistory({int limit = 100}) =>
      ObservableHistory<T>(this, limit: limit);
}
