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
  final TextEditingController _manualController = TextEditingController();
  bool _isProcessing = false;

  void _openManualInput() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product manueel toevoegen'),
        content: TextField(
          controller: _manualController,
          decoration: const InputDecoration(
            labelText: 'Barcode of productcode',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _manualController.clear();
              Navigator.pop(context);
            },
            child: const Text('Annuleer'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _manualController.text.trim();
              if (code.isEmpty) return;

              Navigator.pop(context);
              _manualController.clear();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductScreen(barcode: code),
                ),
              );
            },
            child: const Text('Toevoegen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_isProcessing) return;

          final barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;

          final code = barcodes.first.rawValue;
          if (code == null) return;

          _isProcessing = true;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductScreen(barcode: code),
            ),
          ).then((_) {
            _isProcessing = false;
          });
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openManualInput,
        icon: const Icon(Icons.edit),
        label: const Text('Manueel toevoegen'),
      ),
    );
  }
}
