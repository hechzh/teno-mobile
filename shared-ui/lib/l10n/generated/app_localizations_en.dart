// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get home => 'Home';

  @override
  String get assistant => 'Assistant';

  @override
  String get settings => 'Settings';

  @override
  String get library => 'Library';

  @override
  String get interfaceLanguage => 'Interface language';

  @override
  String get followSystem => 'Follow system';

  @override
  String get languageHint =>
      'Changes interface text only. Recordings, notes and chats are not translated.';

  @override
  String get appearanceLanguage => 'Appearance & language';

  @override
  String get privacyData => 'Privacy & data';

  @override
  String get recorderRecording => 'Recorder & recording';

  @override
  String get brief => 'Brief';

  @override
  String get recentRecordings => 'Recent recordings';

  @override
  String get viewAll => 'View all';

  @override
  String get source => 'Source';

  @override
  String get notes => 'Notes';

  @override
  String get overview => 'Overview';

  @override
  String get search => 'Search';

  @override
  String get importFiles => 'Import files';

  @override
  String get startRecording => 'Start recording';

  @override
  String get myRecorder => 'My recorder';

  @override
  String get newNote => 'New note';

  @override
  String get versions => 'Versions';

  @override
  String get topics => 'Topics';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get done => 'Done';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading…';

  @override
  String get emptyBrief => 'Your latest saved note will appear here.';

  @override
  String get briefSource => 'From a saved note';

  @override
  String get noNotes => 'No saved notes yet';

  @override
  String get firstRecording => 'Start with something worth keeping.';

  @override
  String get firstRecordingHint =>
      'Import audio to keep its transcript, notes and sources together.';

  @override
  String get assistantTitle => 'A little clarity, from your recordings.';

  @override
  String get assistantHint =>
      'Answers from your recordings and notes, with source timestamps when available.';

  @override
  String get personalAccount => 'Personal account';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String briefVersion(String title, String version) {
    return 'From $title · v$version';
  }

  @override
  String topicCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count topics',
      one: '1 topic',
    );
    return '$_temp0';
  }

  @override
  String sourceCount(int count) {
    return '$count sources';
  }

  @override
  String get label7e1b0d5641f2 => 'Account';

  @override
  String get labelf521e4248c6d => 'Account & security';

  @override
  String get label6c4b5440e570 => 'Account changed. Open this recording again.';

  @override
  String get label8a7dfc4957be => 'Account changed. Reload this page.';

  @override
  String get label7874b13aeec1 =>
      'Add a recording, import a file or create a note.';

  @override
  String get label88f3f837facd => 'Add a title and instructions.';

  @override
  String get label0f01d14cacf0 => 'Add context';

  @override
  String get label57d208bc0d04 => 'Add event';

  @override
  String get label5f0580aa7e39 => 'Add highlight';

  @override
  String get label75d9b95a566f => 'Add subfolder';

  @override
  String get labela52ace420f21 => 'All';

  @override
  String get labelbffc49b558cf => 'All cloud recordings';

  @override
  String get label2c92a471fdfc => 'All recordings';

  @override
  String get labela4717b6543d6 => 'Any date';

  @override
  String get label772c230c059d => 'Anyone using this link will lose access.';

  @override
  String get labelb0d015fdadc3 => 'App lock';

  @override
  String get label1862f6ab9820 =>
      'Applies to your next recording. Complete audio is processed again after recording.';

  @override
  String get labela71379918f19 => 'Ask Teno';

  @override
  String get label717367d1bd24 => 'Ask a question about your recordings.';

  @override
  String get label440c2d0c3740 => 'Ask about this recording';

  @override
  String get label813bfccd9116 => 'Ask about your recordings';

  @override
  String get label844fb4bf3408 => 'Ask me anything about this recording';

  @override
  String get labeldb41f0c39aaf => 'Ask me anything about your recordings';

  @override
  String get label46b396c85919 => 'At a glance';

  @override
  String get label5e3176c01225 => 'AI-generated · Review key details';

  @override
  String get labelbc1b88907d3b => 'Audio';

  @override
  String get label00140e8ad0ea => 'Audio & transcript';

  @override
  String get label8d8e1aff4a6f =>
      'Audio and video · Up to 120 minutes / 250 MiB';

  @override
  String get labelfe629dea74ec => 'Audio could not be verified';

  @override
  String get label656fb6ded904 =>
      'Audio is kept while Teno prepares your notes.';

  @override
  String get label0be233af17d9 => 'Audio language';

  @override
  String get label419a6c580fbd => 'Audio settings';

  @override
  String get labeld461a493a375 => 'Automatic';

  @override
  String get label179fd3261edf => 'Automatic processing';

  @override
  String get label00b76f172d63 =>
      'Automatically upload new recordings and imports for transcription and summaries.';

  @override
  String get label6209c5481977 =>
      'Automatically upload saved audio for transcription and summary.';

  @override
  String get label48d57e9d4911 => 'Back 15 seconds';

  @override
  String get label008e42d22277 => 'Back to library';

  @override
  String get labeldfcb7c1619d5 => 'Battery';

  @override
  String get labeld83ab68f7428 => 'Best match';

  @override
  String get label0f82b87c1954 => 'Bring your JWD recorder closer';

  @override
  String get label359ca59af29e => 'Browser imports';

  @override
  String get label9bc6697e3dc9 =>
      'Browser imports stay under this account. Uploads in progress will stop; sign in again to retry.';

  @override
  String get label2456433596a1 => 'Cached previews and exports';

  @override
  String get labeld5d0a30b517e => 'Calendar';

  @override
  String get label84110d11d312 => 'Calendar actions';

  @override
  String get label0e826ce50ae6 => 'Capture important visuals';

  @override
  String get label292c06f0045a => 'Category';

  @override
  String get label9831375bc651 => 'Chapters';

  @override
  String get label460b3a7da007 => 'Chat';

  @override
  String get label05a05aa2fd48 => 'Chat history';

  @override
  String get label916702c8589f =>
      'Check answers against the linked source recordings.';

  @override
  String get label4e8780f8aa73 =>
      'Check important answers against the linked sources.';

  @override
  String get label473763cd02d9 => 'Checking recording service…';

  @override
  String get label8a9779f42128 => 'Chinese';

  @override
  String get label92181d4a51d4 => 'Choose a format';

  @override
  String get labelda0f63e19741 => 'Choose content';

  @override
  String get labela98b1d3e5ceb => 'Choose content to include';

  @override
  String get label343b5a9c7fd6 => 'Choose date';

  @override
  String get label79c6c7ad4ad7 => 'Choose dates';

  @override
  String get labelfc29d2cd66c0 =>
      'Choose up to 30 recordings with transcripts.';

  @override
  String get label108e4eec572c => 'Clean up transcript automatically';

  @override
  String get labeld00e4df0930c => 'Cleaned-up text is not available yet.';

  @override
  String get labeld33461e6c0b6 => 'Clear cache';

  @override
  String get label39041f7b9262 => 'Clear cached files?';

  @override
  String get label3b7ea51793e9 => 'Clear search';

  @override
  String get label95d460729621 => 'Clear search history';

  @override
  String get labeld8232cf4eb24 => 'Close keyboard';

  @override
  String get labela600b900f83d => 'Close panel';

  @override
  String get label2b7aa8894c21 => 'Cloud processing';

  @override
  String get label838991b2b94f =>
      'Cloud processing is off. Imported files stay on this phone until you choose Upload and process.';

  @override
  String get label8adaed39e1a2 =>
      'Cloud processing is on. Imported files are saved on this phone, then uploaded and processed automatically.';

  @override
  String get label2187c26af752 =>
      'Cloud processing starts on for accounts without a saved preference. An existing choice to turn it off is kept. Enable it in Settings → Cloud processing.';

  @override
  String get labela293e2e43fd2 => 'Compatibility scan';

  @override
  String get label7810980ade40 =>
      'Complete files are verified and saved locally before cloud upload. Reconnect to retry an interrupted transfer. Device originals are not automatically deleted.';

  @override
  String get label9d989f15c1c5 =>
      'Complete recordings and imports remain on this phone after upload. Keep the app installed to retain these local copies.';

  @override
  String get label060f79ce72a8 =>
      'Complete recordings and imports stay on this phone after upload. Existing saved files are uploaded only when you request it.';

  @override
  String get labelc8d900f3aeed =>
      'Complete recordings are automatically kept on this phone. Cloud upload never removes a local recording.';

  @override
  String get labeleebdd24a77d9 => 'Confirm';

  @override
  String get label5b27ed7fa9dd =>
      'Connect a JWD recorder, check its service, then authorize it with its device key. Keep the original key to connect from another phone.';

  @override
  String get labelac593f874557 => 'Connect a recorder';

  @override
  String get label40f9815ebd38 => 'Connect a recorder without signing in';

  @override
  String get label9e7eba0b97c9 => 'Connect phone calendar';

  @override
  String get label9639916d9dfb => 'Connect recorder';

  @override
  String get label1ca37334ccfa => 'Connect your recorder';

  @override
  String get label62d0bfa77e96 =>
      'Connect your recorder and keep its original device key. Reconnecting does not start a recording. A Bluetooth disconnect does not mean the recorder has stopped.';

  @override
  String get label8b53877af85c =>
      'Connect your recorder to capture your next conversation.';

  @override
  String get label47bd29075f8b => 'Content';

  @override
  String get label31fbef162594 => 'Continue';

  @override
  String get label37145972530b => 'Continued';

  @override
  String get labele21f935f11d7 => 'Copy';

  @override
  String get labelf81b58cb3b7c => 'Copy / Export';

  @override
  String get labeld888b94d692e => 'Copy note';

  @override
  String get labelb749e205302c => 'Copy to clipboard';

  @override
  String get labelfa8d84566676 => 'Cover';

  @override
  String get label4759498ac2a7 => 'Create';

  @override
  String get label4993a031ed5a => 'Create a link from a recording or note.';

  @override
  String get label6eb05a41f7e6 =>
      'Create a shareable link. Anyone with the link can access this file.';

  @override
  String get labele6b850cff6af => 'Create link';

  @override
  String get label7dc9c0adaca0 => 'Create template';

  @override
  String get labelf9182f6f2dc8 => 'Created by me';

  @override
  String get label26756b8c8a6e => 'Creating link…';

  @override
  String get labele0d1b68224bf => 'Current';

  @override
  String get label60acc53f13a5 => 'Dark';

  @override
  String get labelfa91f7628ea5 => 'Date created';

  @override
  String get label5b7e27d5a077 => 'Date created · newest';

  @override
  String get labelc4709b234134 => 'Date created · oldest';

  @override
  String get labeleb5e7a5e3d68 => 'Date modified';

  @override
  String get label45b575b18fb2 => 'Date modified · newest';

  @override
  String get label8061bfb29ce8 => 'Date range';

  @override
  String get label0372d70a4fd5 =>
      'Default configurations for language, speaker labels and transcript cleanup.';

  @override
  String get labeleb4dd2202ac2 => 'Default summary';

  @override
  String get labele2d0a54968ea => 'Delete';

  @override
  String get labelb872a42ed4cc => 'Delete event';

  @override
  String get label113be1f69f41 => 'Delete event?';

  @override
  String get label39f35f2d44d6 => 'Delete folder';

  @override
  String get label28b4629208db => 'Delete folder?';

  @override
  String get label6a6dd3ce6ae2 => 'Delete local copy';

  @override
  String get labelba9f45a1c2d6 => 'Delete local copy?';

  @override
  String get label280b10c89cc4 => 'Delete permanently';

  @override
  String get labelc1b15a371248 => 'Delete permanently?';

  @override
  String get labelda9a9b350675 => 'Delete template';

  @override
  String get labele1d84431b905 => 'Delete template?';

  @override
  String get labelc13e8743fff5 => 'Deleted cloud recordings will appear here.';

  @override
  String get label14f912855ddb => 'Device key backup';

  @override
  String get labelada711324c39 => 'Discard pending imports';

  @override
  String get labelacfc5be785a9 => 'Disconnect';

  @override
  String get labelb4e929d8bcfe => 'Documents';

  @override
  String get labele9ca7472dee6 => 'Drop into a folder';

  @override
  String get label464c4ffd019e => 'Edit';

  @override
  String get label4f97831c321a => 'Edit local notes';

  @override
  String get label299e604ccff3 => 'Edit note';

  @override
  String get label0e3eb67d72e9 => 'Edit segment';

  @override
  String get labelc04f3d9cb841 => 'Edit summary';

  @override
  String get label176a44212e88 => 'Edit title';

  @override
  String get label08d4e40d7c51 => 'Edit transcript';

  @override
  String get labela440abe23574 => 'Edited text';

  @override
  String get label74a1be251418 =>
      'Edits here update the local note. Notes sent with the original upload remain on the server.';

  @override
  String get labele9d41512971a => 'End of note';

  @override
  String get labelba118bf7fc9c => 'English';

  @override
  String get label258ad01aae4c =>
      'Enter start and end seconds separated by a comma.';

  @override
  String get label4e1f49a9c8ae => 'Event';

  @override
  String get label8ec4602ce4a2 => 'Event title';

  @override
  String get label74100229729d =>
      'Existing notes keep their generated content.';

  @override
  String get label83f51733c819 => 'Existing summaries will be preserved.';

  @override
  String get label3664895579f0 => 'Export';

  @override
  String get label6888c0a35c11 => 'Export & share';

  @override
  String get label1e74a176a3dd => 'Export as';

  @override
  String get labelcd6d4c5ea371 => 'Export audio';

  @override
  String get labelf066ead78e58 => 'Export note';

  @override
  String get labeld106178565fd => 'Export original';

  @override
  String get labelf6aee6b20fe9 => 'Export transcript';

  @override
  String get label6ab7f7d9e711 =>
      'Extracting text. The original file is saved.';

  @override
  String get labelac67507227ad => 'Favorite template';

  @override
  String get label7a1f2a83aca9 => 'Favorites';

  @override
  String get label50009ce1da4d => 'File';

  @override
  String get labelb163fad90bee => 'File options';

  @override
  String get labelb3b9efed9c4d => 'File unavailable';

  @override
  String get labelabc7e9892806 => 'Files';

  @override
  String get labeledfdb024f059 =>
      'Files are saved in this browser. Choose Upload and process to send them to your signed-in account. Keep this tab open until upload finishes.';

  @override
  String get labele5a5c0df54fc => 'Files remain in your library.';

  @override
  String get labeldead605b2f80 => 'Files selected for import appear here.';

  @override
  String get label822b2ae4542b => 'Find';

  @override
  String get labelf8c805bd6a45 => 'Find & replace';

  @override
  String get label7337c292a757 => 'Find a conversation';

  @override
  String get label4230011827fe => 'Find a file';

  @override
  String get labeld543a6e1672a => 'Find my recorder';

  @override
  String get labelb8a514901391 => 'Find the important details';

  @override
  String get label74ccd4330384 => 'Folder';

  @override
  String get labele37afba74564 => 'Folder options';

  @override
  String get labelc4d6bb200f4c => 'Folders';

  @override
  String get labeld383fef33b8f => 'Follow audio';

  @override
  String get label2ba88fa96208 =>
      'For a recorder already used with Teno, enter its original device key. A new key is only for an unbound recorder.';

  @override
  String get label2f343666aaa8 => 'Format';

  @override
  String get label19190cce5524 => 'Forward 15 seconds';

  @override
  String get label6754c0ab7f8f => 'From Files';

  @override
  String get label687c53cb1fb7 => 'From Photos';

  @override
  String get label5052681b30b0 => 'From other apps';

  @override
  String get labelc910d474dcd7 => 'General';

  @override
  String get label49e49bb4401e => 'Generate';

  @override
  String get label9414748cad34 => 'Generate cleaned-up text';

  @override
  String get labelab35d87baddf => 'Generate summary';

  @override
  String get label8c8afc5edbe9 => 'Generated content language';

  @override
  String get label40536dd8a0e2 => 'Generation';

  @override
  String get label467c73ec9baf => 'HTTPS server';

  @override
  String get label7a34ff85344e => 'Help & support';

  @override
  String get labele2f55c84f3b4 => 'Help center';

  @override
  String get label5cb5d4286696 => 'Hide other devices';

  @override
  String get label07ccd15df32a => 'Highlight';

  @override
  String get label6e517828c3d8 => 'Highlights';

  @override
  String get label66bc5802319d =>
      'Home → + → Import files. Choose From Files or From Photos. In another app, tap Share → Teno.';

  @override
  String get label59c2eaa21578 =>
      'Home → + → Import files. Choose a file, then Upload and process. Keep this tab open until upload finishes. Processing then continues on the server.';

  @override
  String get labelb9e9d6be1bcf => 'How can I help you today?';

  @override
  String get labela8bb3b086be4 =>
      'Images · 20 MB    Documents · 15 MB    Text · 2 MB';

  @override
  String get label2cff9baabf56 => 'Import';

  @override
  String get labeldb5f9fda6639 => 'Import a file to create your first note.';

  @override
  String get label5f25f9f40b7a => 'Import and process';

  @override
  String get label03c4ac096cd8 => 'Import calendar file';

  @override
  String get label6f190ac40487 => 'Import limits';

  @override
  String get label321f179c80ba => 'Imported';

  @override
  String get label7df60b64e7ef => 'Imports';

  @override
  String get label81d985062c52 => 'In this browser';

  @override
  String get label4effe447355c => 'Interview';

  @override
  String get label4c2f6b585573 =>
      'JSON includes the complete structured content and source references.';

  @override
  String get label746d2d32f63b => 'JWD candidate · Tap to verify and connect';

  @override
  String get label1cef75aa83ee =>
      'Keep your original file. Browser storage may be cleared or evicted.';

  @override
  String get labelc925a0fbcc77 => 'Key points';

  @override
  String get labelcdfa2a966fc3 => 'Key points · One per line';

  @override
  String get label8c710d7b2497 =>
      'Language detection is automatic for recordings and imports.';

  @override
  String get label8b45bb20e077 => 'Learning';

  @override
  String get labeld7cd25137fff => 'Library options';

  @override
  String get labeldbcd5e7bb7a0 => 'Light';

  @override
  String get label60ec2d7bb78f => 'Link calendar event';

  @override
  String get label5a55f779d975 => 'Link expires after';

  @override
  String get label3d72409411ac => 'Live preview is off · Settings > Recorder';

  @override
  String get label868345e0521a =>
      'Live text is a preview. The complete recording is processed after it is saved and uploaded.';

  @override
  String get labeld17c23100fda =>
      'Live text is a preview. The complete recording is processed after recording for the final transcript and summary.';

  @override
  String get label20611c3780d1 => 'Live transcript';

  @override
  String get label7adfd01e422a => 'Live transcript preview';

  @override
  String get labelac8991ef0101 => 'Load more';

  @override
  String get label267c8973271e => 'Local copies';

  @override
  String get labelf6ecab810535 => 'Local file';

  @override
  String get labelbdb955a9c88d =>
      'Local files and recorder keys remain on this phone under their original account.';

  @override
  String get labelb7d2bf6f1057 => 'Local recording';

  @override
  String get label622410bb0aa1 => 'Local recording notes';

  @override
  String get label3e2b34b888f3 => 'Local recordings';

  @override
  String get label49dc52ab360e =>
      'Local recordings and device keys stay on this phone. Sign in to the same account to access its files again.';

  @override
  String get labeld62f03d8ff00 => 'Local storage';

  @override
  String get label029757c8ca0d => 'MEETING NOTES';

  @override
  String get labelf3060ca2421f => 'Manage local files';

  @override
  String get labelff862e135e82 => 'Mark key moments';

  @override
  String get label0e52f6b9d025 => 'Markdown';

  @override
  String get label4c857c545b8a => 'Matching recorders';

  @override
  String get label8b8b8871bbfb => 'Meeting';

  @override
  String get label9e6c24f51918 => 'Meeting notes';

  @override
  String get label8851aaa7d08c => 'Merge';

  @override
  String get labelc8627d844f1f => 'Merged recording';

  @override
  String get label56112ca16c30 => 'Merged recording title';

  @override
  String get label6ecc3df6bffd => 'Move';

  @override
  String get labelbd0b474a3bd3 =>
      'Move a recording into this folder from its options menu.';

  @override
  String get label91d631e150a3 => 'Move to folder';

  @override
  String get labelb250a454877d => 'Move to trash';

  @override
  String get label6d090914f6d7 => 'Move to trash?';

  @override
  String get label985698b7b5c4 => 'My files';

  @override
  String get label5030ec983702 => 'My files views';

  @override
  String get label1901b64190f9 => 'My templates';

  @override
  String get label7bfab6c61f77 => 'NOTES';

  @override
  String get labeldcd1d5223f73 => 'Name';

  @override
  String get labeled245bd55dfb =>
      'Name a speaker in a transcript to filter recordings.';

  @override
  String get labele9e7f40a9bdd => 'Name speakers';

  @override
  String get label561e624aff7c => 'Name speakers within each recording.';

  @override
  String get label3db65f8c2a7d => 'Navigation';

  @override
  String get labeldb18382a249e => 'New chat';

  @override
  String get labelcf28f49ec597 => 'New folder';

  @override
  String get labelbfc1adc316f2 => 'New folder or note';

  @override
  String get label1f054525307b => 'New subfolder';

  @override
  String get labela6c731830aa4 => 'New summary note';

  @override
  String get label30d87ec45259 => 'New template';

  @override
  String get label079c45af4c2e => 'New unbound recorder';

  @override
  String get labeldd00d3d3e9f7 => 'Next steps';

  @override
  String get label5a97dc7c7d1d => 'No chat history';

  @override
  String get labeld7e20271831b => 'No files here';

  @override
  String get labeldc628c03998f => 'No local files';

  @override
  String get label77161f8e007e => 'No local recordings';

  @override
  String get labeleb82569d8230 => 'No matches found.';

  @override
  String get labelaf10422f854c => 'No notes added.';

  @override
  String get label5e2f7f4186ca => 'No options yet.';

  @override
  String get label033f5cf82455 => 'No recordings here';

  @override
  String get labela43619f32117 => 'No results';

  @override
  String get label46d5c181199b => 'No saved versions';

  @override
  String get labelb346b410d2d9 => 'No shared links';

  @override
  String get labeledc4df618f81 =>
      'No speaker labels are available for this transcript.';

  @override
  String get label330456ef9c44 => 'No speech recognized';

  @override
  String get label506bbb53d801 => 'No templates here';

  @override
  String get labelff785ccc115e => 'No upcoming events';

  @override
  String get label6cfd09061b65 =>
      'No verifiable source was included. Check this answer against your recordings.';

  @override
  String get labeld8da2c49df39 => 'Note';

  @override
  String get label92bb2996b9b2 => 'Note copied';

  @override
  String get labele20e2be082f2 => 'Note options';

  @override
  String get label788011833a5a => 'Notifications';

  @override
  String get label5e97833a594a =>
      'Notify me when processing finishes. Requires Android notification permission.';

  @override
  String get labelf97da48734b6 => 'On this phone';

  @override
  String get label842fc3a912a6 => 'Open audio player';

  @override
  String get label4190c0c7ec72 => 'Open file';

  @override
  String get labelfb799b7fc5ce => 'Open note · Edit and versions';

  @override
  String get label44a915faf3a9 => 'Open original';

  @override
  String get label6e00f5d853ef => 'Open recording';

  @override
  String get label3e74fe245f58 => 'Open result';

  @override
  String get labeldca1f6c209a2 =>
      'Open the file in another app, tap Share, then choose Teno.';

  @override
  String get labelbb09a1532cc1 => 'Original 16-character key';

  @override
  String get labelee9869fcea57 =>
      'Original local recordings, device keys and cloud files stay available.';

  @override
  String get label89420fdb493e => 'Original text';

  @override
  String get label0a30a815d67d => 'Page';

  @override
  String get labele7cf3ef4f17c => 'Password';

  @override
  String get label858e4ba7a29f => 'Pause';

  @override
  String get labelbb6591385f67 => 'Pause recording';

  @override
  String get label02457c055802 => 'Pause transfer';

  @override
  String get labelf4e08fefef74 => 'Personalization';

  @override
  String get labela7c41425ec04 =>
      'Phone recordings: up to 54 minutes. JWD Bluetooth imports: up to 60 minutes / 100 MiB. Audio file imports: up to 120 minutes / 250 MiB.';

  @override
  String get labeld84eebada93e => 'Photo';

  @override
  String get label5e3147ab51e0 => 'Photos';

  @override
  String get labelcf4166250b80 => 'Plain text';

  @override
  String get labela78afaff2fda => 'Play or pause';

  @override
  String get label12c3d3a920ad => 'Play or pause audio';

  @override
  String get label67e0ddff71f2 => 'Play recording';

  @override
  String get labelafec2b22114c => 'Playback speed';

  @override
  String get label66962f72a088 => 'Preferences';

  @override
  String get labelf1af44ed881d => 'Preparing transcript and summary';

  @override
  String get label1802b08513b6 => 'Preparing your answer…';

  @override
  String get label20581eb94b5f => 'Preparing your note';

  @override
  String get label0f454c73915f => 'Preparing your summary';

  @override
  String get labelb44a7fc5628d => 'Preparing your transcript';

  @override
  String get label37c43ad41939 =>
      'Preview only. The complete audio is processed after recording.';

  @override
  String get label23333fe2d3d9 =>
      'Preview · Final transcript follows processing';

  @override
  String get label9348f5af2c55 =>
      'Previous versions and existing next steps are preserved.';

  @override
  String get labelc63eb6720c6e => 'Private';

  @override
  String get labelc8e3e92a62ec => 'Processing';

  @override
  String get labela9e3bc208a09 => 'Processing and notifications';

  @override
  String get label63e7cb980e55 => 'Processing failed. Try again.';

  @override
  String get labeld5fe69b8a1f3 => 'Processing notifications';

  @override
  String get label35b901546886 => 'Processing your recording';

  @override
  String get label75767813e884 => 'Queued for upload';

  @override
  String get label5fa7aac5375c => 'Ready';

  @override
  String get label451a35b8adb3 => 'Ready to summarize';

  @override
  String get label7f2d46393e85 => 'Recap the key decisions';

  @override
  String get labele0050e57eb70 =>
      'Receiving and verifying the complete recording. Originals stay on your recorder.';

  @override
  String get label2ccfecbca101 => 'Recent chats';

  @override
  String get label228c84b5a56e => 'Recent searches';

  @override
  String get label1e7cf8df9b6a => 'Recently used';

  @override
  String get labelf7b07c386b9c => 'Reconnect recorder';

  @override
  String get label8343f2a64a3a => 'Reconnect saved recorder';

  @override
  String get label3941c85fa102 =>
      'Reconnecting does not start a recording. If Bluetooth disconnects, check the recorder before starting another recording.';

  @override
  String get labela571db058621 => 'Record with phone';

  @override
  String get labelb984d066f603 => 'Recorder';

  @override
  String get labelb41c60449af7 => 'Recorder & files';

  @override
  String get label80e8dd1a5a05 => 'Recording';

  @override
  String get labelae19bed1f3b2 => 'Recording highlights';

  @override
  String get labelaeb3eba8a655 => 'Recording notes';

  @override
  String get label024bd21625b8 => 'Recording options';

  @override
  String get labele7a814fbebf5 => 'Recording preferences';

  @override
  String get label65ac0c306d33 => 'Recording service unavailable';

  @override
  String get labela858dbd960d1 => 'Recording service verified · Connect';

  @override
  String get labelcf4a89857ca6 => 'Recording title';

  @override
  String get label2ef4c842e6e8 => 'Recording unavailable';

  @override
  String get labelfd24f4315ebf => 'Recording with Teno';

  @override
  String get label60c56d66a128 => 'Recordings';

  @override
  String get label5ca7933473f1 =>
      'Recordings and imports are automatically kept on this phone.';

  @override
  String get labelace48a7cb5b4 => 'Recordings will stay in your library.';

  @override
  String get label889bdee49e27 => 'Refresh conversation';

  @override
  String get label45b14a89f746 => 'Refresh device status';

  @override
  String get label1651031bf58d => 'Regenerate';

  @override
  String get label3064d79a295c => 'Rename';

  @override
  String get label7249f19c9e4f => 'Rename folder';

  @override
  String get label2ebcba962562 => 'Replace all';

  @override
  String get label8382d317c1d5 => 'Replace with';

  @override
  String get labela76e13b98392 => 'Restore';

  @override
  String get labeld640c7421da0 => 'Resume';

  @override
  String get label5939333e89a8 => 'Retry processing';

  @override
  String get labelc87dc5bbfea5 => 'Return to recording';

  @override
  String get label87e6d00bbf53 => 'Revoke';

  @override
  String get label3d3b295854fe => 'Revoke this link?';

  @override
  String get labelf6f738d04392 => 'Revoked';

  @override
  String get label55559604fc68 =>
      'Save a favorite, create a template or choose another category.';

  @override
  String get label4f4851e2cdef => 'Save as note';

  @override
  String get label6d3f818d9f6a => 'Save favorites or create your own.';

  @override
  String get label20334a86c75a => 'Save new version';

  @override
  String get label59bfdd6b2306 =>
      'Save or share through your phone’s share menu.';

  @override
  String get label47f72a2f3e91 => 'Save template';

  @override
  String get label7ae75ed463cf => 'Saved copy · Checking for updates…';

  @override
  String get labelc9603da9e5ad => 'Saved copy · Could not check for updates';

  @override
  String get label75010cd58573 => 'Saved in this browser';

  @override
  String get label4c03b51d6368 => 'Saved on this phone';

  @override
  String get label951db04b82b5 => 'Saved recorder · Connect';

  @override
  String get labelf15ef1a2514d => 'Saving recording';

  @override
  String get labelcbe16e470ef0 => 'Saving to this phone';

  @override
  String get label23e39291d613 => 'Saving…';

  @override
  String get label38d96da6e8b2 => 'Scanning…';

  @override
  String get label04b9835b977e => 'Search templates';

  @override
  String get label0ca59a709d65 => 'Search titles and transcripts.';

  @override
  String get label088f0ac49c96 => 'Search your recordings';

  @override
  String get label2a78025de6aa => 'Select';

  @override
  String get labeld1156d07ca4e => 'Select a template';

  @override
  String get labelb43ba3e02667 => 'Select recordings to merge.';

  @override
  String get labelf9086318ef13 =>
      'Select recordings, notes, documents or folders.';

  @override
  String get labelec075128ebd3 => 'Send question';

  @override
  String get label485ad1a4f6b7 => 'Separate speakers';

  @override
  String get labelaef7de28d529 => 'Server';

  @override
  String get label3e8fb11efc9e => 'Server settings';

  @override
  String get label29887a5ff984 => 'Share';

  @override
  String get label63ff62289eca => 'Share answer';

  @override
  String get label712a4823ccb9 => 'Share link';

  @override
  String get labelf40b09a5b798 => 'Share recording';

  @override
  String get label44266fb49f67 => 'Share with link';

  @override
  String get labele3c4b39d6d50 => 'Shared';

  @override
  String get label2e3ac056d490 => 'Shared links';

  @override
  String get label3dcf3d16dd02 => 'Shared with Teno';

  @override
  String get labelbfd402b2f6f3 => 'Sign in';

  @override
  String get label22e58a62e3f4 =>
      'Sign in to its account or check local storage.';

  @override
  String get labelc80526e65f78 => 'Sign in to record';

  @override
  String get label11aa3c02e39a =>
      'Sign in to the recording’s account to access its local file.';

  @override
  String get label47e82476c5c4 => 'Sign in to your Teno account.';

  @override
  String get label48f0d3d397d4 => 'Sign out';

  @override
  String get labelc1c084addfcc => 'Sign out?';

  @override
  String get label8b9d3de8ae00 => 'Signing in…';

  @override
  String get label722173bdafb0 => 'Sort and select';

  @override
  String get label75b95987156e => 'Sort search results';

  @override
  String get labelcaf85b0888d7 => 'Sources';

  @override
  String get labela9e0c7058512 => 'Speaker';

  @override
  String get label6d2a3d905d65 => 'Speaker labels';

  @override
  String get labelc92a7237efe6 => 'Speakers';

  @override
  String get label278f200e0954 => 'Start a conversation about your files.';

  @override
  String get labelcae7d57bc067 => 'Stop';

  @override
  String get labelcfa16e25a1b7 => 'Stop following audio';

  @override
  String get label576b015da398 => 'Stop recording?';

  @override
  String get label1ff87776e254 => 'Stop upload';

  @override
  String get labela69c4dece144 => 'Storage';

  @override
  String get label87b46d07344a => 'Summarize the key decisions';

  @override
  String get label8e76a94ac832 => 'Summary';

  @override
  String get label897f93c2a3b8 => 'Summary instructions';

  @override
  String get label69427a25853c => 'Summary language';

  @override
  String get label7530b89a4c88 => 'Summary template';

  @override
  String get label062bcea801e1 => 'Summary unavailable';

  @override
  String get label0d681ad655bb => 'Summary versions';

  @override
  String get labele2d55694b6a7 => 'Supported files';

  @override
  String get label16d7372e3162 =>
      'Switch to Edited text to make changes. The original stays unchanged.';

  @override
  String get label5f905992d185 => 'Sync recordings to this phone';

  @override
  String get label7b905ed0eaf2 => 'Template name';

  @override
  String get label1ad5d815ceef => 'Template options';

  @override
  String get label56b564b75c7f => 'Templates';

  @override
  String get label1e43824cfa40 => 'Teno Web preview';

  @override
  String get label971dc8d18395 => 'Teno account';

  @override
  String get label2504d9c7417d =>
      'The action could not be completed. Try again.';

  @override
  String get label0852dd932048 => 'The answer could not be generated.';

  @override
  String get label1074f8d0c278 =>
      'The cloud content will stay in your library.';

  @override
  String get labelef525ba5f521 =>
      'The cloud recording will stay in your library.';

  @override
  String get labelc15e0ed239f9 =>
      'The complete audio file stays on this phone.';

  @override
  String get label9fedf65e0ac5 =>
      'The complete audio remains available to play.';

  @override
  String get labelbc9c04e2af0b =>
      'The complete file is checked before it is saved and uploaded. Originals stay on your recorder.';

  @override
  String get labeld87528954e3a =>
      'The complete recording will be saved on this phone. Your cloud processing preference will apply.';

  @override
  String get label8f16804b7f33 => 'The current note is available on this page.';

  @override
  String get label5a6ad55a1421 =>
      'The source transcript has changed. This note retains its earlier version.';

  @override
  String get label785bd7747acd =>
      'The transcript has changed since this summary was generated.';

  @override
  String get labelf033a57053af =>
      'The transcript has changed. This note retains its earlier version.';

  @override
  String get labelefb52e7172b7 => 'Theme';

  @override
  String get label281a1ea9ebc2 =>
      'This answer is taking longer. Refresh this conversation to check again.';

  @override
  String get label663517e589cf =>
      'This file has not been uploaded. Its local copy will be permanently deleted.';

  @override
  String get labelc29cd21b0ce4 =>
      'This permanently deletes the cloud recording and its results.';

  @override
  String get label3c12c196ecfa =>
      'This recording has not been uploaded. Its local audio will be permanently deleted.';

  @override
  String get labeld5f64f34a299 => 'This recording is no longer available.';

  @override
  String get labelb519667d4c17 =>
      'This removes the event from Teno. Your phone calendar is unchanged.';

  @override
  String get labelec2d8412977b =>
      'This removes the selected cloud content and its shared links. Local copies stay on this phone.';

  @override
  String get label755f099dbf49 => 'Timestamps';

  @override
  String get label7e8cd2056da7 => 'Title';

  @override
  String get label2b065c7c9ce4 => 'Today';

  @override
  String get labelea93d6a262ec => 'Tools';

  @override
  String get labelfe69a43d8568 => 'Transcribe again';

  @override
  String get label9ee39146dee1 => 'Transcribe again?';

  @override
  String get label721164f0dc70 => 'Transcript';

  @override
  String get label4a2f872776b1 => 'Transcript actions';

  @override
  String get label2eeff6f159ed => 'Transcript excerpt';

  @override
  String get label441836b87229 => 'Transcript is being prepared';

  @override
  String get labelc304d04ca0b6 => 'Transcript version';

  @override
  String get label8bc7ce62eec1 => 'Transcription & summary';

  @override
  String get labelc560122ac470 => 'Trash';

  @override
  String get label52a78027bdd9 => 'Trash is empty';

  @override
  String get labelaa877d97e3f2 => 'Trim audio';

  @override
  String get labele38240ff7d06 => 'Trim range · start,end in seconds';

  @override
  String get labele54a1a0afd40 => 'Try a different word or phrase.';

  @override
  String get labelb4084a52d9d2 => 'Try another word or adjust your filters.';

  @override
  String get labelbaaddf70fb5d => 'Type';

  @override
  String get label849a11b7a0fb => 'Type main ideas';

  @override
  String get label63e39c39bfbb => 'Type note';

  @override
  String get label325ffdb1396d =>
      'Unrecognized device · Check recording service';

  @override
  String get labelf59ab8d1331b => 'Untitled';

  @override
  String get labele93736573a33 => 'Untitled note';

  @override
  String get label567fb2d64a3d => 'Untitled recording';

  @override
  String get labelc26ea11155cf => 'Upload and process';

  @override
  String get labelaedad2135947 => 'Upload needs attention';

  @override
  String get label3c414b7123b8 => 'Upload on Wi-Fi only';

  @override
  String get labeld541bdf9758b => 'Upload saved files';

  @override
  String get label8b898ca34ce7 => 'Uploading';

  @override
  String get label65189a29b993 =>
      'Uploading. Keep this tab open until upload finishes.';

  @override
  String get labelb16a23ba57f3 => 'Use original key';

  @override
  String get label82dbedf99ae9 =>
      'Use the menu to connect your calendar or add an event.';

  @override
  String get label1a439ee577c7 => 'Use this template';

  @override
  String get label467e685ec21a =>
      'Use your existing Teno account. Library, transcripts, summaries, templates and Ask share the same cloud data as the app.';

  @override
  String get labeleb4b0ba0995a => 'Use your phone’s screen lock to open Teno.';

  @override
  String get labele3b89e9d33f8 => 'Username';

  @override
  String get labeldd167905de0d => 'Version';

  @override
  String get labela6df11e706c5 => 'Version history';

  @override
  String get label6ee818aa2de3 => 'View source';

  @override
  String get label8748f23993a8 => 'Voice input';

  @override
  String get label9e320fd47505 => 'Waiting for recorder';

  @override
  String get labelcf7ca0c9fd5d => 'Waiting to upload';

  @override
  String get labelcaf8ca93250b => 'What are the next steps?';

  @override
  String get labelee3986c25932 => 'What should I follow up on?';

  @override
  String get label7b3091d59ac7 => 'What would you like to know?';

  @override
  String get label87bb59ba2f92 => 'Workspace';

  @override
  String get label28fbf97242b1 => 'Write your note…';

  @override
  String get labelfe1bb9b9b4d7 =>
      'You can leave this page while processing continues.';

  @override
  String get label42dcdde2fdda =>
      'You can leave this page. Processing continues in the background.';

  @override
  String get label69a45f93d227 =>
      'You can restore this cloud recording from Trash.';

  @override
  String get label99bff501c410 => 'You can restore this recording from Trash.';

  @override
  String get label11ae56a716fc => 'Your audio remains available.';

  @override
  String get labelf20283e2f772 => 'Your brief';

  @override
  String get label066bb7662174 =>
      'Your brief will appear here when a note is ready.';

  @override
  String get labelaa9ebfad71c7 => 'Your existing Teno account';

  @override
  String get label55576676783c => 'Your notes';

  @override
  String get label2fb2d67edf83 => 'Your question is saved. Retry when ready.';

  @override
  String get label5b8980b8296a => 'Your recorder';

  @override
  String get labelc390405502f1 =>
      'Your recordings and imports are automatically kept here.';

  @override
  String get labelae0ea9dc7f8c => 'Your recordings start here';

  @override
  String get labelbc183962239b => 'Your templates';

  @override
  String get label0ad1dcc94259 =>
      'A complete audio file is always kept on this phone. These choices are saved to this account on this device.';

  @override
  String get label200d05914172 =>
      'Android may delay background uploads and completion notifications. Reopen Teno to resume app work. Live text is a preview; final results use the complete recording.';

  @override
  String get label5098dcb4379e =>
      'Audio and video: 120 minutes / 250 MiB. Images: 20 MB. Documents: 15 MB. Text: 2 MB. Calendar files: 1 MiB. Use unencrypted documents.';

  @override
  String get label738e03c827d3 =>
      'Audio/video: 120 minutes / 250 MiB. Images (PNG/JPEG): 20 MB. Documents (PDF, Word, PowerPoint, MSG): 15 MB. Text/Markdown: 2 MB. Use unencrypted documents.';

  @override
  String get label938be793bada =>
      'Selected files are saved in this browser for retry under their original account. Browser storage can be cleared or evicted; keep your original files. Sign in again to resume an interrupted upload.';

  @override
  String get labelc85f64f70b34 => 'Overview, key points and next steps';

  @override
  String get labelc4e33bbe61e6 =>
      'Change interface language without changing your recordings or generated content.';

  @override
  String get label15f98a3794f0 => 'Your conversations,\nyour clarity.';

  @override
  String get labelf40d7f51f69e => 'Mon';

  @override
  String get labeld1eb39b09bf5 => 'Tue';

  @override
  String get label58339f45df96 => 'Wed';

  @override
  String get label7da11212ed34 => 'Thu';

  @override
  String get label66dab40cea1d => 'Fri';

  @override
  String get labelfdeb71b569e0 => 'Sat';

  @override
  String get labeldb18f17fe532 => 'Sun';

  @override
  String get label5c5db120cb11 => 'Jan';

  @override
  String get labelcaf71b3f582d => 'Feb';

  @override
  String get labelb4b7d3818dbf => 'Mar';

  @override
  String get label617531b4fec3 => 'Apr';

  @override
  String get label8c78fe5b9936 => 'May';

  @override
  String get labelb27fd46ed1b6 => 'Jun';

  @override
  String get labelc43f56b9807e => 'Jul';

  @override
  String get label41e1d82aa990 => 'Aug';

  @override
  String get label451e2b719061 => 'Sep';

  @override
  String get label6877e8494c3a => 'Oct';

  @override
  String get label3e630d2964a0 => 'Nov';

  @override
  String get labelf2a0cfbcf191 => 'Dec';

  @override
  String get labeld98eb49ceb4b => 'Teno · Saving recording';

  @override
  String get label71469cab82c6 => 'Teno · Recording paused';

  @override
  String get label331d2129ed6b => 'Teno · Recording';

  @override
  String get label145ee0765c43 => 'Audio is saved on this phone.';

  @override
  String get label6be804aeece9 => 'Stop and save';

  @override
  String get label57bb71e63419 => 'Uploads and processing';

  @override
  String get label4d1e89c3f939 => 'Recorder connection';

  @override
  String get label1fe47a729aaf => 'Teno · Recorder';

  @override
  String get labelc2bc6d5282a7 => 'Teno · Syncing recordings';

  @override
  String get labeld14b24f9ebe0 => 'Teno · Reminder';

  @override
  String get label3701e28787a3 => 'Speak your question';

  @override
  String get label24cd990fcc96 =>
      'Up to 60 seconds. You can edit the text before sending.';

  @override
  String get label3cfcdc5d210b => 'Export from Teno';

  @override
  String get label8ab78c95bb63 => 'Share from Teno';

  @override
  String get label60baea44888e => 'Processing · Local copy kept';

  @override
  String get labelf79ec89e7d95 => 'Upload paused · Local copy kept';

  @override
  String get label0303e1824670 => 'Not connected';

  @override
  String get label0b4bb3eed1bb => 'Not received';

  @override
  String get label9c1f7ff256de => 'Recorder service';

  @override
  String get labelb18237558cf3 => 'Recorder is recording';

  @override
  String get labela4348acc6d9c => 'Recording paused';

  @override
  String get label02acf8170c9a => 'Receiving audio over Bluetooth';

  @override
  String get label570d8b1483dd => 'Saved on recorder · Syncing to this phone';

  @override
  String get label944daea70213 => 'Waiting for the recorder to finish saving…';

  @override
  String get labelb18eeb0d43f6 => 'Compatibility scan · 15 seconds';

  @override
  String get labele2d7f6d7f18b =>
      'Scanning · Keep the recorder available for connection';

  @override
  String get label15fd3168e6c2 =>
      'No recorder found. Wake the recorder and close other recorder apps, then try again.';

  @override
  String get labelabad6f3dc147 =>
      'Scan complete. Verify the service before connecting.';

  @override
  String get label196574e3aa9c =>
      'Disconnected. Check the recorder: it may still be recording.';

  @override
  String get labela610dc54b358 =>
      'Sync paused. Originals stay on the recorder. Reconnect to try again.';

  @override
  String get labeleec2b22a86dc =>
      'Device key not accepted. Enter the original 16-character key, or check Recorder help before resetting the device.';

  @override
  String get label0cc1ba39d071 =>
      'Saved on recorder. Sign in and set recording preferences to sync automatically.';

  @override
  String get labelcf2759aff016 =>
      'Permission was not granted. Enable it in Android Settings to use this feature.';

  @override
  String get labelfc25221a1fc1 =>
      'Finish the current permission request first.';

  @override
  String get labelca44e25205d6 =>
      'Allow microphone access in Android Settings.';

  @override
  String get label533f1648108c => 'No audio received from recorder';

  @override
  String get label2a0b3310ed0f => 'Live preview is off';

  @override
  String get labeld403c686f6a1 => 'Connecting';

  @override
  String get label22965568d22a => 'Connected';

  @override
  String get label04dfac3671b4 => 'Disconnected';

  @override
  String get label7971dd752669 => 'Reminders';

  @override
  String get fullMeetingNotes => 'Full meeting notes';

  @override
  String fullNoteVersion(String version) {
    return 'Full note · v$version';
  }

  @override
  String get label548dc526803d => 'Scan for recorders';

  @override
  String get label2d56922b543d => 'Any folder';

  @override
  String get labelb05fc1fe6984 => 'Any type';

  @override
  String get label73843394f5ee => 'Any speaker';

  @override
  String get label0951734d8ac4 => 'Cleaned-up text';

  @override
  String otherDeviceCount(int count) {
    return 'Other Bluetooth devices ($count)';
  }

  @override
  String get label7dcd94452308 =>
      'A fixed version is shared. Revoke links in Settings → Shared links.';

  @override
  String get label401584c4ad5b => 'Copy transcript';

  @override
  String get labele58a1a86879f => 'Export files';

  @override
  String get label758ba0c08150 => 'Transcript copied';

  @override
  String get label8876eaf42b3b =>
      'Open the existing transcript without generating a new note.';

  @override
  String dayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get label0c00c2a6d16e =>
      'A complete copy stays on this phone after upload.';

  @override
  String get labelc8e9021fd812 =>
      'A new transcript version will be generated from the complete audio.';

  @override
  String get label1118a899f7f2 => 'Teno device key';

  @override
  String get label86f468a6b1d9 =>
      'Unlock to view your recorder\'s binding key.';

  @override
  String get labeled7d0390e6c9 =>
      'Keep this key private. It is needed to connect this recorder from another phone.';

  @override
  String get label20bb8fece4b5 => 'Share Teno notes';

  @override
  String get labeldde65e3126c3 =>
      'Check the recorder service before saving a device key.';

  @override
  String get labelbcf0cd2bc357 =>
      'Finish recording and transfers before changing accounts.';

  @override
  String get labelb8d5ef9344ff => 'Finish the current recording first.';

  @override
  String get label1f45e77f2c0c => 'Finish the phone recording first.';

  @override
  String get labelc43a281ad04f => 'Invalid local recording.';

  @override
  String get labelfc576d907ff7 =>
      'Recording could not start. Open the app and try again.';

  @override
  String get label2bd2ab92015b => 'Recording notes are too long.';

  @override
  String get labelaf8da0a68f14 => 'Sign in to this recording\'s account.';

  @override
  String get label7fe5b32b587a => 'Sign in to your Teno account first.';

  @override
  String get label2d211ecaebe2 => 'Sign out before changing accounts.';

  @override
  String get labelc161ed9c9526 => 'There is no active phone recording.';

  @override
  String get label7afc8612d3d2 => 'This recorder already has a saved key.';

  @override
  String get label27d81c15395f => 'Unsupported API request.';

  @override
  String get label6dd96f6320f1 =>
      'Wait for the active recording or upload to finish.';

  @override
  String get label268703d4af88 => 'Account changed. Import the file again.';

  @override
  String get labelaf4e0f09019e => 'Account changed. Open the export again.';

  @override
  String get label2ddae4d82d4c => 'Choose playable audio up to 120 minutes.';

  @override
  String get label1a0c74b79fc2 => 'Finish the current device key request.';

  @override
  String get label2395f9d173b3 => 'Finish the current import first.';

  @override
  String get label419205d06a9d => 'Invalid recording.';

  @override
  String get labele5a17d74835d => 'No device key is saved.';

  @override
  String get label6452bb49b9fd => 'Playback request changed.';

  @override
  String get label1d00f99f5e44 => 'Screen-lock verification is unavailable.';

  @override
  String get label5fdfb782b25b =>
      'Set a phone screen lock before viewing a device key.';

  @override
  String get label6977460770a2 =>
      'Supported formats: WAV, MP3, M4A, MP4 and OGG.';

  @override
  String get label65d0add78333 => 'The import limit is 250 MiB.';

  @override
  String get label686dfdbc0bd6 => 'The selected file is unavailable.';

  @override
  String get label4eabe69bda69 => 'This audio could not be played.';

  @override
  String get labela9b9f6f9c8bb => 'Unsupported export.';

  @override
  String get label1ac024f120c6 => 'Unsupported playback speed.';

  @override
  String get labeld642f9d8fbbd => 'Account changed during export.';

  @override
  String get labela69f32f2be19 => 'Account changed during import.';

  @override
  String get labelaf589e0ed460 => 'Account changed during voice input.';

  @override
  String get label82cab6a7cf93 => 'Choose a file shared with read permission.';

  @override
  String get label4780fd8ca280 =>
      'Choose a supported audio, video, document or image file.';

  @override
  String get label69f231493a92 => 'Choose a valid image up to 25 megapixels.';

  @override
  String get labeldfd6f617b710 => 'Choose audio or video up to 120 minutes.';

  @override
  String get label78bf8ff7bab7 =>
      'Finish phone recording before using voice input.';

  @override
  String get labele10607ef7236 => 'Import up to 20 files at a time.';

  @override
  String get labelfaedf3084288 => 'Invalid export request.';

  @override
  String get label412eadfa55af => 'Invalid pending import.';

  @override
  String get label3249da300236 =>
      'Set a screen lock in Android Settings before enabling App lock.';

  @override
  String get labeld0bc2276463c => 'Share up to 20 files at a time.';

  @override
  String get labelcdbfee510021 =>
      'The local copy is missing. Import the file again.';

  @override
  String get label42eb27c3baf6 => 'The selected file is empty.';

  @override
  String get label6578f2c3deff => 'The shared file is unavailable.';

  @override
  String get label3eee87dc352b => 'The shared item does not contain a file.';

  @override
  String get label31efa9c0d5f1 => 'This file exceeds the import size limit.';

  @override
  String get label3a5ad967765d => 'This file has no supported audio track.';

  @override
  String get label1bb4f67fef3a => 'Unlock was cancelled.';

  @override
  String get labela69fc6732df7 => 'Unsupported Android action.';

  @override
  String get labele5c81a03c8e4 => 'No valid audio file found';

  @override
  String get label8957795f2687 => 'Sign in to the recording\'s account.';

  @override
  String get labelc27cda07904f => 'The local recording is unavailable.';

  @override
  String get label7160d98ed12a =>
      'Upload is stopping. Try signing out again in a moment.';

  @override
  String get label6e403d1365f7 =>
      'Audio saved, but its details could not be updated.';

  @override
  String get labeld1497761ce3d =>
      'Microphone interrupted. The saved audio has been kept.';

  @override
  String get labelfb7fabb3f59b => 'Sign in before recording';

  @override
  String get label86a0a120d000 =>
      'The 54-minute recording limit was reached. Audio has been saved.';

  @override
  String get label6aacf8f7a4f4 => 'The microphone could not be opened';

  @override
  String get labelf77d844bd3e6 =>
      'Android requested Bluetooth pairing. Cancel the prompt and export diagnostics. This is separate from the device key.';

  @override
  String get labelb4abac09ddaa => 'Bluetooth is unavailable';

  @override
  String get label2696acc675bb => 'Bluetooth scanning is unavailable';

  @override
  String get label12ccdafe98af => 'Connect and authorize the recorder first';

  @override
  String get label881358b23a3e => 'Decoding audio…';

  @override
  String get label60be0d723450 =>
      'Device discovery could not start. Try again.';

  @override
  String get labele6de9857d9de => 'Device status is unknown. Refresh it first.';

  @override
  String get label9a83d411be97 =>
      'Disconnect the current device or wait for verification to finish';

  @override
  String get labele3612e46803e => 'File list is incomplete. Load it again.';

  @override
  String get label624978a9fdb9 =>
      'File received. Verifying and decoding audio…';

  @override
  String get label6e10b5d9ac7c => 'Finish or cancel the current transfer first';

  @override
  String get labelc84c53e325b9 => 'Folder list is incomplete. Refresh it.';

  @override
  String get label1d6fa934a135 => 'Invalid Bluetooth address';

  @override
  String get label73f3b91129b4 =>
      'Not enough phone storage to receive and decode this file';

  @override
  String get labela67fbae8b37e =>
      'Recorder busy. Wait for the current action to finish.';

  @override
  String get label56293b946edb =>
      'Recording has not been confirmed. Refresh device status.';

  @override
  String get label99cb9dbb575f =>
      'Recordings must be under 60 minutes. For a connection test, record 10–30 seconds.';

  @override
  String get label582e2241c5e0 => 'Refresh the device file list';

  @override
  String get label6de22cdd3fbe => 'Save a device key before connecting';

  @override
  String get label3d0eedf458fb => 'Sign in before syncing to this phone.';

  @override
  String get label4898fd2ce8a9 =>
      'Sign in first. Imported recordings are saved to that account on this phone.';

  @override
  String get label8835e8dff9c4 => 'Sign in to use live transcription.';

  @override
  String get labeld1ded7701d16 =>
      'Stop recording and refresh device status first';

  @override
  String get labele915c9021cf0 =>
      'The account changed. The original file was kept without adding it to another account.';

  @override
  String get labeld39fe5ae8670 =>
      'The previous transcript is finishing. Try again shortly.';

  @override
  String get labeld081d82e7bac => 'Turn on Bluetooth';

  @override
  String get labelbf84d4f787ce => 'Turn on Bluetooth first';

  @override
  String get labeld7cf4941b136 =>
      'Wait for the decoded file to finish saving before disconnecting';

  @override
  String get label3380d425195b =>
      'The network request failed. Check your connection and try again.';

  @override
  String get label1b144c8c7d14 => 'Your session expired. Sign in again.';

  @override
  String get label1d1152d6d52f => 'You do not have access to this item.';

  @override
  String get label197c299e08a2 => 'This item is no longer available.';

  @override
  String get label5063fc19cf22 => 'Too many requests. Try again shortly.';

  @override
  String get labelea44638d3340 =>
      'The service is temporarily unavailable. Try again later.';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String speakerLabel(String name) {
    return 'Speaker $name';
  }

  @override
  String savedVersionDate(String date) {
    return 'Saved version · $date';
  }

  @override
  String get labelb17d3954b0f0 => 'Account changed. Sign in and retry.';

  @override
  String get label715d2af9f81b => 'Audio could not be loaded. Retry playback.';

  @override
  String get labelf7c4df5ebfc0 =>
      'Browser storage is unavailable. Allow website storage and retry.';

  @override
  String get labelcfa0dfffb662 =>
      'Choose a supported audio, video, document or PNG/JPEG file.';

  @override
  String get label1b1aff5e5100 => 'Choose up to 20 files at a time.';

  @override
  String get label033eedd28183 => 'Close other Teno tabs and retry.';

  @override
  String get label450f7807e5e7 =>
      'Could not save the file in this browser. Free up storage and retry.';

  @override
  String get label7f5bff4d3e6d => 'File unavailable for this account.';

  @override
  String get labelbe125b0e02ff => 'Invalid interface language.';

  @override
  String get label42ff5192c1e3 =>
      'RECORDING_UNAVAILABLE: This recording is no longer available.';

  @override
  String get label4776d0f30a16 => 'Sign-in cancelled.';

  @override
  String get labeld213c1d485d4 =>
      'Stop the upload before deleting this browser copy.';

  @override
  String get label3ee0417ca776 =>
      'This action is not available in the Web preview.';

  @override
  String get label05fa01dff97b =>
      'This audio cannot be played in this browser.';

  @override
  String get label12bfad5e9bb0 => 'This file is uploading in another tab.';

  @override
  String get label009a19b41a91 => 'This request is not a Teno API request.';

  @override
  String get labelc691c2b42bd2 => 'Upload result was incomplete. Retry safely.';

  @override
  String get label6122f155474f =>
      'Upload or request stopped. Retry when ready.';

  @override
  String get label8c7103817ec7 =>
      'Connection interrupted. Check your internet connection and retry.';

  @override
  String get loginInvalidCredentials =>
      'Invalid username or password. Check your Teno account and try again.';

  @override
  String get autoJwdHeading => 'Connecting your JWD recorder';

  @override
  String get autoJwdProgress =>
      'Searching, verifying and connecting automatically.';

  @override
  String get autoJwdCancel => 'Cancel connection';

  @override
  String get autoJwdRetry => 'Retry connection';

  @override
  String get autoJwdRestore => 'Restore original device code';

  @override
  String get autoJwdSearching => 'Searching for your JWD recorder';

  @override
  String get autoJwdVerifying => 'Verifying recorder protocol';

  @override
  String get autoJwdConnecting => 'Connecting automatically';

  @override
  String get autoJwdNoDevice =>
      'No JWD recorder found. Wake your recorder and try again.';

  @override
  String get autoJwdLastMissing =>
      'Your last recorder is unavailable. Wake it up and try again.';

  @override
  String get autoJwdKeyRejected =>
      'Device key was rejected. Use the original key; the recorder was not reset.';

  @override
  String get autoJwdSaveCode =>
      'The device code could not be saved. Try connecting again.';

  @override
  String get autoJwdAuth => 'Authorizing recorder';

  @override
  String get autoJwdChannels =>
      'The recorder channels do not match the JWD protocol.';
}
