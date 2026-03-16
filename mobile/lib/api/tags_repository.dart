import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/tag.dart';

class TagsRepository {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<Tag>> list() async {
    final r = await _dio.get('/tags');
    return (r.data as List<dynamic>)
        .map((j) => Tag.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Tag> create(String name, String emoji) async {
    final r = await _dio.post('/tags', data: {'name': name, 'emoji': emoji});
    return Tag.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Tag> update(String id, {String? name, String? emoji}) async {
    final r = await _dio.put('/tags/$id', data: {
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
    });
    return Tag.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/tags/$id');
  }
}
