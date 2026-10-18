import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_query.dart';

void main() {
  // A Monday.
  final now = DateTime(2026, 3, 30, 10);

  AskQuery parse(String q) => AskQuery.parse(AskRequest(question: q), now);

  test('stems drop stop and date words and strip suffixes', () {
    expect(parse('What is the serial number?').stems, ['serial', 'number']);
    expect(parse('my warranties').stems, ['warranty']);
    expect(parse('When is the beta shipping?').ftsMatch, '"beta"* OR "shipp"*');
  });

  test('date ranges', () {
    DateTime d(int m, int day) => DateTime(2026, m, day);
    expect(parse('call yesterday').range, AskDateRange(d(3, 29), d(3, 29)));
    expect(parse('last week').range, AskDateRange(d(3, 23), d(3, 29)));
    expect(parse('this week').range, AskDateRange(d(3, 30), d(3, 30)));
    expect(parse('on Friday').range, AskDateRange(d(3, 27), d(3, 27)));
    expect(parse('in February').range, AskDateRange(d(2, 1), d(2, 28)));
    expect(
      parse('in November').range,
      AskDateRange(DateTime(2025, 11), DateTime(2025, 11, 30)),
    );
    expect(parse('plain question').range, isNull);
  });

  test('date-only questions and explicit filters', () {
    expect(parse('What did I record yesterday?').dateOnly, isTrue);
    final q = parse('budget profile:meeting #q3');
    expect(q.profileId, 'meeting');
    expect(q.tags, ['q3']);
    expect(q.stems, ['budget']);
  });
}
