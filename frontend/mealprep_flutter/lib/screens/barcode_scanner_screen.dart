import 'package:flutter/material.dart';
import 'package:mealprep_flutter/screens/product_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mealprep_flutter/services/food_api_service.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false; // voorkomt dubbele detecties

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: MobileScanner(
        onDetect: (capture) {
          final barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;

          final code = barcodes.first.rawValue;
          if (code == null) return;

          print('Gescande barcode: $code');

          // Open nieuw scherm en haal product op daar
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductScreen(barcode: code),
            ),
          );
        }

      )
    );
  }
}
