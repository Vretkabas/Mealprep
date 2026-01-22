import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan barcode")),
      body: MobileScanner(
        onDetect: (barcode) {
          final code = barcode.barcodes.first.rawValue;
          if (code == null) return;

          debugPrint("EAN: $code");

          // 👉 GA NAAR CAMERA SCREEN
          Navigator.pushNamed(
            context,
            '/camera',
            arguments: code,
          );
        },
      ),
    );
  }
}
