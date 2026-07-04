import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

/// Demo 4: a small form with several fields, saved via `Observable.batch`,
/// with a visible notification counter proving manual listeners fire
/// "exactly once" per save regardless of how many fields changed.
///
/// Demo 4: um pequeno formulário com vários campos, salvo via
/// `Observable.batch`, com um contador de notificações visível provando
/// que listeners manuais disparam "exatamente uma vez" por salvamento,
/// independente de quantos campos mudaram.
class BatchDemo extends StatefulWidget {
  /// Creates the batch demo.
  ///
  /// Cria o demo de batch.
  const BatchDemo({super.key});

  @override
  State<BatchDemo> createState() => _BatchDemoState();
}

class _BatchDemoState extends State<BatchDemo> {
  final ObservableString _firstName = 'Carlos'.obs;
  final ObservableString _lastName = 'Castro'.obs;
  final ObservableInt _age = 30.obs;
  final ObservableInt _notificationCount = 0.obs;
  late final Worker _everWorker;

  final TextEditingController _firstNameController = TextEditingController(
    text: 'Carlos',
  );
  final TextEditingController _lastNameController = TextEditingController(
    text: 'Castro',
  );

  @override
  void initState() {
    super.initState();
    // A single manual listener watching all three fields; `ever` here just
    // demonstrates the notification count, not a real persistence layer.
    _everWorker = ever(_firstName, (_) => _notificationCount.value++);
    ever(_lastName, (_) => _notificationCount.value++);
    ever(_age, (_) => _notificationCount.value++);
  }

  void _saveWithBatch() {
    Observable.batch(() {
      _firstName.setValue(_firstNameController.text);
      _lastName.setValue(_lastNameController.text);
      _age.value++;
    });
  }

  void _saveWithoutBatch() {
    _firstName.setValue('${_firstNameController.text} ');
    _lastName.setValue('${_lastNameController.text} ');
    _age.value++;
  }

  @override
  void dispose() {
    _everWorker.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _firstName.close();
    _lastName.close();
    _age.close();
    _notificationCount.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'First name'),
          ),
          TextField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Last name'),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              ElevatedButton(
                onPressed: _saveWithBatch,
                child: const Text('Save (batch: fires once)'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _saveWithoutBatch,
                child: const Text('Save (no batch: fires per field)'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Observer(
            () => Text(
              'Total notifications received: ${_notificationCount.value}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Observer(
            () => Text(
              'Current: ${_firstName.value} ${_lastName.value}, '
              'age ${_age.value}',
            ),
          ),
        ],
      ),
    );
  }
}
