import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String _getBaseUrl() {
  return dotenv.env['API_BASE_URL'] ?? 'http://localhost:8081';
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
