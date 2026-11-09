import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

@JS('tenoAssets.bytes')
external JSPromise<JSUint8Array> _bytes(JSString path);
@JS('tenoAssets.listenInput')
external void _listenInput(JSFunction listener);

/// Only glyph asset names leave the browser, never text, credentials or audio.
/// FontLoader notifies Flutter's systemFonts listener after registration.
class ContentFonts {
  static final instance = ContentFonts();
  Future<void>? _index;
  final Map<int, String> _glyphs = {};
  final Map<String, String> _families = {};
  final Map<String, Future<void>> _loading = {};
  final Set<String> _loaded = {};
  final Set<int> _requested = {};
  final failed = ValueNotifier<bool>(false);
  Timer? _typing;

  void listen() {
    _listenInput(
      ((JSString value) {
        _typing?.cancel();
        _typing = Timer(const Duration(milliseconds: 100), () {
          unawaited(ensure(value.toDart));
        });
      }).toJS,
    );
  }

  Future<Uint8List> bytes(String name) async =>
      (await _bytes('assets/fonts/subsets/$name'.toJS).toDart).toDart;

  Future<void> _readIndex() async {
    final data = jsonDecode(utf8.decode(await bytes('manifest.json'))) as Map;
    for (final chunk in data['chunks'] as List) {
      _families[chunk['file'] as String] = chunk['family'] as String;
      for (final rune in (chunk['chars'] as String).runes) {
        _glyphs[rune] = chunk['file'] as String;
      }
    }
  }

  Future<void> _load(String name) async {
    try {
      final data = await bytes(name);
      final loader = FontLoader(_families[name]!);
      loader.addFont(Future.value(ByteData.sublistView(data)));
      await loader.load();
      _loaded.add(name);
    } finally {
      _loading.remove(name);
    }
  }

  Future<void> ensure(String content) async {
    _requested.addAll(content.runes.where((c) => c > 255));
    if (_requested.isEmpty) return;
    try {
      try {
        await (_index ??= _readIndex());
      } catch (_) {
        _index = null;
        rethrow;
      }
      final names = _requested
          .map((c) => _glyphs[c])
          .whereType<String>()
          .toSet();
      // Limit concurrent transfers on mobile networks. Repeated API/cache/IME
      // text shares in-flight work; a failed chunk stays retryable next time.
      final pending = names.where((name) => !_loaded.contains(name)).toList();
      for (var offset = 0; offset < pending.length; offset += 4) {
        await Future.wait(
          pending
              .skip(offset)
              .take(4)
              .map((name) => _loading[name] ??= _load(name)),
        );
      }
      if (_requested
          .map((c) => _glyphs[c])
          .whereType<String>()
          .every(_loaded.contains)) {
        failed.value = false;
      }
    } catch (_) {
      // A font outage must not convert a successful upload/save into a failed
      // operation or hide already cached notes. Subsequent reads/typing retry.
      failed.value = true;
    }
  }
}

class ContentFontNotice extends StatelessWidget {
  const ContentFontNotice({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: ContentFonts.instance.failed,
    child: child,
    builder: (context, failed, child) {
      final zh = Localizations.localeOf(context).languageCode == 'zh';
      return Column(
        // Paint the notice after Navigator so a modal route cannot suppress
        // its accessibility nodes. Keep Navigator's position stable on errors.
        verticalDirection: VerticalDirection.up,
        children: [
          Expanded(child: child!),
          if (failed)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          zh
                              ? '部分文字显示资源未能加载。'
                              : 'Some text display resources could not load.',
                        ),
                      ),
                      TextButton(
                        onPressed: () => ContentFonts.instance.ensure(''),
                        child: Text(zh ? '重试' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
