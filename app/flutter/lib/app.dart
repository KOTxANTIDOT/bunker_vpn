import 'package:flutter/material.dart';

import 'features/home/presentation/home_screen.dart';
import 'theme/bunker_theme.dart';

class BunkerVpnApp extends StatelessWidget {
  const BunkerVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BUNKER VPN',
      debugShowCheckedModeBanner: false,
      theme: BunkerTheme.dark,
      home: const HomeScreen(),
    );
  }
}
