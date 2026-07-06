import 'dart:io';

class KatsKlubHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    return client;
  }
}

void configureHttpOverrides() {
  HttpOverrides.global = KatsKlubHttpOverrides();
}
