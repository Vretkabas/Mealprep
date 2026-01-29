import 'package:flutter/material.dart';

import 'barcode_scanner_screen.dart';
import 'object_scan_screen.dart';
import '../services/food_api_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /* Homescreen met barcode scan + fallback naar object herkenning */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mealprep')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Scan barcode'),
          onPressed: () async {
            //  Barcode scannen
            final barcode = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BarcodeScannerScreen(),
              ),
            );

            if (barcode == null) return;

            //  Probeer product via barcode
            try {
              final product =
                  await FoodApiService.fetchByBarcode(barcode);

              //  Barcode succesvol
              debugPrint('Product gevonden via barcode: $product');
            } catch (e) {
              // Barcode niet gevonden → fallback object scan
              debugPrint('Barcode niet herkend, start object scan');

              final detections = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ObjectScanScreen(),
                ),
              );

              if (detections != null && detections.isNotEmpty) {
                final label = detections.first['label'];
                debugPrint('Product herkend via object: $label');
              } else {
                debugPrint('Geen objecten herkend');
              }
            }
          },
        ),
      ),
    );
  }
}
