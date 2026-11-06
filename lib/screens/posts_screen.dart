import 'package:flutter/material.dart';

import '../models/post.dart';
import '../repositories/post_repository.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'post_detail_screen.dart';
import 'post_form_screen.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final PostRepository _repository = PostRepository();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Post>> _postsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _postsFuture = _repository.loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _postsFuture = _repository.loadPosts());
  }

  Future<void> _refresh() async {
    _reload();
    // Error sengaja tidak dilempar ulang: FutureBuilder yang menampilkannya.
    try {
      await _postsFuture;
    } catch (_) {}
  }

  Future<void> _openDetail(Post post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
    );

    if (changed == true && mounted) _reload();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PostFormScreen()),
    );

    if (created == true && mounted) _reload();
  }

  Future<bool> _confirmDelete(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus postingan?'),
        content: Text('Post #${post.id} akan dihapus dari daftar.'),
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

    return confirmed ?? false;
  }

  Future<void> _performDelete(Post post) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _repository.deletePost(post);
      messenger.showSnackBar(
        SnackBar(content: Text('Post #${post.id} dihapus via HTTP DELETE')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }

    _reload();
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    await AuthService.instance.logout();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  List<Post> _applyFilter(List<Post> posts) {
    if (_query.isEmpty) return posts;

    final needle = _query.toLowerCase();
    return posts
        .where(
          (post) =>
              post.title.toLowerCase().contains(needle) ||
              post.body.toLowerCase().contains(needle),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Posts Explorer'),
            Text(
              AuthService.instance.currentUserEmail ?? '',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Post Baru'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'Cari judul atau isi postingan',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Bersihkan',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Post>>(
              future: _postsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _MessageView(
                    icon: Icons.wifi_off,
                    message: '${snapshot.error}',
                    actionLabel: 'Coba lagi',
                    onAction: _reload,
                  );
                }

                final allPosts = snapshot.data ?? const <Post>[];
                final posts = _applyFilter(allPosts);

                if (allPosts.isEmpty) {
                  return _MessageView(
                    icon: Icons.inbox_outlined,
                    message: 'Tidak ada data postingan.',
                    actionLabel: 'Muat ulang',
                    onAction: _reload,
                  );
                }

                if (posts.isEmpty) {
                  return _MessageView(
                    icon: Icons.search_off,
                    message: 'Tidak ada hasil untuk "$_query".',
                    actionLabel: 'Hapus pencarian',
                    onAction: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                    itemCount: posts.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ResultCounter(
                          shown: posts.length,
                          total: allPosts.length,
                        );
                      }

                      final post = posts[index - 1];

                      return Dismissible(
                        key: ValueKey<int>(post.id),
                        direction: DismissDirection.endToStart,
                        background: _SwipeToDeleteBackground(theme: theme),
                        confirmDismiss: (_) => _confirmDelete(post),
                        onDismissed: (_) => _performDelete(post),
                        child: _PostTile(
                          post: post,
                          onTap: () => _openDetail(post),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCounter extends StatelessWidget {
  const _ResultCounter({required this.shown, required this.total});

  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        shown == total
            ? 'Menampilkan $total data dari REST API'
            : 'Menampilkan $shown dari $total data',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SwipeToDeleteBackground extends StatelessWidget {
  const _SwipeToDeleteBackground({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = post.body.replaceAll('\n', ' ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Badge(label: 'Post #${post.id}'),
                  const SizedBox(width: 8),
                  _Badge(label: 'User #${post.userId}'),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                post.title,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                preview.length > 100
                    ? '${preview.substring(0, 100)}...'
                    : preview,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Read More'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
