import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/post.dart';

/// Menyimpan perubahan pengguna di perangkat, karena JSONPlaceholder
/// hanya berpura-pura menulis: hasilnya hilang begitu request selesai.
class PostLocalStore {
  PostLocalStore._();

  static final PostLocalStore instance = PostLocalStore._();

  static const String _createdKey = 'local_created_posts';
  static const String _editedKey = 'local_edited_posts';
  static const String _deletedKey = 'local_deleted_post_ids';

  Future<List<Post>> _readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return <Post>[];

    final List<dynamic> decoded = jsonDecode(raw);
    return decoded
        .map((item) => Post.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeList(String key, List<Post> posts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(posts.map((post) => post.toJson()).toList()),
    );
  }

  Future<List<Post>> createdPosts() => _readList(_createdKey);

  Future<List<Post>> editedPosts() => _readList(_editedKey);

  Future<void> addCreated(Post post) async {
    final posts = await createdPosts();
    posts.add(post);
    await _writeList(_createdKey, posts);
  }

  Future<void> replaceCreated(Post post) async {
    final posts = await createdPosts();
    final index = posts.indexWhere((item) => item.id == post.id);
    if (index < 0) return;

    posts[index] = post;
    await _writeList(_createdKey, posts);
  }

  Future<void> removeCreated(int id) async {
    final posts = await createdPosts();
    posts.removeWhere((item) => item.id == id);
    await _writeList(_createdKey, posts);
  }

  Future<void> saveEdit(Post post) async {
    final posts = await editedPosts();
    final index = posts.indexWhere((item) => item.id == post.id);

    if (index < 0) {
      posts.add(post);
    } else {
      posts[index] = post;
    }
    await _writeList(_editedKey, posts);
  }

  Future<Set<int>> deletedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_deletedKey);
    if (raw == null) return <int>{};

    return (jsonDecode(raw) as List<dynamic>).cast<int>().toSet();
  }

  Future<void> addDeletedId(int id) async {
    final ids = await deletedIds();
    ids.add(id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deletedKey, jsonEncode(ids.toList()));
  }
}
