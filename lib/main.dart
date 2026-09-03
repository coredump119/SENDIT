import 'package:flutter/material.dart';

import 'ui/app_state.dart';
import 'ui/scope.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  runApp(const SenditApp());
}

class SenditApp extends StatefulWidget {
  const SenditApp({super.key});
  @override
  State<SenditApp> createState() => _SenditAppState();
}

class _SenditAppState extends State<SenditApp> {
  final _state = AppState();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'SENDIT',
        debugShowCheckedModeBanner: false,
        theme: Tone.theme(),
        home: const Shell(),
      ),
    );
  }
}
