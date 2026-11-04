import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import 'recorder.dart';

class LoginPage extends StatefulWidget {
  const LoginPage(this.model, {super.key});
  final TenoModel model;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController(), password = TextEditingController();
  late final server = TextEditingController(
    text: widget.model.runtime?.session.server,
  );
  bool busy = false, advanced = false;
  String error = '';
  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.model.signIn(
        server.text.trim(),
        username.text,
        password.text,
      );
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      password.clear();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              const Text(
                'Teno',
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your conversations,\nyour clarity.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sign in to your Teno account.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 32),
              AutofillGroup(
                child: Column(
                  children: [
                    TextField(
                      controller: username,
                      enabled: !busy,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: password,
                      enabled: !busy,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => submit(),
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                  ],
                ),
              ),
              if (error.isNotEmpty) ErrorNotice(error),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Signing in…' : 'Sign in'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: busy
                    ? null
                    : () => push(context, DevicePage(widget.model)),
                child: const Text('Connect a recorder without signing in'),
              ),
              TextButton(
                onPressed: () => setState(() => advanced = !advanced),
                child: const Text('Server settings'),
              ),
              if (advanced)
                TextField(
                  controller: server,
                  enabled: !busy,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'HTTPS server'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    username.dispose();
    password.dispose();
    server.dispose();
    super.dispose();
  }
}
