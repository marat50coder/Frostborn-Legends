import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/game_state.dart';
import 'screens/loading_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await hideSystemBars();
  runApp(const FrostbornApp());
}

class FrostbornApp extends StatelessWidget {
  const FrostbornApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameState>(
      create: (_) => GameState(),
      child: MaterialApp(
        title: 'Frostborn Legends',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        // The reels are laid out for a fixed portrait canvas, so keep system
        // font scaling from pushing labels out of their panels.
        builder: (BuildContext context, Widget? child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const LoadingScreen(),
      ),
    );
  }
}
