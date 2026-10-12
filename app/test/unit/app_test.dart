import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/flavor.dart';

void main() {
  testWidgets('app shows the product name and flavor', (tester) async {
    await tester.pumpWidget(const App(flavor: Flavor.dev));
    expect(find.text(kAppName), findsOneWidget);
    expect(find.text('dev flavor'), findsOneWidget);
  });
}
