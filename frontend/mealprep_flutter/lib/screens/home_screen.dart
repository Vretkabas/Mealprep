import 'package:flutter/material.dart';
import 'barcode_scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
/* Homescreen met daarop een button die je naar de barcodescanner brengt */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mealprep')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Scan barcode'),
          onPressed: () async {
            final barcode = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BarcodeScannerScreen(),
              ),
            );

            if (barcode != null) {
              print("Gescand: $barcode");
            }
          },
        ),
      ),
    );
  }
}
