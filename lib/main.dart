import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/posts_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.restoreSession();
  await AuthService.instance.ensureDemoAccount();

  runApp(const PostsExplorerApp());
}

class PostsExplorerApp extends StatelessWidget {
  const PostsExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.instance.currentUserEmail != null;

    return MaterialApp(
      title: 'Posts Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const PostsScreen() : const LoginScreen(),
    );
  }
}
