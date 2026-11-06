import '../models/comment.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/post_local_store.dart';
import '../services/post_service.dart';

class PostDetail {
  const PostDetail({
    required this.post,
    required this.comments,
    this.author,
  });

  final Post post;
  final List<Comment> comments;
  final User? author;
}

/// Menggabungkan data dari REST API dengan perubahan yang disimpan lokal.
class PostRepository {
  PostRepository({PostService? service, PostLocalStore? store})
    : _service = service ?? PostService(),
      _store = store ?? PostLocalStore.instance;

  final PostService _service;
  final PostLocalStore _store;

  static const int lastServerPostId = 100;

  bool isLocalPost(Post post) => post.id > lastServerPostId;

  int _nextLocalId(List<Post> created) {
    int highest = lastServerPostId;
    for (final post in created) {
      if (post.id > highest) highest = post.id;
    }
    return highest + 1;
  }

  Future<List<Post>> loadPosts() async {
    final remote = await _service.getPosts();
    final deleted = await _store.deletedIds();
    final edits = await _store.editedPosts();
    final created = await _store.createdPosts();

    final editById = {for (final post in edits) post.id: post};

    return <Post>[
      for (final post in remote)
        if (!deleted.contains(post.id)) editById[post.id] ?? post,
      ...created,
    ];
  }

  Future<Post> createPost({
    required String title,
    required String body,
    required int userId,
  }) async {
    // Request POST asli dikirim ke server. Balasan id-nya selalu 101,
    // jadi id unik dibuat di sisi aplikasi agar tidak saling menimpa.
    await _service.createPost(title: title, body: body, userId: userId);

    final created = await _store.createdPosts();
    final post = Post(
      userId: userId,
      id: _nextLocalId(created),
      title: title,
      body: body,
    );

    await _store.addCreated(post);
    return post;
  }

  Future<Post> updatePost(Post post) async {
    if (isLocalPost(post)) {
      await _store.replaceCreated(post);
      return post;
    }

    await _service.updatePost(post);
    await _store.saveEdit(post);
    return post;
  }

  Future<void> deletePost(Post post) async {
    if (isLocalPost(post)) {
      await _store.removeCreated(post.id);
      return;
    }

    await _service.deletePost(post.id);
    await _store.addDeletedId(post.id);
  }

  Future<PostDetail> loadDetail(Post post) async {
    final current = isLocalPost(post) ? post : await _service.getPost(post.id);
    final author = await _service.getUser(current.userId);
    final comments = await _service.getComments(current.id);

    return PostDetail(post: current, author: author, comments: comments);
  }
}
