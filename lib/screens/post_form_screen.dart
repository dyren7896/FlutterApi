import 'package:flutter/material.dart';

import '../models/post.dart';
import '../repositories/post_repository.dart';

class PostFormScreen extends StatefulWidget {
  const PostFormScreen({super.key, this.post});

  /// null berarti mode tambah, terisi berarti mode edit.
  final Post? post;

  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _repository = PostRepository();

  int _userId = 1;
  bool _isSaving = false;

  bool get _isEdit => widget.post != null;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.post?.title ?? '';
    _bodyController.text = widget.post?.body ?? '';
    _userId = widget.post?.userId ?? 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    try {
      if (_isEdit) {
        await _repository.updatePost(
          Post(userId: _userId, id: widget.post!.id, title: title, body: body),
        );
        messenger.showSnackBar(
          SnackBar(content: Text('Post #${widget.post!.id} diperbarui via HTTP PUT')),
        );
      } else {
        final created = await _repository.createPost(
          title: title,
          body: body,
          userId: _userId,
        );
        messenger.showSnackBar(
          SnackBar(content: Text('Post #${created.id} terkirim via HTTP POST')),
        );
      }

      navigator.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Postingan' : 'Buat Postingan')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isEdit)
                      _InfoBox(
                        theme: theme,
                        text:
                            'Post #${widget.post!.id} — perubahan dikirim ke '
                            'server lewat HTTP PUT dan disimpan di perangkat ini.',
                      )
                    else
                      _InfoBox(
                        theme: theme,
                        text:
                            'Data dikirim ke /posts lewat HTTP POST. Server '
                            'JSONPlaceholder hanya membalas, tidak menyimpan.',
                      ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      maxLength: 120,
                      validator: (value) {
                        final input = value?.trim() ?? '';
                        if (input.isEmpty) return 'Judul wajib diisi';
                        if (input.length < 5) {
                          return 'Judul minimal 5 karakter';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Judul postingan',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bodyController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 8,
                      maxLength: 1000,
                      validator: (value) {
                        final input = value?.trim() ?? '';
                        if (input.isEmpty) return 'Isi postingan wajib diisi';
                        if (input.length < 10) {
                          return 'Isi postingan minimal 10 karakter';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Isi postingan',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _userId,
                      decoration: const InputDecoration(
                        labelText: 'Penulis (userId)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: List.generate(
                        10,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('User #${index + 1}'),
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _userId = value ?? _userId),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_isEdit ? Icons.save : Icons.send),
                      label: Text(_isEdit ? 'Simpan perubahan' : 'Kirim postingan'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.theme, required this.text});

  final ThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
