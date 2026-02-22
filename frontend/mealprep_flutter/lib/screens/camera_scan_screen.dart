import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../services/scan_device.dart';

class CameraScanScreen extends ConsumerWidget {
  const CameraScanScreen({super.key});

  Future<void> _takePhoto(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    final scanService = ref.read(scanServiceProvider);


    try {
      final result = await scanService.scanImage(image.path); 

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Resultaat: $result")),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fout: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Object Scan')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _takePhoto(context, ref),
          child: const Text('Neem foto'),
        ),
      ),
    );
  }
}
