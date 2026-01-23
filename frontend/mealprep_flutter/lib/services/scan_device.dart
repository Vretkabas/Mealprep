import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';

final scanServiceProvider = Provider<ScanService>((ref) {
  final dio = ref.watch(dioProvider);
  return ScanService(dio);
});

class ScanService {
  final Dio dio;
  ScanService(this.dio);

  Future<Map<String, dynamic>> scanImage(String path) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(path),
    });

    final response = await dio.post(
      '/scan/image',
      data: formData,
    );

    return response.data;
  }
}
