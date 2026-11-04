import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/runtime.g.dart',
    javaOut: '../app/src/main/java/com/teno/app/RuntimeMessages.java',
    javaOptions: JavaOptions(package: 'com.teno.app'),
    swiftOut: '../ios/Teno/Generated/RuntimeMessages.g.swift',
    dartPackageName: 'teno_mobile',
  ),
)
class SessionState {
  SessionState({
    required this.signedIn,
    required this.username,
    required this.scope,
    required this.server,
    required this.cloudUpload,
    required this.wifiOnly,
    required this.livePreview,
    required this.optionsSet,
  });
  bool signedIn;
  String username;
  String scope;
  String server;
  bool cloudUpload;
  bool wifiOnly;
  bool livePreview;
  bool optionsSet;
}

class CaptureState {
  CaptureState({
    required this.source,
    required this.phase,
    required this.elapsedMs,
    required this.localId,
    required this.status,
    required this.partial,
    required this.segmentsJson,
    required this.notes,
  });
  String source;
  String phase;
  int elapsedMs;
  String localId;
  String status;
  String partial;
  String segmentsJson;
  String notes;
}

class DeviceState {
  DeviceState({
    required this.connected,
    required this.authorized,
    required this.scanning,
    required this.busy,
    required this.receiving,
    required this.receivedBytes,
    required this.expectedBytes,
    required this.identifier,
    required this.name,
    required this.battery,
    required this.status,
    required this.candidatesJson,
    required this.filesJson,
  });
  bool connected;
  bool authorized;
  bool scanning;
  bool busy;
  bool receiving;
  int receivedBytes;
  int expectedBytes;
  String identifier;
  String name;
  String battery;
  String status;
  String candidatesJson;
  String filesJson;
}

class PlaybackState {
  PlaybackState({
    required this.ready,
    required this.playing,
    required this.positionMs,
    required this.durationMs,
    required this.speed,
    required this.mediaId,
    required this.error,
  });
  bool ready;
  bool playing;
  int positionMs;
  int durationMs;
  double speed;
  String mediaId;
  String error;
}

class RuntimeState {
  RuntimeState({
    required this.sequence,
    required this.session,
    required this.capture,
    required this.device,
    required this.playback,
    required this.draftsJson,
    required this.uploadStatus,
    required this.openRoute,
  });
  int sequence;
  SessionState session;
  CaptureState capture;
  DeviceState device;
  PlaybackState playback;
  String draftsJson;
  String uploadStatus;
  String openRoute;
}

enum PhoneAction { pause, resume, stop, retryPreview }

enum DeviceAction {
  scan,
  compatibilityScan,
  probe,
  connect,
  disconnect,
  refresh,
  start,
  pause,
  resume,
  stop,
  sync,
  cancelTransfer,
}

enum PlaybackAction { play, pause, seek, speed, stop }

@HostApi()
abstract class RuntimeHost {
  @async
  RuntimeState snapshot();
  @async
  SessionState login(String server, String username, String password);
  @async
  void logout();
  @async
  String request(String method, String path, String? jsonBody);
  @async
  void configure(bool cloudUpload, bool wifiOnly, bool livePreview);
  @async
  String startPhone(String title);
  @async
  void controlPhone(PhoneAction action);
  @async
  void controlDevice(DeviceAction action, String identifier, String name);
  @async
  void bindDevice(String identifier, String name, String key, bool createNew);
  @async
  void showDeviceKey();
  @async
  void saveNotes(String localId, String notes);
  @async
  void retryUpload(String localId);
  @async
  void deleteLocal(String localId);
  @async
  String? importAudio();
  @async
  void playback(
    PlaybackAction action,
    String mediaId,
    bool local,
    int positionMs,
    double speed,
  );
  @async
  void shareExport(String recordingId, String format);
  @async
  void shareText(String text);
}

@FlutterApi()
abstract class RuntimeEvents {
  void changed(RuntimeState state);
}
