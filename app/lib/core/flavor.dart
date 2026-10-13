/// Build flavor selected by the entrypoint (`main_dev.dart`/`main_prod.dart`).
enum Flavor {
  dev,
  prod;

  /// Whether this is the development flavor.
  bool get isDev => this == Flavor.dev;
}
