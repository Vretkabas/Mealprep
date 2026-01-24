import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dio/dio.dart';
import '../services/object_scan_service.dart';

class ObjectScanScreen extends StatefulWidget {
  const ObjectScanScreen({super.key});

  @override
  State<ObjectScanScreen> createState() => _ObjectScanScreenState();
}

class _ObjectScanScreenState extends State<ObjectScanScreen> {
  final picker = ImagePicker();
  final service = ObjectScanService(Dio());

  Future<void> _scanObject() async {
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    final file = File(image.path);

    try {
      final detections = await service.scanImage(file);

      if (!mounted) return;

      Navigator.pop(context, detections);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Object scan mislukt: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Object herkennen')),
      body: Center(
        child: ElevatedButton(
          onPressed: _scanObject,
          child: const Text('Neem foto van product'),
        ),
      ),
    );
  }
}
