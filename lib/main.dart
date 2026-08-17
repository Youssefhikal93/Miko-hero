import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/iam_hero_app.dart';

/// Starts the local-first Flutter application inside a Riverpod container.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: IamHeroApp()));
}
