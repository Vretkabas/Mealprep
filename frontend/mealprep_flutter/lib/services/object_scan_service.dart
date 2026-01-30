import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

String _getBaseUrl() {
  if (kIsWeb) {
    return 'http://localhost:8081';
  } else if (Platform.isAndroid) {
    return 'http://10.0.2.2:8081';
  } else {
    return 'http://localhost:8081';
  }
}

class ObjectScanService {
  final Dio dio;

  ObjectScanService(this.dio);

  Future<List<dynamic>> scanImage(File image) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(image.path),
    });

    final response = await dio.post(
      '${_getBaseUrl()}/scan/image',
      data: formData,
    );

    return response.data['detections'];
  }
}
