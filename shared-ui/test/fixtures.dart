// Synthetic, test-only content. This file is never imported by the application.
import 'dart:convert';
import '../lib/platform/runtime.g.dart';
import '../lib/core/model.dart';

final reviewRecordings = <Json>[
  {
    'id': 'record-1',
    'title': 'Product launch review',
    'duration_ms': 1458000,
    'status': 'ready',
    'created_at': '2026-11-04T09:00:00Z',
    'revision': 1,
  },
  {
    'id': 'record-2',
    'title': 'Weekly planning',
    'duration_ms': 1926000,
    'status': 'ready',
    'created_at': '2026-11-04T08:15:00Z',
    'revision': 1,
  },
  {
    'id': 'record-3',
    'title': 'Customer interview — Maya',
    'duration_ms': 2571000,
    'status': 'ready',
    'created_at': '2026-11-03T16:30:00Z',
    'revision': 1,
  },
];
final reviewSummary = <String, dynamic>{
  'id': 'summary-1',
  'kind': 'summary',
  'created_at': '2026-11-04T09:30:00Z',
  'data': {
    'title': 'Product launch review',
    'summary':
        'The team reviewed the launch timeline and agreed to focus on a clear first experience. Customer feedback will guide the next release.',
    'key_points': [
      'Complete the recording flow before expanding the feature set.',
      'Review the onboarding copy and check the export experience.',
    ],
    'action_items': [
      {'text': 'Prepare the next design review.'},
    ],
  },
};
RuntimeState reviewState({
  bool signedIn = true,
  int sequence = 1,
  String scope = 'review-account',
  String phase = 'idle',
  bool connected = false,
}) => RuntimeState(
  sequence: sequence,
  session: SessionState(
    signedIn: signedIn,
    username: signedIn ? 'Alex' : '',
    scope: signedIn ? scope : '',
    server: 'https://api.example.test',
    cloudUpload: true,
    wifiOnly: false,
    livePreview: true,
    optionsSet: true,
  ),
  capture: CaptureState(
    source: phase == 'idle' ? 'phone' : 'device',
    phase: phase,
    elapsedMs: 142000,
    localId: phase == 'idle' ? 'local-1' : 'jwd:review-recorder|meeting.opus',
    status: phase == 'paused'
        ? 'Recorder paused'
        : 'Recording on your recorder',
    partial: 'We should review the recording experience.',
    segmentsJson: jsonEncode([
      {
        'text': 'Let’s begin with the launch timeline.',
        'start_ms': 0,
        'end_ms': 4200,
      },
    ]),
    notes: '02:10 · Check onboarding copy',
  ),
  device: DeviceState(
    connected: connected,
    authorized: connected,
    scanning: false,
    busy: false,
    receiving: false,
    receivedBytes: 0,
    expectedBytes: 0,
    identifier: 'review-recorder',
    name: 'JWD recorder',
    battery: connected ? '82%' : 'Not received',
    status: connected
        ? 'Recorder connected'
        : 'Connect your recorder to get started.',
    candidatesJson: '[]',
    filesJson: '[]',
  ),
  playback: PlaybackState(
    ready: false,
    playing: false,
    positionMs: 0,
    durationMs: 0,
    speed: 1,
    mediaId: '',
    error: '',
  ),
  draftsJson: jsonEncode([
    {
      'id': 'local-1',
      'title': 'Design review',
      'duration_ms': 142000,
      'status': 'local',
      'scope': scope,
      'created_at': '2026-11-04T10:00:00Z',
      'notes': '02:10 · Check onboarding copy',
    },
  ]),
  uploadStatus: '',
  openRoute: '',
);

class FixtureHost extends RuntimeHost {
  RuntimeState state = reviewState();
  final calls = <String>[];
  @override
  Future<RuntimeState> snapshot() async => state;
  @override
  Future<void> saveNotes(String localId, String notes) async {
    calls.add('notes');
  }

  @override
  Future<void> controlDevice(
    DeviceAction action,
    String id,
    String name,
  ) async {
    calls.add('device:' + action.name);
  }

  @override
  Future<String> startPhone(String title) async {
    calls.add('phone');
    return 'local-1';
  }

  @override
  Future<String> request(String method, String path, String? jsonBody) async {
    calls.add(method + ' ' + path);
    Object result = {};
    if (path == '/api/v1/me')
      result = {
        'id': 'account-1',
        'settings': {
          'language': 'auto',
          'summary_language': 'en-US',
          'timezone': 'UTC',
        },
      };
    else if (path.endsWith('/transcriptions'))
      result = {
        'revision': 1,
        'segments': [
          {
            'id': 'segment-1',
            'text':
                'Let’s begin with the launch timeline. The recording flow should be ready for our next review.',
            'speaker': 'Speaker 1',
            'start_ms': 0,
            'end_ms': 12000,
          },
          {
            'id': 'segment-2',
            'text':
                'We will review onboarding and the export experience together.',
            'speaker': 'Speaker 2',
            'start_ms': 14000,
            'end_ms': 22000,
          },
        ],
      };
    else if (path.endsWith('/summaries'))
      result = {
        'items': [reviewSummary],
      };
    else if (path.startsWith('/api/v1/recordings?') ||
        path.startsWith('/api/v1/search'))
      result = {'items': reviewRecordings};
    else if (path.startsWith('/api/v1/recordings/'))
      result = reviewRecordings.first;
    else if (path.startsWith('/api/v1/folders'))
      result = {
        'items': [
          {
            'id': 'folder-1',
            'data': {'title': 'Research'},
          },
        ],
      };
    else if (path.startsWith('/api/v1/templates'))
      result = {
        'items': [
          {
            'id': 'template-1',
            'data': {
              'title': 'Meeting notes',
              'prompt': 'Summarize decisions, key points and next steps.',
            },
          },
        ],
      };
    else if (path.endsWith('/messages'))
      result = {
        'items': [
          {
            'id': 'message-1',
            'data': {
              'question': 'What did we decide for the launch?',
              'answer':
                  'The recording flow comes first. Onboarding and export will be reviewed together.',
              'grounded': true,
              'citations': [
                {'recording_id': 'record-1', 'start_ms': 0, 'end_ms': 12000},
              ],
            },
          },
        ],
      };
    else if (path == '/api/v1/chats/chat-1')
      result = {
        'id': 'chat-1',
        'data': {
          'title': 'Launch review',
          'recording_ids': ['record-1'],
        },
      };
    else if (path.startsWith('/api/v1/chats'))
      result = {
        'items': [
          {
            'id': 'chat-1',
            'data': {'title': 'Launch review'},
            'created_at': '2026-11-04T10:00:00Z',
          },
        ],
      };
    else if (path.startsWith('/api/v1/trash'))
      result = {
        'items': [reviewRecordings.last],
      };
    return jsonEncode(result);
  }
}

TenoModel reviewModel([FixtureHost? host]) {
  final native = host ?? FixtureHost();
  return TenoModel(host: native)
    ..changed(native.state)
    ..recordings = reviewRecordings
    ..folders = [
      {
        'id': 'folder-1',
        'data': {'title': 'Research'},
      },
    ];
}
