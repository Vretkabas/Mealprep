import 'dart:io';
import 'package:dio/dio.dart';

class ObjectScanService {
  final Dio dio;

  ObjectScanService(this.dio);

  Future<List<dynamic>> scanImage(File image) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(image.path),
    });

    final response = await dio.post(
      'http://10.0.2.2:8000/scan/image', // emulator
      data: formData,
    );

    return response.data['detections'];
  }
}
