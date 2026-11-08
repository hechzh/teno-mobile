import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../platform/runtime.g.dart';

typedef Json = Map<String, dynamic>;

Json object(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Json> rows(Object? value) =>
    value is List ? value.map(object).toList() : [];
List<Json> jsonRows(String value) => rows(jsonDecode(value));
String text(Object? value) => value?.toString() ?? '';
String recordingStatus(Object? value) => switch (text(value)) {
  'local' => 'Saved on this phone',
  'queued' => 'Waiting to upload',
  'uploading' => 'Uploading',
  'processing' || 'transcribing' => 'Preparing transcript and summary',
  'transcribed' || 'uploaded' => 'Ready',
  'recording' => 'Recording',
  'failed' => 'Upload needs attention',
  'invalid' => 'Audio could not be verified',
  _ => text(value),
};
String requestId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String duration(Object? value) {
  final seconds = ((value is num ? value : 0) / 1000).floor().clamp(0, 999999);
  return (seconds ~/ 60).toString().padLeft(2, '0') +
      ':' +
      (seconds % 60).toString().padLeft(2, '0');
}

String dateLabel(Object? value) {
  final date = DateTime.tryParse(text(value))?.toLocal();
  if (date == null) return '';
  return date.year.toString() +
      '-' +
      date.month.toString().padLeft(2, '0') +
      '-' +
      date.day.toString().padLeft(2, '0');
}

class TenoModel extends ChangeNotifier implements RuntimeEvents {
  TenoModel({RuntimeHost? host, this.webExperience = false})
    : host = host ?? RuntimeHost();
  final RuntimeHost host;
  // Opt-in only for the independent browser host. Native behavior stays unchanged.
  final bool webExperience;
  RuntimeState? runtime;
  List<Json> recordings = [], folders = [];
  Json capabilities = {}, personalSettings = {};
  bool personalCore = false;
  String error = '';
  bool loading = false, moreAvailable = true;
  Timer? _processingTimer;
  bool _disposed = false;
  bool get signedIn => runtime?.session.signedIn ?? false;
  List<Json> get drafts => runtime == null ? [] : jsonRows(runtime!.draftsJson);
  bool get capturing => [
    'starting',
    'recording',
    'paused',
    'stopping',
    'saving',
    'interrupted',
  ].contains(runtime?.capture.phase);

  Future<void> initialize() async {
    RuntimeEvents.setUp(this);
    try {
      changed(await host.snapshot());
      if (signedIn) {
        await loadPersonal();
        await refresh();
      }
    } catch (e) {
      error = friendly(e);
      notifyListeners();
    }
    _processingTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (signedIn &&
          !loading &&
          recordings.any(
            (r) =>
                ['queued', 'processing', 'transcribing'].contains(r['status']),
          )) {
        unawaited(refresh());
      }
    });
  }

  @override
  void changed(RuntimeState state) {
    if (_disposed) return;
    final previous = runtime;
    if (previous != null && state.sequence < previous.sequence) return;
    if (previous?.session.scope != state.session.scope) {
      recordings = [];
      folders = [];
      error = '';
      personalSettings = {};
      capabilities = {};
      personalCore = false;
    }
    runtime = state;
    notifyListeners();
  }

  Future<Json> api(String method, String path, [Json? body]) async {
    final scope = runtime?.session.scope;
    final result = await host.request(
      method,
      path,
      body == null ? null : jsonEncode(body),
    );
    if (scope != runtime?.session.scope)
      throw StateError('Account changed. Reload this page.');
    return object(jsonDecode(result));
  }

  Future<List<Json>> list(String path) async =>
      rows((await api('GET', path))['items']);

  Future<Json> command(String action, [Json? args]) async => object(
    jsonDecode(
      await host.platformCommand(
        action,
        args == null ? null : jsonEncode(args),
      ),
    ),
  );

  Future<void> loadPersonal() async {
    try {
      final native = await command('preferences');
      personalCore = native['personal_core'] == true;
      personalSettings = object(native['settings']);
      if (!_disposed) notifyListeners();
    } catch (_) {}
    try {
      capabilities = await api('GET', '/api/v1/capabilities');
      personalCore = personalCore || capabilities['personal_core'] == 1;
      if (personalCore) {
        personalSettings = await api('GET', '/api/v1/personal/preferences');
        await command('cache_preferences', personalSettings);
      }
    } catch (_) {
      /* Local recording remains available offline. */
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> updatePersonal(Json values) async {
    personalSettings = await api(
      'PATCH',
      '/api/v1/personal/preferences',
      values,
    );
    await command('cache_preferences', personalSettings);
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh({bool append = false}) async {
    if (!signedIn || loading) return;
    loading = true;
    error = '';
    notifyListeners();
    try {
      final offset = append ? recordings.length : 0;
      final values = await Future.wait([
        list('/api/v1/recordings?limit=50&offset=' + offset.toString()),
        list('/api/v1/folders?limit=200'),
      ]);
      recordings = append ? [...recordings, ...values[0]] : values[0];
      folders = values[1];
      moreAvailable = values[0].length == 50;
    } catch (e) {
      error = friendly(e);
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> signIn(String server, String username, String password) async {
    await host.login(server, username.trim(), password);
    changed(await host.snapshot());
    await loadPersonal();
    await refresh();
  }

  Future<void> signOut() async {
    await host.logout();
    changed(await host.snapshot());
  }

  static String friendly(Object error) {
    if (error is PlatformException)
      return error.message ?? 'The action could not be completed. Try again.';
    final value = error.toString();
    // Never put arguments, request bodies or authentication headers in UI errors.
    if (value.contains('PlatformException(')) {
      final parts = value.split(', ');
      if (parts.length > 1) return parts[1];
    }
    return value
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }

  @override
  void dispose() {
    _disposed = true;
    _processingTimer?.cancel();
    RuntimeEvents.setUp(null);
    super.dispose();
  }
}
