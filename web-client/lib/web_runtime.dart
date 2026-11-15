import 'dart:convert';
import 'dart:async';
import 'dart:js_interop';
import 'package:teno_mobile/core/model.dart';
import 'package:teno_mobile/platform/runtime.g.dart';
import 'content_fonts.dart';

@JS('tenoWeb.call')
external JSPromise<JSString> _call(JSString method, JSString arguments);
@JS('tenoWeb.listen')
external void _listen(JSFunction listener);

/// The browser host implements the existing bridge without native channels.
class WebRuntime extends RuntimeHost {
  Future<String> call(String method, [Json args = const {}]) async {
    final result = (await _call(
      method.toJS,
      jsonEncode(args).toJS,
    ).toDart).toDart;
    // Reads wait for their own glyphs so a slow font cannot silently erase
    // characters from displayed notes. A successful mutation must never turn
    // into a retryable failure because of an unrelated display download.
    final reading =
        (method == 'request' && args['method'] == 'GET') ||
        (method == 'recording_cache' && args['action'] == 'read');
    if (reading) {
      if (!await ContentFonts.instance.ensure(result)) {
        throw StateError(
          'Text display resources could not load. Please retry.',
        );
      }
    } else {
      unawaited(ContentFonts.instance.ensure(result));
    }
    return result;
  }

  void listen(void Function(RuntimeState) onChange) =>
      _listen(((JSString value) => onChange(state(value.toDart))).toJS);

  RuntimeState state(String value) {
    final data = object(jsonDecode(value));
    final session = object(data['session']), player = object(data['playback']);
    return RuntimeState(
      sequence: (data['sequence'] as num).toInt(),
      session: SessionState(
        signedIn: session['signedIn'] == true,
        username: text(session['username']),
        scope: text(session['scope']),
        server: text(session['server']),
        cloudUpload: false,
        wifiOnly: false,
        livePreview: false,
        optionsSet: true,
      ),
      capture: CaptureState(
        source: '',
        phase: 'idle',
        elapsedMs: 0,
        localId: '',
        status: '',
        partial: '',
        segmentsJson: '[]',
        notes: '',
      ),
      device: DeviceState(
        connected: false,
        authorized: false,
        scanning: false,
        busy: false,
        receiving: false,
        receivedBytes: 0,
        expectedBytes: 0,
        identifier: '',
        name: '',
        battery: '',
        status: '',
        candidatesJson: '[]',
        filesJson: '[]',
      ),
      playback: PlaybackState(
        ready: player['ready'] == true,
        playing: player['playing'] == true,
        positionMs: (player['positionMs'] as num? ?? 0).toInt(),
        durationMs: (player['durationMs'] as num? ?? 0).toInt(),
        speed: (player['speed'] as num? ?? 1).toDouble(),
        mediaId: text(player['mediaId']),
        error: text(player['error']),
      ),
      draftsJson: jsonEncode(data['drafts'] ?? []),
      uploadStatus: text(data['uploadStatus']),
      openRoute: '',
    );
  }

  @override
  Future<RuntimeState> snapshot() async => state(await call('snapshot'));
  @override
  Future<SessionState> login(
    String server,
    String username,
    String password,
  ) async {
    await call('login', {'username': username, 'password': password});
    return (await snapshot()).session;
  }

  @override
  Future<void> logout() async {
    await call('logout');
  }

  @override
  Future<String> request(String method, String path, String? jsonBody) =>
      call('request', {
        'method': method,
        'path': path,
        'body': jsonBody == null ? null : jsonDecode(jsonBody),
      });
  @override
  Future<String> platformCommand(String command, String? jsonBody) =>
      call(command, jsonBody == null ? {} : object(jsonDecode(jsonBody)));
  @override
  Future<void> retryUpload(String localId) async {
    await call('retryUpload', {'id': localId});
  }

  @override
  Future<void> deleteLocal(String localId) async {
    await call('deleteLocal', {'id': localId});
  }

  @override
  Future<void> playback(
    PlaybackAction action,
    String mediaId,
    bool local,
    int positionMs,
    double speed,
  ) async {
    await call('playback', {
      'action': action.name,
      'id': mediaId,
      'local': local,
      'positionMs': positionMs,
      'speed': speed,
    });
  }

  @override
  Future<void> shareText(String value) async {
    await call('shareText', {'text': value});
  }
}
