import 'package:flutter/material.dart';

/// Root widget of the mobile app.
///
/// Stage 1 only renders the splash wordmark. Routing, theming and dependency
/// wiring are added here as each domain package lands.
class BancaDigitalApp extends StatelessWidget {
  const BancaDigitalApp({super.key});

  static const String productName = 'Banca Digital';

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: productName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(productName),
        ),
      ),
    );
  }
}
