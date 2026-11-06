import 'package:flutter/material.dart';

import '../models/post.dart';
import '../models/user.dart';
import '../repositories/post_repository.dart';
import 'post_form_screen.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final Post post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PostRepository _repository = PostRepository();

  late Future<PostDetail> _detailFuture;
  late Post _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _detailFuture = _loadFuture();
  }

  Future<PostDetail> _loadFuture() {
    return _repository.loadDetail(_currentPost).then((detail) {
      _currentPost = detail.post;
      return detail;
    });
  }

  void _reload() {
    setState(() => _detailFuture = _loadFuture());
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PostFormScreen(post: _currentPost)),
    );

    if (changed == true && mounted) _reload();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus postingan?'),
        content: Text(
          'Post #${_currentPost.id} akan dihapus dari daftar. '
          'Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final deletedPost = _currentPost;

    try {
      await _repository.deletePost(deletedPost);
      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Post #${deletedPost.id} dihapus via HTTP DELETE'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Postingan'),
        actions: [
          IconButton(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Hapus',
          ),
        ],
      ),
      body: FutureBuilder<PostDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}'),
              ),
            );
          }

          final detail = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PostCard(
                post: detail.post,
                isLocal: _repository.isLocalPost(detail.post),
              ),
              const SizedBox(height: 16),
              if (detail.author != null) ...[
                _AuthorCard(author: detail.author!),
                const SizedBox(height: 16),
              ],
              Text(
                'Komentar (${detail.comments.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (detail.comments.isEmpty)
                const _EmptyComments()
              else
                for (final comment in detail.comments)
                  _CommentCard(
                    name: comment.name,
                    email: comment.email,
                    body: comment.body,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.isLocal});

  final Post post;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: 'Post #${post.id}', theme: theme),
                _Chip(label: 'User #${post.userId}', theme: theme),
                if (isLocal)
                  _Chip(label: 'Buatan sendiri', theme: theme, emphasized: true),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: theme.dividerColor),
            const SizedBox(height: 12),
            Text(
              post.body,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({required this.author});

  final User author;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(author.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Username: @${author.username}'),
            Text('Email: ${author.email}'),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.name,
    required this.email,
    required this.body,
  });

  final String name;
  final String email;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              email,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'Belum ada komentar untuk postingan ini.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.theme,
    this.emphasized = false,
  });

  final String label;
  final ThemeData theme;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: emphasized
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
