import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/note.dart';

class NotesRepository {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<Note>> list() async {
    final r = await _dio.get('/notes');
    return (r.data as List<dynamic>)
        .map((j) => Note.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Note> get(String id) async {
    final r = await _dio.get('/notes/$id');
    return Note.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Note> create({
    required String title,
    required String body,
    required bool isSecret,
    String? credential,
    String? color,
    List<String>? tagIds,
  }) async {
    final r = await _dio.post('/notes', data: {
      'title': title,
      'body': body,
      'is_secret': isSecret,
      if (credential != null) 'credential': credential,
      if (color != null) 'color': color,
      if (tagIds != null) 'tags': tagIds,
    });
    return Note.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Note> update(
    String id, {
    String? title,
    String? body,
    bool? isSecret,
    bool? isPinned,
    String? color,
    String? credential,
    List<String>? tagIds,
  }) async {
    final r = await _dio.put('/notes/$id', data: {
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (isSecret != null) 'is_secret': isSecret,
      if (isPinned != null) 'is_pinned': isPinned,
      if (color != null) 'color': color,
      if (credential != null) 'credential': credential,
      if (tagIds != null) 'tags': tagIds,
    });
    return Note.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/notes/$id');
  }

  Future<Note> unlock(String id, {required String credential}) async {
    final r = await _dio.post('/notes/$id/unlock', data: {
      'credential': credential,
    });
    return Note.fromJson(r.data as Map<String, dynamic>);
  }
}
