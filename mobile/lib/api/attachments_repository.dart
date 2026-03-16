import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'api_client.dart';
import '../models/attachment.dart';

class AttachmentsRepository {
  final Dio _dio = ApiClient.instance.dio;

  String contentUrl(String id) =>
      '${_dio.options.baseUrl}/attachments/$id/content';

  Future<List<Attachment>> list(String noteId) async {
    final r = await _dio.get('/notes/$noteId/attachments');
    return (r.data as List<dynamic>)
        .map((j) => Attachment.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Attachment> upload(String noteId, String filePath, String fileName) async {
    final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
    final parts = mimeType.split('/');
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: MediaType(parts[0], parts[1]),
      ),
    });
    final r = await _dio.post('/notes/$noteId/attachments', data: formData);
    return Attachment.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Attachment> uploadBytes(
      String noteId, List<int> bytes, String fileName, String mimeType) async {
    final parts = mimeType.split('/');
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: MediaType(parts[0], parts[1]),
      ),
    });
    final r = await _dio.post('/notes/$noteId/attachments', data: formData);
    return Attachment.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/attachments/$id');
  }

  /// Downloads attachment bytes with auth header.
  Future<List<int>> downloadBytes(String id) async {
    final r = await _dio.get<List<int>>(
      '/attachments/$id/content',
      options: Options(responseType: ResponseType.bytes),
    );
    return r.data!;
  }
}
