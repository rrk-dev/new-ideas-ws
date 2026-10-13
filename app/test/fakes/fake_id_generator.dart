import 'package:vaultvoice/core/platform/id_generator.dart';

/// Deterministic [IdGenerator]: `id-0001`, `id-0002`, …
class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator({this.prefix = 'id', int start = 1}) : _next = start;

  final String prefix;
  int _next;

  /// IDs handed out so far, in order.
  final List<String> issued = [];

  @override
  String next() {
    final id = '$prefix-${(_next++).toString().padLeft(4, '0')}';
    issued.add(id);
    return id;
  }
}
