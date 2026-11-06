import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_api/models/post.dart';
import 'package:flutter_api/repositories/post_repository.dart';
import 'package:flutter_api/services/post_local_store.dart';
import 'package:flutter_api/services/post_service.dart';

void main() {
  final requested = <String>[];

  /// Server palsu yang meniru perilaku JSONPlaceholder:
  /// hanya punya post id 1-3, dan POST selalu membalas id 101.
  PostService fakeService() {
    final client = MockClient((request) async {
      final method = request.method;
      final path = request.url.path;
      requested.add('$method $path');

      if (method == 'GET' && path == '/posts') {
        return http.Response(
          jsonEncode([
            for (int id = 1; id <= 3; id++)
              {'userId': 1, 'id': id, 'title': 'judul $id', 'body': 'isi $id'},
          ]),
          200,
        );
      }

      if (method == 'GET' && RegExp(r'^/posts/\d+$').hasMatch(path)) {
        final id = int.parse(path.split('/').last);
        return http.Response(
          jsonEncode({'userId': 1, 'id': id, 'title': 'judul $id', 'body': 'isi $id'}),
          200,
        );
      }

      if (method == 'POST' && path == '/posts') {
        return http.Response(
          jsonEncode({'userId': 1, 'id': 101, 'title': 'echo', 'body': 'echo'}),
          201,
        );
      }

      if (method == 'PUT' && RegExp(r'^/posts/\d+$').hasMatch(path)) {
        return http.Response(request.body, 200);
      }

      if (method == 'DELETE') {
        return http.Response('{}', 200);
      }

      if (method == 'GET' && path.endsWith('/comments')) {
        return http.Response('[]', 200);
      }

      if (method == 'GET' && path.startsWith('/users/')) {
        return http.Response(
          jsonEncode({'id': 1, 'name': 'Budi', 'username': 'budi', 'email': 'budi@mail.com'}),
          200,
        );
      }

      return http.Response('not found', 404);
    });

    return PostService(client: client);
  }

  PostRepository buildRepository() =>
      PostRepository(service: fakeService(), store: PostLocalStore.instance);

  setUp(() {
    requested.clear();
    SharedPreferences.setMockInitialValues({});
  });

  group('createPost (HTTP POST)', () {
    test('mengirim request POST dan menyimpan hasilnya secara lokal', () async {
      final repo = buildRepository();

      final created = await repo.createPost(
        title: 'Post baru',
        body: 'Isi post baru',
        userId: 2,
      );

      expect(requested, contains('POST /posts'));
      expect(created.id, 101);
      expect(created.userId, 2);

      final posts = await repo.loadPosts();
      expect(posts.map((post) => post.id), containsAll(<int>[101]));
      expect(posts.length, 4);
    });

    test('id lokal tetap unik walau server selalu membalas 101', () async {
      final repo = buildRepository();

      final first = await repo.createPost(title: 'Satu', body: 'isi satu', userId: 1);
      final second = await repo.createPost(title: 'Dua', body: 'isi dua', userId: 1);

      expect(first.id, 101);
      expect(second.id, 102);
    });

    test('id lokal tidak menimpa post yang ada setelah salah satunya dihapus', () async {
      final repo = buildRepository();

      await repo.createPost(title: 'Satu', body: 'isi satu', userId: 1);
      final second = await repo.createPost(title: 'Dua', body: 'isi dua', userId: 1);

      await repo.deletePost(
        const Post(userId: 1, id: 101, title: 'Satu', body: 'isi satu'),
      );

      final third = await repo.createPost(title: 'Tiga', body: 'isi tiga', userId: 1);

      expect(second.id, 102);
      expect(third.id, 103);
    });
  });

  group('deletePost (HTTP DELETE)', () {
    test('post dari server hilang dari daftar dan request DELETE dikirim', () async {
      final repo = buildRepository();

      await repo.deletePost(
        const Post(userId: 1, id: 2, title: 'judul 2', body: 'isi 2'),
      );

      expect(requested, contains('DELETE /posts/2'));

      final posts = await repo.loadPosts();
      expect(posts.map((post) => post.id), isNot(contains(2)));
      expect(posts.length, 2);
    });

    test('post buatan sendiri dihapus tanpa memanggil server', () async {
      final repo = buildRepository();

      final created = await repo.createPost(
        title: 'Lokal',
        body: 'isi lokal',
        userId: 1,
      );
      requested.clear();

      await repo.deletePost(created);

      expect(requested, isEmpty);
      expect((await repo.loadPosts()).map((post) => post.id), isNot(contains(created.id)));
    });
  });

  group('updatePost (HTTP PUT)', () {
    test('post dari server diperbarui lewat PUT dan tersimpan lokal', () async {
      final repo = buildRepository();

      await repo.updatePost(
        const Post(userId: 1, id: 1, title: 'judul diubah', body: 'isi diubah'),
      );

      expect(requested, contains('PUT /posts/1'));

      final posts = await repo.loadPosts();
      final updated = posts.firstWhere((post) => post.id == 1);
      expect(updated.title, 'judul diubah');
    });

    test('post buatan sendiri diperbarui tanpa memanggil server', () async {
      final repo = buildRepository();

      final created = await repo.createPost(
        title: 'Awal',
        body: 'isi awal',
        userId: 1,
      );
      requested.clear();

      await repo.updatePost(
        Post(userId: 1, id: created.id, title: 'Diedit', body: 'isi diedit'),
      );

      expect(requested, isEmpty);

      final posts = await repo.loadPosts();
      expect(posts.firstWhere((post) => post.id == created.id).title, 'Diedit');
    });
  });

  group('loadDetail', () {
    test('memuat post, penulis, dan komentar', () async {
      final repo = buildRepository();

      final detail = await repo.loadDetail(
        const Post(userId: 1, id: 1, title: 'judul 1', body: 'isi 1'),
      );

      expect(requested, contains('GET /posts/1'));
      expect(requested, contains('GET /users/1'));
      expect(requested, contains('GET /posts/1/comments'));
      expect(detail.author?.name, 'Budi');
      expect(detail.comments, isEmpty);
    });

    test('post lokal tidak meminta detail ke server', () async {
      final repo = buildRepository();

      final created = await repo.createPost(
        title: 'Lokal',
        body: 'isi lokal',
        userId: 1,
      );
      requested.clear();

      final detail = await repo.loadDetail(created);

      expect(requested, isNot(contains('GET /posts/${created.id}')));
      expect(detail.post.title, 'Lokal');
    });
  });

  group('penanganan error', () {
    test('kegagalan server menghentikan proses dan melempar exception', () async {
      final client = MockClient((request) async => http.Response('boom', 500));
      final repo = PostRepository(
        service: PostService(client: client),
        store: PostLocalStore.instance,
      );

      expect(
        () => repo.createPost(title: 'Gagal', body: 'isi gagal', userId: 1),
        throwsA(isA<Exception>()),
      );
    });
  });
}
