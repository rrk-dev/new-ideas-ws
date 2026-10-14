import 'dart:async';

import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/recording/domain/recording_indicator.dart';

/// Records what the OS indicator would show; [tap] simulates a button tap.
class FakeRecordingIndicator implements RecordingIndicator {
  final shown = <IndicatorContent>[];
  final reminders = <Duration>[];
  int hides = 0;
  bool visible = false;
  final _actions = StreamController<IndicatorAction>.broadcast();

  IndicatorContent? get current => visible ? shown.last : null;

  void tap(IndicatorAction action) => _actions.add(action);

  @override
  Future<Result<void>> show(IndicatorContent content) async {
    shown.add(content);
    visible = true;
    return const Ok<void>(null);
  }

  @override
  Future<void> hide() async {
    hides++;
    visible = false;
  }

  @override
  void stillRecording(Duration elapsed) => reminders.add(elapsed);

  @override
  Stream<IndicatorAction> get actions => _actions.stream;
}
