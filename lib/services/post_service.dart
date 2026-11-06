import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/comment.dart';
import '../models/post.dart';
import '../models/user.dart';

/// Seluruh pemanggilan REST API JSONPlaceholder.
class PostService {
  PostService({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl = 'https://jsonplaceholder.typicode.com';

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  final http.Client _client;

  void _ensureSuccess(http.Response response, String action) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Gagal $action. Status code: ${response.statusCode}');
    }
  }

  Future<List<Post>> getPosts() async {
    final response = await _client.get(Uri.parse('$baseUrl/posts'));
    _ensureSuccess(response, 'memuat daftar data');

    final List<dynamic> dataList = jsonDecode(response.body);
    return dataList
        .map((item) => Post.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Post> getPost(int id) async {
    final response = await _client.get(Uri.parse('$baseUrl/posts/$id'));
    _ensureSuccess(response, 'memuat detail data');

    return Post.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Mengembalikan balasan server. Catatan: server selalu memberi id 101
  /// dan tidak menyimpan data ini secara permanen.
  Future<Post> createPost({
    required String title,
    required String body,
    required int userId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/posts'),
      headers: _jsonHeaders,
      body: jsonEncode({'userId': userId, 'title': title, 'body': body}),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Gagal mengirim data. Status code: ${response.statusCode}',
      );
    }

    return Post.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Post> updatePost(Post post) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/posts/${post.id}'),
      headers: _jsonHeaders,
      body: jsonEncode(post.toJson()),
    );
    _ensureSuccess(response, 'memperbarui data');

    return Post.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deletePost(int id) async {
    final response = await _client.delete(Uri.parse('$baseUrl/posts/$id'));
    _ensureSuccess(response, 'menghapus data');
  }

  Future<List<Comment>> getComments(int postId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/posts/$postId/comments'),
    );
    _ensureSuccess(response, 'memuat komentar');

    final List<dynamic> dataList = jsonDecode(response.body);
    return dataList
        .map((item) => Comment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<User> getUser(int id) async {
    final response = await _client.get(Uri.parse('$baseUrl/users/$id'));
    _ensureSuccess(response, 'memuat data penulis');

    return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
