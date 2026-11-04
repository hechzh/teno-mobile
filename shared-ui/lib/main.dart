import 'dart:async';
import 'package:flutter/material.dart';
import 'core/model.dart';
import 'ui/widgets.dart';
import 'features/home.dart';
import 'features/login.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TenoApp(model: TenoModel()));
}

class TenoApp extends StatefulWidget {
  const TenoApp({super.key, required this.model, this.initialize = true});
  final TenoModel model;
  final bool initialize;
  @override
  State<TenoApp> createState() => _TenoAppState();
}

class _TenoAppState extends State<TenoApp> {
  @override
  void initState() {
    super.initState();
    if (widget.initialize) unawaited(widget.model.initialize());
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) => MaterialApp(
      title: 'Teno',
      debugShowCheckedModeBanner: false,
      theme: tenoTheme(),
      // Reset the complete route stack when the account changes.
      key: ValueKey(widget.model.runtime?.session.scope ?? 'initializing'),
      home: widget.model.runtime == null
          ? Scaffold(
              body: Center(
                child: widget.model.error.isEmpty
                    ? const CircularProgressIndicator()
                    : ErrorNotice(
                        widget.model.error,
                        retry: () => unawaited(widget.model.initialize()),
                      ),
              ),
            )
          : widget.model.signedIn
          ? HomePage(widget.model)
          : LoginPage(widget.model),
    ),
  );
  @override
  void dispose() {
    widget.model.dispose();
    super.dispose();
  }
}
