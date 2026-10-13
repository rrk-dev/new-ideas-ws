// failWith mirrors the vv-testing fake contract; a setter reads poorly.
// ignore_for_file: use_setters_to_change_properties

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/profiles/domain/profile_grammar.dart';

/// Deterministic [SchemaGrammarConverter]: returns a fake grammar tagged with
/// the schema length. `failWith` makes every conversion fail (the native
/// converter rejected the schema).
class FakeSchemaGrammarConverter implements SchemaGrammarConverter {
  final List<String> requests = [];
  Failure? _failure;

  void failWith(Failure failure) => _failure = failure;

  @override
  Future<Result<String>> toGbnf(String schemaJson) async {
    requests.add(schemaJson);
    if (_failure case final failure?) return Err(failure);
    return Ok('root ::= object # fake ${schemaJson.length}');
  }
}
