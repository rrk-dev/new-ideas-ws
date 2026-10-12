import 'package:flutter/material.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/flavor.dart';

/// Root widget. Placeholder until FND-02 adds routing and theming.
class App extends StatelessWidget {
  /// Creates the root widget for [flavor].
  const new({required this.flavor, super.key});

  /// Active build flavor.
  final Flavor flavor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: flavor.isDev,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text(kAppName)),
        body: Center(child: Text('${flavor.name} flavor')),
      ),
    );
  }
}
