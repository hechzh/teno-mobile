import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @assistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistant;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @interfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get interfaceLanguage;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @languageHint.
  ///
  /// In en, this message translates to:
  /// **'Changes interface text only. Recordings, notes and chats are not translated.'**
  String get languageHint;

  /// No description provided for @appearanceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Appearance & language'**
  String get appearanceLanguage;

  /// No description provided for @privacyData.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get privacyData;

  /// No description provided for @recorderRecording.
  ///
  /// In en, this message translates to:
  /// **'Recorder & recording'**
  String get recorderRecording;

  /// No description provided for @brief.
  ///
  /// In en, this message translates to:
  /// **'Brief'**
  String get brief;

  /// No description provided for @recentRecordings.
  ///
  /// In en, this message translates to:
  /// **'Recent recordings'**
  String get recentRecordings;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @importFiles.
  ///
  /// In en, this message translates to:
  /// **'Import files'**
  String get importFiles;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get startRecording;

  /// No description provided for @myRecorder.
  ///
  /// In en, this message translates to:
  /// **'My recorder'**
  String get myRecorder;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @versions.
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get versions;

  /// No description provided for @topics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get topics;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @emptyBrief.
  ///
  /// In en, this message translates to:
  /// **'Your latest saved note will appear here.'**
  String get emptyBrief;

  /// No description provided for @briefSource.
  ///
  /// In en, this message translates to:
  /// **'From a saved note'**
  String get briefSource;

  /// No description provided for @noNotes.
  ///
  /// In en, this message translates to:
  /// **'No saved notes yet'**
  String get noNotes;

  /// No description provided for @firstRecording.
  ///
  /// In en, this message translates to:
  /// **'Start with something worth keeping.'**
  String get firstRecording;

  /// No description provided for @firstRecordingHint.
  ///
  /// In en, this message translates to:
  /// **'Import audio to keep its transcript, notes and sources together.'**
  String get firstRecordingHint;

  /// No description provided for @assistantTitle.
  ///
  /// In en, this message translates to:
  /// **'A little clarity, from your recordings.'**
  String get assistantTitle;

  /// No description provided for @assistantHint.
  ///
  /// In en, this message translates to:
  /// **'Answers from your recordings and notes, with source timestamps when available.'**
  String get assistantHint;

  /// No description provided for @personalAccount.
  ///
  /// In en, this message translates to:
  /// **'Personal account'**
  String get personalAccount;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @briefVersion.
  ///
  /// In en, this message translates to:
  /// **'From {title} · v{version}'**
  String briefVersion(String title, String version);

  /// No description provided for @topicCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 topic} other {{count} topics}}'**
  String topicCount(int count);

  /// No description provided for @sourceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sources'**
  String sourceCount(int count);

  /// No description provided for @label7e1b0d5641f2.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get label7e1b0d5641f2;

  /// No description provided for @labelf521e4248c6d.
  ///
  /// In en, this message translates to:
  /// **'Account & security'**
  String get labelf521e4248c6d;

  /// No description provided for @label6c4b5440e570.
  ///
  /// In en, this message translates to:
  /// **'Account changed. Open this recording again.'**
  String get label6c4b5440e570;

  /// No description provided for @label8a7dfc4957be.
  ///
  /// In en, this message translates to:
  /// **'Account changed. Reload this page.'**
  String get label8a7dfc4957be;

  /// No description provided for @label7874b13aeec1.
  ///
  /// In en, this message translates to:
  /// **'Add a recording, import a file or create a note.'**
  String get label7874b13aeec1;

  /// No description provided for @label88f3f837facd.
  ///
  /// In en, this message translates to:
  /// **'Add a title and instructions.'**
  String get label88f3f837facd;

  /// No description provided for @label0f01d14cacf0.
  ///
  /// In en, this message translates to:
  /// **'Add context'**
  String get label0f01d14cacf0;

  /// No description provided for @label57d208bc0d04.
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get label57d208bc0d04;

  /// No description provided for @label5f0580aa7e39.
  ///
  /// In en, this message translates to:
  /// **'Add highlight'**
  String get label5f0580aa7e39;

  /// No description provided for @label75d9b95a566f.
  ///
  /// In en, this message translates to:
  /// **'Add subfolder'**
  String get label75d9b95a566f;

  /// No description provided for @labela52ace420f21.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get labela52ace420f21;

  /// No description provided for @labelbffc49b558cf.
  ///
  /// In en, this message translates to:
  /// **'All cloud recordings'**
  String get labelbffc49b558cf;

  /// No description provided for @label2c92a471fdfc.
  ///
  /// In en, this message translates to:
  /// **'All recordings'**
  String get label2c92a471fdfc;

  /// No description provided for @labela4717b6543d6.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get labela4717b6543d6;

  /// No description provided for @label772c230c059d.
  ///
  /// In en, this message translates to:
  /// **'Anyone using this link will lose access.'**
  String get label772c230c059d;

  /// No description provided for @labelb0d015fdadc3.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get labelb0d015fdadc3;

  /// No description provided for @label1862f6ab9820.
  ///
  /// In en, this message translates to:
  /// **'Applies to your next recording. Complete audio is processed again after recording.'**
  String get label1862f6ab9820;

  /// No description provided for @labela71379918f19.
  ///
  /// In en, this message translates to:
  /// **'Ask Teno'**
  String get labela71379918f19;

  /// No description provided for @label717367d1bd24.
  ///
  /// In en, this message translates to:
  /// **'Ask a question about your recordings.'**
  String get label717367d1bd24;

  /// No description provided for @label440c2d0c3740.
  ///
  /// In en, this message translates to:
  /// **'Ask about this recording'**
  String get label440c2d0c3740;

  /// No description provided for @label813bfccd9116.
  ///
  /// In en, this message translates to:
  /// **'Ask about your recordings'**
  String get label813bfccd9116;

  /// No description provided for @label844fb4bf3408.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about this recording'**
  String get label844fb4bf3408;

  /// No description provided for @labeldb41f0c39aaf.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about your recordings'**
  String get labeldb41f0c39aaf;

  /// No description provided for @label46b396c85919.
  ///
  /// In en, this message translates to:
  /// **'At a glance'**
  String get label46b396c85919;

  /// No description provided for @label5e3176c01225.
  ///
  /// In en, this message translates to:
  /// **'AI-generated · Review key details'**
  String get label5e3176c01225;

  /// No description provided for @labelbc1b88907d3b.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get labelbc1b88907d3b;

  /// No description provided for @label00140e8ad0ea.
  ///
  /// In en, this message translates to:
  /// **'Audio & transcript'**
  String get label00140e8ad0ea;

  /// No description provided for @label8d8e1aff4a6f.
  ///
  /// In en, this message translates to:
  /// **'Audio and video · Up to 120 minutes / 250 MiB'**
  String get label8d8e1aff4a6f;

  /// No description provided for @labelfe629dea74ec.
  ///
  /// In en, this message translates to:
  /// **'Audio could not be verified'**
  String get labelfe629dea74ec;

  /// No description provided for @label656fb6ded904.
  ///
  /// In en, this message translates to:
  /// **'Audio is kept while Teno prepares your notes.'**
  String get label656fb6ded904;

  /// No description provided for @label0be233af17d9.
  ///
  /// In en, this message translates to:
  /// **'Audio language'**
  String get label0be233af17d9;

  /// No description provided for @label419a6c580fbd.
  ///
  /// In en, this message translates to:
  /// **'Audio settings'**
  String get label419a6c580fbd;

  /// No description provided for @labeld461a493a375.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get labeld461a493a375;

  /// No description provided for @label179fd3261edf.
  ///
  /// In en, this message translates to:
  /// **'Automatic processing'**
  String get label179fd3261edf;

  /// No description provided for @label00b76f172d63.
  ///
  /// In en, this message translates to:
  /// **'Automatically upload new recordings and imports for transcription and summaries.'**
  String get label00b76f172d63;

  /// No description provided for @label6209c5481977.
  ///
  /// In en, this message translates to:
  /// **'Automatically upload saved audio for transcription and summary.'**
  String get label6209c5481977;

  /// No description provided for @label48d57e9d4911.
  ///
  /// In en, this message translates to:
  /// **'Back 15 seconds'**
  String get label48d57e9d4911;

  /// No description provided for @label008e42d22277.
  ///
  /// In en, this message translates to:
  /// **'Back to library'**
  String get label008e42d22277;

  /// No description provided for @labeldfcb7c1619d5.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get labeldfcb7c1619d5;

  /// No description provided for @labeld83ab68f7428.
  ///
  /// In en, this message translates to:
  /// **'Best match'**
  String get labeld83ab68f7428;

  /// No description provided for @label0f82b87c1954.
  ///
  /// In en, this message translates to:
  /// **'Bring your JWD recorder closer'**
  String get label0f82b87c1954;

  /// No description provided for @label359ca59af29e.
  ///
  /// In en, this message translates to:
  /// **'Browser imports'**
  String get label359ca59af29e;

  /// No description provided for @label9bc6697e3dc9.
  ///
  /// In en, this message translates to:
  /// **'Browser imports stay under this account. Uploads in progress will stop; sign in again to retry.'**
  String get label9bc6697e3dc9;

  /// No description provided for @label2456433596a1.
  ///
  /// In en, this message translates to:
  /// **'Cached previews and exports'**
  String get label2456433596a1;

  /// No description provided for @labeld5d0a30b517e.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get labeld5d0a30b517e;

  /// No description provided for @label84110d11d312.
  ///
  /// In en, this message translates to:
  /// **'Calendar actions'**
  String get label84110d11d312;

  /// No description provided for @label0e826ce50ae6.
  ///
  /// In en, this message translates to:
  /// **'Capture important visuals'**
  String get label0e826ce50ae6;

  /// No description provided for @label292c06f0045a.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get label292c06f0045a;

  /// No description provided for @label9831375bc651.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get label9831375bc651;

  /// No description provided for @label460b3a7da007.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get label460b3a7da007;

  /// No description provided for @label05a05aa2fd48.
  ///
  /// In en, this message translates to:
  /// **'Chat history'**
  String get label05a05aa2fd48;

  /// No description provided for @label916702c8589f.
  ///
  /// In en, this message translates to:
  /// **'Check answers against the linked source recordings.'**
  String get label916702c8589f;

  /// No description provided for @label4e8780f8aa73.
  ///
  /// In en, this message translates to:
  /// **'Check important answers against the linked sources.'**
  String get label4e8780f8aa73;

  /// No description provided for @label473763cd02d9.
  ///
  /// In en, this message translates to:
  /// **'Checking recording service…'**
  String get label473763cd02d9;

  /// No description provided for @label8a9779f42128.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get label8a9779f42128;

  /// No description provided for @label92181d4a51d4.
  ///
  /// In en, this message translates to:
  /// **'Choose a format'**
  String get label92181d4a51d4;

  /// No description provided for @labelda0f63e19741.
  ///
  /// In en, this message translates to:
  /// **'Choose content'**
  String get labelda0f63e19741;

  /// No description provided for @labela98b1d3e5ceb.
  ///
  /// In en, this message translates to:
  /// **'Choose content to include'**
  String get labela98b1d3e5ceb;

  /// No description provided for @label343b5a9c7fd6.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get label343b5a9c7fd6;

  /// No description provided for @label79c6c7ad4ad7.
  ///
  /// In en, this message translates to:
  /// **'Choose dates'**
  String get label79c6c7ad4ad7;

  /// No description provided for @labelfc29d2cd66c0.
  ///
  /// In en, this message translates to:
  /// **'Choose up to 30 recordings with transcripts.'**
  String get labelfc29d2cd66c0;

  /// No description provided for @label108e4eec572c.
  ///
  /// In en, this message translates to:
  /// **'Clean up transcript automatically'**
  String get label108e4eec572c;

  /// No description provided for @labeld00e4df0930c.
  ///
  /// In en, this message translates to:
  /// **'Cleaned-up text is not available yet.'**
  String get labeld00e4df0930c;

  /// No description provided for @labeld33461e6c0b6.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get labeld33461e6c0b6;

  /// No description provided for @label39041f7b9262.
  ///
  /// In en, this message translates to:
  /// **'Clear cached files?'**
  String get label39041f7b9262;

  /// No description provided for @label3b7ea51793e9.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get label3b7ea51793e9;

  /// No description provided for @label95d460729621.
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get label95d460729621;

  /// No description provided for @labeld8232cf4eb24.
  ///
  /// In en, this message translates to:
  /// **'Close keyboard'**
  String get labeld8232cf4eb24;

  /// No description provided for @labela600b900f83d.
  ///
  /// In en, this message translates to:
  /// **'Close panel'**
  String get labela600b900f83d;

  /// No description provided for @label2b7aa8894c21.
  ///
  /// In en, this message translates to:
  /// **'Cloud processing'**
  String get label2b7aa8894c21;

  /// No description provided for @label838991b2b94f.
  ///
  /// In en, this message translates to:
  /// **'Cloud processing is off. Imported files stay on this phone until you choose Upload and process.'**
  String get label838991b2b94f;

  /// No description provided for @label8adaed39e1a2.
  ///
  /// In en, this message translates to:
  /// **'Cloud processing is on. Imported files are saved on this phone, then uploaded and processed automatically.'**
  String get label8adaed39e1a2;

  /// No description provided for @label2187c26af752.
  ///
  /// In en, this message translates to:
  /// **'Cloud processing starts on for accounts without a saved preference. An existing choice to turn it off is kept. Enable it in Settings → Cloud processing.'**
  String get label2187c26af752;

  /// No description provided for @labela293e2e43fd2.
  ///
  /// In en, this message translates to:
  /// **'Compatibility scan'**
  String get labela293e2e43fd2;

  /// No description provided for @label7810980ade40.
  ///
  /// In en, this message translates to:
  /// **'Complete files are verified and saved locally before cloud upload. Reconnect to retry an interrupted transfer. Device originals are not automatically deleted.'**
  String get label7810980ade40;

  /// No description provided for @label9d989f15c1c5.
  ///
  /// In en, this message translates to:
  /// **'Complete recordings and imports remain on this phone after upload. Keep the app installed to retain these local copies.'**
  String get label9d989f15c1c5;

  /// No description provided for @label060f79ce72a8.
  ///
  /// In en, this message translates to:
  /// **'Complete recordings and imports stay on this phone after upload. Existing saved files are uploaded only when you request it.'**
  String get label060f79ce72a8;

  /// No description provided for @labelc8d900f3aeed.
  ///
  /// In en, this message translates to:
  /// **'Complete recordings are automatically kept on this phone. Cloud upload never removes a local recording.'**
  String get labelc8d900f3aeed;

  /// No description provided for @labeleebdd24a77d9.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get labeleebdd24a77d9;

  /// No description provided for @label5b27ed7fa9dd.
  ///
  /// In en, this message translates to:
  /// **'Connect a JWD recorder, check its service, then authorize it with its device key. Keep the original key to connect from another phone.'**
  String get label5b27ed7fa9dd;

  /// No description provided for @labelac593f874557.
  ///
  /// In en, this message translates to:
  /// **'Connect a recorder'**
  String get labelac593f874557;

  /// No description provided for @label40f9815ebd38.
  ///
  /// In en, this message translates to:
  /// **'Connect a recorder without signing in'**
  String get label40f9815ebd38;

  /// No description provided for @label9e7eba0b97c9.
  ///
  /// In en, this message translates to:
  /// **'Connect phone calendar'**
  String get label9e7eba0b97c9;

  /// No description provided for @label9639916d9dfb.
  ///
  /// In en, this message translates to:
  /// **'Connect recorder'**
  String get label9639916d9dfb;

  /// No description provided for @label1ca37334ccfa.
  ///
  /// In en, this message translates to:
  /// **'Connect your recorder'**
  String get label1ca37334ccfa;

  /// No description provided for @label62d0bfa77e96.
  ///
  /// In en, this message translates to:
  /// **'Connect your recorder and keep its original device key. Reconnecting does not start a recording. A Bluetooth disconnect does not mean the recorder has stopped.'**
  String get label62d0bfa77e96;

  /// No description provided for @label8b53877af85c.
  ///
  /// In en, this message translates to:
  /// **'Connect your recorder to capture your next conversation.'**
  String get label8b53877af85c;

  /// No description provided for @label47bd29075f8b.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get label47bd29075f8b;

  /// No description provided for @label31fbef162594.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get label31fbef162594;

  /// No description provided for @label37145972530b.
  ///
  /// In en, this message translates to:
  /// **'Continued'**
  String get label37145972530b;

  /// No description provided for @labele21f935f11d7.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get labele21f935f11d7;

  /// No description provided for @labelf81b58cb3b7c.
  ///
  /// In en, this message translates to:
  /// **'Copy / Export'**
  String get labelf81b58cb3b7c;

  /// No description provided for @labeld888b94d692e.
  ///
  /// In en, this message translates to:
  /// **'Copy note'**
  String get labeld888b94d692e;

  /// No description provided for @labelb749e205302c.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get labelb749e205302c;

  /// No description provided for @labelfa8d84566676.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get labelfa8d84566676;

  /// No description provided for @label4759498ac2a7.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get label4759498ac2a7;

  /// No description provided for @label4993a031ed5a.
  ///
  /// In en, this message translates to:
  /// **'Create a link from a recording or note.'**
  String get label4993a031ed5a;

  /// No description provided for @label6eb05a41f7e6.
  ///
  /// In en, this message translates to:
  /// **'Create a shareable link. Anyone with the link can access this file.'**
  String get label6eb05a41f7e6;

  /// No description provided for @labele6b850cff6af.
  ///
  /// In en, this message translates to:
  /// **'Create link'**
  String get labele6b850cff6af;

  /// No description provided for @label7dc9c0adaca0.
  ///
  /// In en, this message translates to:
  /// **'Create template'**
  String get label7dc9c0adaca0;

  /// No description provided for @labelf9182f6f2dc8.
  ///
  /// In en, this message translates to:
  /// **'Created by me'**
  String get labelf9182f6f2dc8;

  /// No description provided for @label26756b8c8a6e.
  ///
  /// In en, this message translates to:
  /// **'Creating link…'**
  String get label26756b8c8a6e;

  /// No description provided for @labele0d1b68224bf.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get labele0d1b68224bf;

  /// No description provided for @label60acc53f13a5.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get label60acc53f13a5;

  /// No description provided for @labelfa91f7628ea5.
  ///
  /// In en, this message translates to:
  /// **'Date created'**
  String get labelfa91f7628ea5;

  /// No description provided for @label5b7e27d5a077.
  ///
  /// In en, this message translates to:
  /// **'Date created · newest'**
  String get label5b7e27d5a077;

  /// No description provided for @labelc4709b234134.
  ///
  /// In en, this message translates to:
  /// **'Date created · oldest'**
  String get labelc4709b234134;

  /// No description provided for @labeleb5e7a5e3d68.
  ///
  /// In en, this message translates to:
  /// **'Date modified'**
  String get labeleb5e7a5e3d68;

  /// No description provided for @label45b575b18fb2.
  ///
  /// In en, this message translates to:
  /// **'Date modified · newest'**
  String get label45b575b18fb2;

  /// No description provided for @label8061bfb29ce8.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get label8061bfb29ce8;

  /// No description provided for @label0372d70a4fd5.
  ///
  /// In en, this message translates to:
  /// **'Default configurations for language, speaker labels and transcript cleanup.'**
  String get label0372d70a4fd5;

  /// No description provided for @labeleb4dd2202ac2.
  ///
  /// In en, this message translates to:
  /// **'Default summary'**
  String get labeleb4dd2202ac2;

  /// No description provided for @labele2d0a54968ea.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get labele2d0a54968ea;

  /// No description provided for @labelb872a42ed4cc.
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get labelb872a42ed4cc;

  /// No description provided for @label113be1f69f41.
  ///
  /// In en, this message translates to:
  /// **'Delete event?'**
  String get label113be1f69f41;

  /// No description provided for @label39f35f2d44d6.
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get label39f35f2d44d6;

  /// No description provided for @label28b4629208db.
  ///
  /// In en, this message translates to:
  /// **'Delete folder?'**
  String get label28b4629208db;

  /// No description provided for @label6a6dd3ce6ae2.
  ///
  /// In en, this message translates to:
  /// **'Delete local copy'**
  String get label6a6dd3ce6ae2;

  /// No description provided for @labelba9f45a1c2d6.
  ///
  /// In en, this message translates to:
  /// **'Delete local copy?'**
  String get labelba9f45a1c2d6;

  /// No description provided for @label280b10c89cc4.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get label280b10c89cc4;

  /// No description provided for @labelc1b15a371248.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently?'**
  String get labelc1b15a371248;

  /// No description provided for @labelda9a9b350675.
  ///
  /// In en, this message translates to:
  /// **'Delete template'**
  String get labelda9a9b350675;

  /// No description provided for @labele1d84431b905.
  ///
  /// In en, this message translates to:
  /// **'Delete template?'**
  String get labele1d84431b905;

  /// No description provided for @labelc13e8743fff5.
  ///
  /// In en, this message translates to:
  /// **'Deleted cloud recordings will appear here.'**
  String get labelc13e8743fff5;

  /// No description provided for @label14f912855ddb.
  ///
  /// In en, this message translates to:
  /// **'Device key backup'**
  String get label14f912855ddb;

  /// No description provided for @labelada711324c39.
  ///
  /// In en, this message translates to:
  /// **'Discard pending imports'**
  String get labelada711324c39;

  /// No description provided for @labelacfc5be785a9.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get labelacfc5be785a9;

  /// No description provided for @labelb4e929d8bcfe.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get labelb4e929d8bcfe;

  /// No description provided for @labele9ca7472dee6.
  ///
  /// In en, this message translates to:
  /// **'Drop into a folder'**
  String get labele9ca7472dee6;

  /// No description provided for @label464c4ffd019e.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get label464c4ffd019e;

  /// No description provided for @label4f97831c321a.
  ///
  /// In en, this message translates to:
  /// **'Edit local notes'**
  String get label4f97831c321a;

  /// No description provided for @label299e604ccff3.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get label299e604ccff3;

  /// No description provided for @label0e3eb67d72e9.
  ///
  /// In en, this message translates to:
  /// **'Edit segment'**
  String get label0e3eb67d72e9;

  /// No description provided for @labelc04f3d9cb841.
  ///
  /// In en, this message translates to:
  /// **'Edit summary'**
  String get labelc04f3d9cb841;

  /// No description provided for @label176a44212e88.
  ///
  /// In en, this message translates to:
  /// **'Edit title'**
  String get label176a44212e88;

  /// No description provided for @label08d4e40d7c51.
  ///
  /// In en, this message translates to:
  /// **'Edit transcript'**
  String get label08d4e40d7c51;

  /// No description provided for @labela440abe23574.
  ///
  /// In en, this message translates to:
  /// **'Edited text'**
  String get labela440abe23574;

  /// No description provided for @label74a1be251418.
  ///
  /// In en, this message translates to:
  /// **'Edits here update the local note. Notes sent with the original upload remain on the server.'**
  String get label74a1be251418;

  /// No description provided for @labele9d41512971a.
  ///
  /// In en, this message translates to:
  /// **'End of note'**
  String get labele9d41512971a;

  /// No description provided for @labelba118bf7fc9c.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get labelba118bf7fc9c;

  /// No description provided for @label258ad01aae4c.
  ///
  /// In en, this message translates to:
  /// **'Enter start and end seconds separated by a comma.'**
  String get label258ad01aae4c;

  /// No description provided for @label4e1f49a9c8ae.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get label4e1f49a9c8ae;

  /// No description provided for @label8ec4602ce4a2.
  ///
  /// In en, this message translates to:
  /// **'Event title'**
  String get label8ec4602ce4a2;

  /// No description provided for @label74100229729d.
  ///
  /// In en, this message translates to:
  /// **'Existing notes keep their generated content.'**
  String get label74100229729d;

  /// No description provided for @label83f51733c819.
  ///
  /// In en, this message translates to:
  /// **'Existing summaries will be preserved.'**
  String get label83f51733c819;

  /// No description provided for @label3664895579f0.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get label3664895579f0;

  /// No description provided for @label6888c0a35c11.
  ///
  /// In en, this message translates to:
  /// **'Export & share'**
  String get label6888c0a35c11;

  /// No description provided for @label1e74a176a3dd.
  ///
  /// In en, this message translates to:
  /// **'Export as'**
  String get label1e74a176a3dd;

  /// No description provided for @labelcd6d4c5ea371.
  ///
  /// In en, this message translates to:
  /// **'Export audio'**
  String get labelcd6d4c5ea371;

  /// No description provided for @labelf066ead78e58.
  ///
  /// In en, this message translates to:
  /// **'Export note'**
  String get labelf066ead78e58;

  /// No description provided for @labeld106178565fd.
  ///
  /// In en, this message translates to:
  /// **'Export original'**
  String get labeld106178565fd;

  /// No description provided for @labelf6aee6b20fe9.
  ///
  /// In en, this message translates to:
  /// **'Export transcript'**
  String get labelf6aee6b20fe9;

  /// No description provided for @label6ab7f7d9e711.
  ///
  /// In en, this message translates to:
  /// **'Extracting text. The original file is saved.'**
  String get label6ab7f7d9e711;

  /// No description provided for @labelac67507227ad.
  ///
  /// In en, this message translates to:
  /// **'Favorite template'**
  String get labelac67507227ad;

  /// No description provided for @label7a1f2a83aca9.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get label7a1f2a83aca9;

  /// No description provided for @label50009ce1da4d.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get label50009ce1da4d;

  /// No description provided for @labelb163fad90bee.
  ///
  /// In en, this message translates to:
  /// **'File options'**
  String get labelb163fad90bee;

  /// No description provided for @labelb3b9efed9c4d.
  ///
  /// In en, this message translates to:
  /// **'File unavailable'**
  String get labelb3b9efed9c4d;

  /// No description provided for @labelabc7e9892806.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get labelabc7e9892806;

  /// No description provided for @labeledfdb024f059.
  ///
  /// In en, this message translates to:
  /// **'Files are saved in this browser. Choose Upload and process to send them to your signed-in account. Keep this tab open until upload finishes.'**
  String get labeledfdb024f059;

  /// No description provided for @labele5a5c0df54fc.
  ///
  /// In en, this message translates to:
  /// **'Files remain in your library.'**
  String get labele5a5c0df54fc;

  /// No description provided for @labeldead605b2f80.
  ///
  /// In en, this message translates to:
  /// **'Files selected for import appear here.'**
  String get labeldead605b2f80;

  /// No description provided for @label822b2ae4542b.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get label822b2ae4542b;

  /// No description provided for @labelf8c805bd6a45.
  ///
  /// In en, this message translates to:
  /// **'Find & replace'**
  String get labelf8c805bd6a45;

  /// No description provided for @label7337c292a757.
  ///
  /// In en, this message translates to:
  /// **'Find a conversation'**
  String get label7337c292a757;

  /// No description provided for @label4230011827fe.
  ///
  /// In en, this message translates to:
  /// **'Find a file'**
  String get label4230011827fe;

  /// No description provided for @labeld543a6e1672a.
  ///
  /// In en, this message translates to:
  /// **'Find my recorder'**
  String get labeld543a6e1672a;

  /// No description provided for @labelb8a514901391.
  ///
  /// In en, this message translates to:
  /// **'Find the important details'**
  String get labelb8a514901391;

  /// No description provided for @label74ccd4330384.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get label74ccd4330384;

  /// No description provided for @labele37afba74564.
  ///
  /// In en, this message translates to:
  /// **'Folder options'**
  String get labele37afba74564;

  /// No description provided for @labelc4d6bb200f4c.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get labelc4d6bb200f4c;

  /// No description provided for @labeld383fef33b8f.
  ///
  /// In en, this message translates to:
  /// **'Follow audio'**
  String get labeld383fef33b8f;

  /// No description provided for @label2ba88fa96208.
  ///
  /// In en, this message translates to:
  /// **'For a recorder already used with Teno, enter its original device key. A new key is only for an unbound recorder.'**
  String get label2ba88fa96208;

  /// No description provided for @label2f343666aaa8.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get label2f343666aaa8;

  /// No description provided for @label19190cce5524.
  ///
  /// In en, this message translates to:
  /// **'Forward 15 seconds'**
  String get label19190cce5524;

  /// No description provided for @label6754c0ab7f8f.
  ///
  /// In en, this message translates to:
  /// **'From Files'**
  String get label6754c0ab7f8f;

  /// No description provided for @label687c53cb1fb7.
  ///
  /// In en, this message translates to:
  /// **'From Photos'**
  String get label687c53cb1fb7;

  /// No description provided for @label5052681b30b0.
  ///
  /// In en, this message translates to:
  /// **'From other apps'**
  String get label5052681b30b0;

  /// No description provided for @labelc910d474dcd7.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get labelc910d474dcd7;

  /// No description provided for @label49e49bb4401e.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get label49e49bb4401e;

  /// No description provided for @label9414748cad34.
  ///
  /// In en, this message translates to:
  /// **'Generate cleaned-up text'**
  String get label9414748cad34;

  /// No description provided for @labelab35d87baddf.
  ///
  /// In en, this message translates to:
  /// **'Generate summary'**
  String get labelab35d87baddf;

  /// No description provided for @label8c8afc5edbe9.
  ///
  /// In en, this message translates to:
  /// **'Generated content language'**
  String get label8c8afc5edbe9;

  /// No description provided for @label40536dd8a0e2.
  ///
  /// In en, this message translates to:
  /// **'Generation'**
  String get label40536dd8a0e2;

  /// No description provided for @label467c73ec9baf.
  ///
  /// In en, this message translates to:
  /// **'HTTPS server'**
  String get label467c73ec9baf;

  /// No description provided for @label7a34ff85344e.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get label7a34ff85344e;

  /// No description provided for @labele2f55c84f3b4.
  ///
  /// In en, this message translates to:
  /// **'Help center'**
  String get labele2f55c84f3b4;

  /// No description provided for @label5cb5d4286696.
  ///
  /// In en, this message translates to:
  /// **'Hide other devices'**
  String get label5cb5d4286696;

  /// No description provided for @label07ccd15df32a.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get label07ccd15df32a;

  /// No description provided for @label6e517828c3d8.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get label6e517828c3d8;

  /// No description provided for @label66bc5802319d.
  ///
  /// In en, this message translates to:
  /// **'Home → + → Import files. Choose From Files or From Photos. In another app, tap Share → Teno.'**
  String get label66bc5802319d;

  /// No description provided for @label59c2eaa21578.
  ///
  /// In en, this message translates to:
  /// **'Home → + → Import files. Choose a file, then Upload and process. Keep this tab open until upload finishes. Processing then continues on the server.'**
  String get label59c2eaa21578;

  /// No description provided for @labelb9e9d6be1bcf.
  ///
  /// In en, this message translates to:
  /// **'How can I help you today?'**
  String get labelb9e9d6be1bcf;

  /// No description provided for @labela8bb3b086be4.
  ///
  /// In en, this message translates to:
  /// **'Images · 20 MB    Documents · 15 MB    Text · 2 MB'**
  String get labela8bb3b086be4;

  /// No description provided for @label2cff9baabf56.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get label2cff9baabf56;

  /// No description provided for @labeldb5f9fda6639.
  ///
  /// In en, this message translates to:
  /// **'Import a file to create your first note.'**
  String get labeldb5f9fda6639;

  /// No description provided for @label5f25f9f40b7a.
  ///
  /// In en, this message translates to:
  /// **'Import and process'**
  String get label5f25f9f40b7a;

  /// No description provided for @label03c4ac096cd8.
  ///
  /// In en, this message translates to:
  /// **'Import calendar file'**
  String get label03c4ac096cd8;

  /// No description provided for @label6f190ac40487.
  ///
  /// In en, this message translates to:
  /// **'Import limits'**
  String get label6f190ac40487;

  /// No description provided for @label321f179c80ba.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get label321f179c80ba;

  /// No description provided for @label7df60b64e7ef.
  ///
  /// In en, this message translates to:
  /// **'Imports'**
  String get label7df60b64e7ef;

  /// No description provided for @label81d985062c52.
  ///
  /// In en, this message translates to:
  /// **'In this browser'**
  String get label81d985062c52;

  /// No description provided for @label4effe447355c.
  ///
  /// In en, this message translates to:
  /// **'Interview'**
  String get label4effe447355c;

  /// No description provided for @label4c2f6b585573.
  ///
  /// In en, this message translates to:
  /// **'JSON includes the complete structured content and source references.'**
  String get label4c2f6b585573;

  /// No description provided for @label746d2d32f63b.
  ///
  /// In en, this message translates to:
  /// **'JWD candidate · Tap to verify and connect'**
  String get label746d2d32f63b;

  /// No description provided for @label1cef75aa83ee.
  ///
  /// In en, this message translates to:
  /// **'Keep your original file. Browser storage may be cleared or evicted.'**
  String get label1cef75aa83ee;

  /// No description provided for @labelc925a0fbcc77.
  ///
  /// In en, this message translates to:
  /// **'Key points'**
  String get labelc925a0fbcc77;

  /// No description provided for @labelcdfa2a966fc3.
  ///
  /// In en, this message translates to:
  /// **'Key points · One per line'**
  String get labelcdfa2a966fc3;

  /// No description provided for @label8c710d7b2497.
  ///
  /// In en, this message translates to:
  /// **'Language detection is automatic for recordings and imports.'**
  String get label8c710d7b2497;

  /// No description provided for @label8b45bb20e077.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get label8b45bb20e077;

  /// No description provided for @labeld7cd25137fff.
  ///
  /// In en, this message translates to:
  /// **'Library options'**
  String get labeld7cd25137fff;

  /// No description provided for @labeldbcd5e7bb7a0.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get labeldbcd5e7bb7a0;

  /// No description provided for @label60ec2d7bb78f.
  ///
  /// In en, this message translates to:
  /// **'Link calendar event'**
  String get label60ec2d7bb78f;

  /// No description provided for @label5a55f779d975.
  ///
  /// In en, this message translates to:
  /// **'Link expires after'**
  String get label5a55f779d975;

  /// No description provided for @label3d72409411ac.
  ///
  /// In en, this message translates to:
  /// **'Live preview is off · Settings > Recorder'**
  String get label3d72409411ac;

  /// No description provided for @label868345e0521a.
  ///
  /// In en, this message translates to:
  /// **'Live text is a preview. The complete recording is processed after it is saved and uploaded.'**
  String get label868345e0521a;

  /// No description provided for @labeld17c23100fda.
  ///
  /// In en, this message translates to:
  /// **'Live text is a preview. The complete recording is processed after recording for the final transcript and summary.'**
  String get labeld17c23100fda;

  /// No description provided for @label20611c3780d1.
  ///
  /// In en, this message translates to:
  /// **'Live transcript'**
  String get label20611c3780d1;

  /// No description provided for @label7adfd01e422a.
  ///
  /// In en, this message translates to:
  /// **'Live transcript preview'**
  String get label7adfd01e422a;

  /// No description provided for @labelac8991ef0101.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get labelac8991ef0101;

  /// No description provided for @label267c8973271e.
  ///
  /// In en, this message translates to:
  /// **'Local copies'**
  String get label267c8973271e;

  /// No description provided for @labelf6ecab810535.
  ///
  /// In en, this message translates to:
  /// **'Local file'**
  String get labelf6ecab810535;

  /// No description provided for @labelbdb955a9c88d.
  ///
  /// In en, this message translates to:
  /// **'Local files and recorder keys remain on this phone under their original account.'**
  String get labelbdb955a9c88d;

  /// No description provided for @labelb7d2bf6f1057.
  ///
  /// In en, this message translates to:
  /// **'Local recording'**
  String get labelb7d2bf6f1057;

  /// No description provided for @label622410bb0aa1.
  ///
  /// In en, this message translates to:
  /// **'Local recording notes'**
  String get label622410bb0aa1;

  /// No description provided for @label3e2b34b888f3.
  ///
  /// In en, this message translates to:
  /// **'Local recordings'**
  String get label3e2b34b888f3;

  /// No description provided for @label49dc52ab360e.
  ///
  /// In en, this message translates to:
  /// **'Local recordings and device keys stay on this phone. Sign in to the same account to access its files again.'**
  String get label49dc52ab360e;

  /// No description provided for @labeld62f03d8ff00.
  ///
  /// In en, this message translates to:
  /// **'Local storage'**
  String get labeld62f03d8ff00;

  /// No description provided for @label029757c8ca0d.
  ///
  /// In en, this message translates to:
  /// **'MEETING NOTES'**
  String get label029757c8ca0d;

  /// No description provided for @labelf3060ca2421f.
  ///
  /// In en, this message translates to:
  /// **'Manage local files'**
  String get labelf3060ca2421f;

  /// No description provided for @labelff862e135e82.
  ///
  /// In en, this message translates to:
  /// **'Mark key moments'**
  String get labelff862e135e82;

  /// No description provided for @label0e52f6b9d025.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get label0e52f6b9d025;

  /// No description provided for @label4c857c545b8a.
  ///
  /// In en, this message translates to:
  /// **'Matching recorders'**
  String get label4c857c545b8a;

  /// No description provided for @label8b8b8871bbfb.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get label8b8b8871bbfb;

  /// No description provided for @label9e6c24f51918.
  ///
  /// In en, this message translates to:
  /// **'Meeting notes'**
  String get label9e6c24f51918;

  /// No description provided for @label8851aaa7d08c.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get label8851aaa7d08c;

  /// No description provided for @labelc8627d844f1f.
  ///
  /// In en, this message translates to:
  /// **'Merged recording'**
  String get labelc8627d844f1f;

  /// No description provided for @label56112ca16c30.
  ///
  /// In en, this message translates to:
  /// **'Merged recording title'**
  String get label56112ca16c30;

  /// No description provided for @label6ecc3df6bffd.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get label6ecc3df6bffd;

  /// No description provided for @labelbd0b474a3bd3.
  ///
  /// In en, this message translates to:
  /// **'Move a recording into this folder from its options menu.'**
  String get labelbd0b474a3bd3;

  /// No description provided for @label91d631e150a3.
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get label91d631e150a3;

  /// No description provided for @labelb250a454877d.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get labelb250a454877d;

  /// No description provided for @label6d090914f6d7.
  ///
  /// In en, this message translates to:
  /// **'Move to trash?'**
  String get label6d090914f6d7;

  /// No description provided for @label985698b7b5c4.
  ///
  /// In en, this message translates to:
  /// **'My files'**
  String get label985698b7b5c4;

  /// No description provided for @label5030ec983702.
  ///
  /// In en, this message translates to:
  /// **'My files views'**
  String get label5030ec983702;

  /// No description provided for @label1901b64190f9.
  ///
  /// In en, this message translates to:
  /// **'My templates'**
  String get label1901b64190f9;

  /// No description provided for @label7bfab6c61f77.
  ///
  /// In en, this message translates to:
  /// **'NOTES'**
  String get label7bfab6c61f77;

  /// No description provided for @labeldcd1d5223f73.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get labeldcd1d5223f73;

  /// No description provided for @labeled245bd55dfb.
  ///
  /// In en, this message translates to:
  /// **'Name a speaker in a transcript to filter recordings.'**
  String get labeled245bd55dfb;

  /// No description provided for @labele9e7f40a9bdd.
  ///
  /// In en, this message translates to:
  /// **'Name speakers'**
  String get labele9e7f40a9bdd;

  /// No description provided for @label561e624aff7c.
  ///
  /// In en, this message translates to:
  /// **'Name speakers within each recording.'**
  String get label561e624aff7c;

  /// No description provided for @label3db65f8c2a7d.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get label3db65f8c2a7d;

  /// No description provided for @labeldb18382a249e.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get labeldb18382a249e;

  /// No description provided for @labelcf28f49ec597.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get labelcf28f49ec597;

  /// No description provided for @labelbfc1adc316f2.
  ///
  /// In en, this message translates to:
  /// **'New folder or note'**
  String get labelbfc1adc316f2;

  /// No description provided for @label1f054525307b.
  ///
  /// In en, this message translates to:
  /// **'New subfolder'**
  String get label1f054525307b;

  /// No description provided for @labela6c731830aa4.
  ///
  /// In en, this message translates to:
  /// **'New summary note'**
  String get labela6c731830aa4;

  /// No description provided for @label30d87ec45259.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get label30d87ec45259;

  /// No description provided for @label079c45af4c2e.
  ///
  /// In en, this message translates to:
  /// **'New unbound recorder'**
  String get label079c45af4c2e;

  /// No description provided for @labeldd00d3d3e9f7.
  ///
  /// In en, this message translates to:
  /// **'Next steps'**
  String get labeldd00d3d3e9f7;

  /// No description provided for @label5a97dc7c7d1d.
  ///
  /// In en, this message translates to:
  /// **'No chat history'**
  String get label5a97dc7c7d1d;

  /// No description provided for @labeld7e20271831b.
  ///
  /// In en, this message translates to:
  /// **'No files here'**
  String get labeld7e20271831b;

  /// No description provided for @labeldc628c03998f.
  ///
  /// In en, this message translates to:
  /// **'No local files'**
  String get labeldc628c03998f;

  /// No description provided for @label77161f8e007e.
  ///
  /// In en, this message translates to:
  /// **'No local recordings'**
  String get label77161f8e007e;

  /// No description provided for @labeleb82569d8230.
  ///
  /// In en, this message translates to:
  /// **'No matches found.'**
  String get labeleb82569d8230;

  /// No description provided for @labelaf10422f854c.
  ///
  /// In en, this message translates to:
  /// **'No notes added.'**
  String get labelaf10422f854c;

  /// No description provided for @label5e2f7f4186ca.
  ///
  /// In en, this message translates to:
  /// **'No options yet.'**
  String get label5e2f7f4186ca;

  /// No description provided for @label033f5cf82455.
  ///
  /// In en, this message translates to:
  /// **'No recordings here'**
  String get label033f5cf82455;

  /// No description provided for @labela43619f32117.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get labela43619f32117;

  /// No description provided for @label46d5c181199b.
  ///
  /// In en, this message translates to:
  /// **'No saved versions'**
  String get label46d5c181199b;

  /// No description provided for @labelb346b410d2d9.
  ///
  /// In en, this message translates to:
  /// **'No shared links'**
  String get labelb346b410d2d9;

  /// No description provided for @labeledc4df618f81.
  ///
  /// In en, this message translates to:
  /// **'No speaker labels are available for this transcript.'**
  String get labeledc4df618f81;

  /// No description provided for @label330456ef9c44.
  ///
  /// In en, this message translates to:
  /// **'No speech recognized'**
  String get label330456ef9c44;

  /// No description provided for @label506bbb53d801.
  ///
  /// In en, this message translates to:
  /// **'No templates here'**
  String get label506bbb53d801;

  /// No description provided for @labelff785ccc115e.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events'**
  String get labelff785ccc115e;

  /// No description provided for @label6cfd09061b65.
  ///
  /// In en, this message translates to:
  /// **'No verifiable source was included. Check this answer against your recordings.'**
  String get label6cfd09061b65;

  /// No description provided for @labeld8da2c49df39.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get labeld8da2c49df39;

  /// No description provided for @label92bb2996b9b2.
  ///
  /// In en, this message translates to:
  /// **'Note copied'**
  String get label92bb2996b9b2;

  /// No description provided for @labele20e2be082f2.
  ///
  /// In en, this message translates to:
  /// **'Note options'**
  String get labele20e2be082f2;

  /// No description provided for @label788011833a5a.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get label788011833a5a;

  /// No description provided for @label5e97833a594a.
  ///
  /// In en, this message translates to:
  /// **'Notify me when processing finishes. Requires Android notification permission.'**
  String get label5e97833a594a;

  /// No description provided for @labelf97da48734b6.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get labelf97da48734b6;

  /// No description provided for @label842fc3a912a6.
  ///
  /// In en, this message translates to:
  /// **'Open audio player'**
  String get label842fc3a912a6;

  /// No description provided for @label4190c0c7ec72.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get label4190c0c7ec72;

  /// No description provided for @labelfb799b7fc5ce.
  ///
  /// In en, this message translates to:
  /// **'Open note · Edit and versions'**
  String get labelfb799b7fc5ce;

  /// No description provided for @label44a915faf3a9.
  ///
  /// In en, this message translates to:
  /// **'Open original'**
  String get label44a915faf3a9;

  /// No description provided for @label6e00f5d853ef.
  ///
  /// In en, this message translates to:
  /// **'Open recording'**
  String get label6e00f5d853ef;

  /// No description provided for @label3e74fe245f58.
  ///
  /// In en, this message translates to:
  /// **'Open result'**
  String get label3e74fe245f58;

  /// No description provided for @labeldca1f6c209a2.
  ///
  /// In en, this message translates to:
  /// **'Open the file in another app, tap Share, then choose Teno.'**
  String get labeldca1f6c209a2;

  /// No description provided for @labelbb09a1532cc1.
  ///
  /// In en, this message translates to:
  /// **'Original 16-character key'**
  String get labelbb09a1532cc1;

  /// No description provided for @labelee9869fcea57.
  ///
  /// In en, this message translates to:
  /// **'Original local recordings, device keys and cloud files stay available.'**
  String get labelee9869fcea57;

  /// No description provided for @label89420fdb493e.
  ///
  /// In en, this message translates to:
  /// **'Original text'**
  String get label89420fdb493e;

  /// No description provided for @label0a30a815d67d.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get label0a30a815d67d;

  /// No description provided for @labele7cf3ef4f17c.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get labele7cf3ef4f17c;

  /// No description provided for @label858e4ba7a29f.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get label858e4ba7a29f;

  /// No description provided for @labelbb6591385f67.
  ///
  /// In en, this message translates to:
  /// **'Pause recording'**
  String get labelbb6591385f67;

  /// No description provided for @label02457c055802.
  ///
  /// In en, this message translates to:
  /// **'Pause transfer'**
  String get label02457c055802;

  /// No description provided for @labelf4e08fefef74.
  ///
  /// In en, this message translates to:
  /// **'Personalization'**
  String get labelf4e08fefef74;

  /// No description provided for @labela7c41425ec04.
  ///
  /// In en, this message translates to:
  /// **'Phone recordings: up to 54 minutes. JWD Bluetooth imports: up to 60 minutes / 100 MiB. Audio file imports: up to 120 minutes / 250 MiB.'**
  String get labela7c41425ec04;

  /// No description provided for @labeld84eebada93e.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get labeld84eebada93e;

  /// No description provided for @label5e3147ab51e0.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get label5e3147ab51e0;

  /// No description provided for @labelcf4166250b80.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get labelcf4166250b80;

  /// No description provided for @labela78afaff2fda.
  ///
  /// In en, this message translates to:
  /// **'Play or pause'**
  String get labela78afaff2fda;

  /// No description provided for @label12c3d3a920ad.
  ///
  /// In en, this message translates to:
  /// **'Play or pause audio'**
  String get label12c3d3a920ad;

  /// No description provided for @label67e0ddff71f2.
  ///
  /// In en, this message translates to:
  /// **'Play recording'**
  String get label67e0ddff71f2;

  /// No description provided for @labelafec2b22114c.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get labelafec2b22114c;

  /// No description provided for @label66962f72a088.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get label66962f72a088;

  /// No description provided for @labelf1af44ed881d.
  ///
  /// In en, this message translates to:
  /// **'Preparing transcript and summary'**
  String get labelf1af44ed881d;

  /// No description provided for @label1802b08513b6.
  ///
  /// In en, this message translates to:
  /// **'Preparing your answer…'**
  String get label1802b08513b6;

  /// No description provided for @label20581eb94b5f.
  ///
  /// In en, this message translates to:
  /// **'Preparing your note'**
  String get label20581eb94b5f;

  /// No description provided for @label0f454c73915f.
  ///
  /// In en, this message translates to:
  /// **'Preparing your summary'**
  String get label0f454c73915f;

  /// No description provided for @labelb44a7fc5628d.
  ///
  /// In en, this message translates to:
  /// **'Preparing your transcript'**
  String get labelb44a7fc5628d;

  /// No description provided for @label37c43ad41939.
  ///
  /// In en, this message translates to:
  /// **'Preview only. The complete audio is processed after recording.'**
  String get label37c43ad41939;

  /// No description provided for @label23333fe2d3d9.
  ///
  /// In en, this message translates to:
  /// **'Preview · Final transcript follows processing'**
  String get label23333fe2d3d9;

  /// No description provided for @label9348f5af2c55.
  ///
  /// In en, this message translates to:
  /// **'Previous versions and existing next steps are preserved.'**
  String get label9348f5af2c55;

  /// No description provided for @labelc63eb6720c6e.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get labelc63eb6720c6e;

  /// No description provided for @labelc8e3e92a62ec.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get labelc8e3e92a62ec;

  /// No description provided for @labela9e3bc208a09.
  ///
  /// In en, this message translates to:
  /// **'Processing and notifications'**
  String get labela9e3bc208a09;

  /// No description provided for @label63e7cb980e55.
  ///
  /// In en, this message translates to:
  /// **'Processing failed. Try again.'**
  String get label63e7cb980e55;

  /// No description provided for @labeld5fe69b8a1f3.
  ///
  /// In en, this message translates to:
  /// **'Processing notifications'**
  String get labeld5fe69b8a1f3;

  /// No description provided for @label35b901546886.
  ///
  /// In en, this message translates to:
  /// **'Processing your recording'**
  String get label35b901546886;

  /// No description provided for @label75767813e884.
  ///
  /// In en, this message translates to:
  /// **'Queued for upload'**
  String get label75767813e884;

  /// No description provided for @label5fa7aac5375c.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get label5fa7aac5375c;

  /// No description provided for @label451a35b8adb3.
  ///
  /// In en, this message translates to:
  /// **'Ready to summarize'**
  String get label451a35b8adb3;

  /// No description provided for @label7f2d46393e85.
  ///
  /// In en, this message translates to:
  /// **'Recap the key decisions'**
  String get label7f2d46393e85;

  /// No description provided for @labele0050e57eb70.
  ///
  /// In en, this message translates to:
  /// **'Receiving and verifying the complete recording. Originals stay on your recorder.'**
  String get labele0050e57eb70;

  /// No description provided for @label2ccfecbca101.
  ///
  /// In en, this message translates to:
  /// **'Recent chats'**
  String get label2ccfecbca101;

  /// No description provided for @label228c84b5a56e.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get label228c84b5a56e;

  /// No description provided for @label1e7cf8df9b6a.
  ///
  /// In en, this message translates to:
  /// **'Recently used'**
  String get label1e7cf8df9b6a;

  /// No description provided for @labelf7b07c386b9c.
  ///
  /// In en, this message translates to:
  /// **'Reconnect recorder'**
  String get labelf7b07c386b9c;

  /// No description provided for @label8343f2a64a3a.
  ///
  /// In en, this message translates to:
  /// **'Reconnect saved recorder'**
  String get label8343f2a64a3a;

  /// No description provided for @label3941c85fa102.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting does not start a recording. If Bluetooth disconnects, check the recorder before starting another recording.'**
  String get label3941c85fa102;

  /// No description provided for @labela571db058621.
  ///
  /// In en, this message translates to:
  /// **'Record with phone'**
  String get labela571db058621;

  /// No description provided for @labelb984d066f603.
  ///
  /// In en, this message translates to:
  /// **'Recorder'**
  String get labelb984d066f603;

  /// No description provided for @labelb41c60449af7.
  ///
  /// In en, this message translates to:
  /// **'Recorder & files'**
  String get labelb41c60449af7;

  /// No description provided for @label80e8dd1a5a05.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get label80e8dd1a5a05;

  /// No description provided for @labelae19bed1f3b2.
  ///
  /// In en, this message translates to:
  /// **'Recording highlights'**
  String get labelae19bed1f3b2;

  /// No description provided for @labelaeb3eba8a655.
  ///
  /// In en, this message translates to:
  /// **'Recording notes'**
  String get labelaeb3eba8a655;

  /// No description provided for @label024bd21625b8.
  ///
  /// In en, this message translates to:
  /// **'Recording options'**
  String get label024bd21625b8;

  /// No description provided for @labele7a814fbebf5.
  ///
  /// In en, this message translates to:
  /// **'Recording preferences'**
  String get labele7a814fbebf5;

  /// No description provided for @label65ac0c306d33.
  ///
  /// In en, this message translates to:
  /// **'Recording service unavailable'**
  String get label65ac0c306d33;

  /// No description provided for @labela858dbd960d1.
  ///
  /// In en, this message translates to:
  /// **'Recording service verified · Connect'**
  String get labela858dbd960d1;

  /// No description provided for @labelcf4a89857ca6.
  ///
  /// In en, this message translates to:
  /// **'Recording title'**
  String get labelcf4a89857ca6;

  /// No description provided for @label2ef4c842e6e8.
  ///
  /// In en, this message translates to:
  /// **'Recording unavailable'**
  String get label2ef4c842e6e8;

  /// No description provided for @labelfd24f4315ebf.
  ///
  /// In en, this message translates to:
  /// **'Recording with Teno'**
  String get labelfd24f4315ebf;

  /// No description provided for @label60c56d66a128.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get label60c56d66a128;

  /// No description provided for @label5ca7933473f1.
  ///
  /// In en, this message translates to:
  /// **'Recordings and imports are automatically kept on this phone.'**
  String get label5ca7933473f1;

  /// No description provided for @labelace48a7cb5b4.
  ///
  /// In en, this message translates to:
  /// **'Recordings will stay in your library.'**
  String get labelace48a7cb5b4;

  /// No description provided for @label889bdee49e27.
  ///
  /// In en, this message translates to:
  /// **'Refresh conversation'**
  String get label889bdee49e27;

  /// No description provided for @label45b14a89f746.
  ///
  /// In en, this message translates to:
  /// **'Refresh device status'**
  String get label45b14a89f746;

  /// No description provided for @label1651031bf58d.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get label1651031bf58d;

  /// No description provided for @label3064d79a295c.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get label3064d79a295c;

  /// No description provided for @label7249f19c9e4f.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get label7249f19c9e4f;

  /// No description provided for @label2ebcba962562.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get label2ebcba962562;

  /// No description provided for @label8382d317c1d5.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get label8382d317c1d5;

  /// No description provided for @labela76e13b98392.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get labela76e13b98392;

  /// No description provided for @labeld640c7421da0.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get labeld640c7421da0;

  /// No description provided for @label5939333e89a8.
  ///
  /// In en, this message translates to:
  /// **'Retry processing'**
  String get label5939333e89a8;

  /// No description provided for @labelc87dc5bbfea5.
  ///
  /// In en, this message translates to:
  /// **'Return to recording'**
  String get labelc87dc5bbfea5;

  /// No description provided for @label87e6d00bbf53.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get label87e6d00bbf53;

  /// No description provided for @label3d3b295854fe.
  ///
  /// In en, this message translates to:
  /// **'Revoke this link?'**
  String get label3d3b295854fe;

  /// No description provided for @labelf6f738d04392.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get labelf6f738d04392;

  /// No description provided for @label55559604fc68.
  ///
  /// In en, this message translates to:
  /// **'Save a favorite, create a template or choose another category.'**
  String get label55559604fc68;

  /// No description provided for @label4f4851e2cdef.
  ///
  /// In en, this message translates to:
  /// **'Save as note'**
  String get label4f4851e2cdef;

  /// No description provided for @label6d3f818d9f6a.
  ///
  /// In en, this message translates to:
  /// **'Save favorites or create your own.'**
  String get label6d3f818d9f6a;

  /// No description provided for @label20334a86c75a.
  ///
  /// In en, this message translates to:
  /// **'Save new version'**
  String get label20334a86c75a;

  /// No description provided for @label59bfdd6b2306.
  ///
  /// In en, this message translates to:
  /// **'Save or share through your phone’s share menu.'**
  String get label59bfdd6b2306;

  /// No description provided for @label47f72a2f3e91.
  ///
  /// In en, this message translates to:
  /// **'Save template'**
  String get label47f72a2f3e91;

  /// No description provided for @label7ae75ed463cf.
  ///
  /// In en, this message translates to:
  /// **'Saved copy · Checking for updates…'**
  String get label7ae75ed463cf;

  /// No description provided for @labelc9603da9e5ad.
  ///
  /// In en, this message translates to:
  /// **'Saved copy · Could not check for updates'**
  String get labelc9603da9e5ad;

  /// No description provided for @label75010cd58573.
  ///
  /// In en, this message translates to:
  /// **'Saved in this browser'**
  String get label75010cd58573;

  /// No description provided for @label4c03b51d6368.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone'**
  String get label4c03b51d6368;

  /// No description provided for @label951db04b82b5.
  ///
  /// In en, this message translates to:
  /// **'Saved recorder · Connect'**
  String get label951db04b82b5;

  /// No description provided for @labelf15ef1a2514d.
  ///
  /// In en, this message translates to:
  /// **'Saving recording'**
  String get labelf15ef1a2514d;

  /// No description provided for @labelcbe16e470ef0.
  ///
  /// In en, this message translates to:
  /// **'Saving to this phone'**
  String get labelcbe16e470ef0;

  /// No description provided for @label23e39291d613.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get label23e39291d613;

  /// No description provided for @label38d96da6e8b2.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get label38d96da6e8b2;

  /// No description provided for @label04b9835b977e.
  ///
  /// In en, this message translates to:
  /// **'Search templates'**
  String get label04b9835b977e;

  /// No description provided for @label0ca59a709d65.
  ///
  /// In en, this message translates to:
  /// **'Search titles and transcripts.'**
  String get label0ca59a709d65;

  /// No description provided for @label088f0ac49c96.
  ///
  /// In en, this message translates to:
  /// **'Search your recordings'**
  String get label088f0ac49c96;

  /// No description provided for @label2a78025de6aa.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get label2a78025de6aa;

  /// No description provided for @labeld1156d07ca4e.
  ///
  /// In en, this message translates to:
  /// **'Select a template'**
  String get labeld1156d07ca4e;

  /// No description provided for @labelb43ba3e02667.
  ///
  /// In en, this message translates to:
  /// **'Select recordings to merge.'**
  String get labelb43ba3e02667;

  /// No description provided for @labelf9086318ef13.
  ///
  /// In en, this message translates to:
  /// **'Select recordings, notes, documents or folders.'**
  String get labelf9086318ef13;

  /// No description provided for @labelec075128ebd3.
  ///
  /// In en, this message translates to:
  /// **'Send question'**
  String get labelec075128ebd3;

  /// No description provided for @label485ad1a4f6b7.
  ///
  /// In en, this message translates to:
  /// **'Separate speakers'**
  String get label485ad1a4f6b7;

  /// No description provided for @labelaef7de28d529.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get labelaef7de28d529;

  /// No description provided for @label3e8fb11efc9e.
  ///
  /// In en, this message translates to:
  /// **'Server settings'**
  String get label3e8fb11efc9e;

  /// No description provided for @label29887a5ff984.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get label29887a5ff984;

  /// No description provided for @label63ff62289eca.
  ///
  /// In en, this message translates to:
  /// **'Share answer'**
  String get label63ff62289eca;

  /// No description provided for @label712a4823ccb9.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get label712a4823ccb9;

  /// No description provided for @labelf40b09a5b798.
  ///
  /// In en, this message translates to:
  /// **'Share recording'**
  String get labelf40b09a5b798;

  /// No description provided for @label44266fb49f67.
  ///
  /// In en, this message translates to:
  /// **'Share with link'**
  String get label44266fb49f67;

  /// No description provided for @labele3c4b39d6d50.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get labele3c4b39d6d50;

  /// No description provided for @label2e3ac056d490.
  ///
  /// In en, this message translates to:
  /// **'Shared links'**
  String get label2e3ac056d490;

  /// No description provided for @label3dcf3d16dd02.
  ///
  /// In en, this message translates to:
  /// **'Shared with Teno'**
  String get label3dcf3d16dd02;

  /// No description provided for @labelbfd402b2f6f3.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get labelbfd402b2f6f3;

  /// No description provided for @label22e58a62e3f4.
  ///
  /// In en, this message translates to:
  /// **'Sign in to its account or check local storage.'**
  String get label22e58a62e3f4;

  /// No description provided for @labelc80526e65f78.
  ///
  /// In en, this message translates to:
  /// **'Sign in to record'**
  String get labelc80526e65f78;

  /// No description provided for @label11aa3c02e39a.
  ///
  /// In en, this message translates to:
  /// **'Sign in to the recording’s account to access its local file.'**
  String get label11aa3c02e39a;

  /// No description provided for @label47e82476c5c4.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your Teno account.'**
  String get label47e82476c5c4;

  /// No description provided for @label48f0d3d397d4.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get label48f0d3d397d4;

  /// No description provided for @labelc1c084addfcc.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get labelc1c084addfcc;

  /// No description provided for @label8b9d3de8ae00.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get label8b9d3de8ae00;

  /// No description provided for @label722173bdafb0.
  ///
  /// In en, this message translates to:
  /// **'Sort and select'**
  String get label722173bdafb0;

  /// No description provided for @label75b95987156e.
  ///
  /// In en, this message translates to:
  /// **'Sort search results'**
  String get label75b95987156e;

  /// No description provided for @labelcaf85b0888d7.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get labelcaf85b0888d7;

  /// No description provided for @labela9e0c7058512.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get labela9e0c7058512;

  /// No description provided for @label6d2a3d905d65.
  ///
  /// In en, this message translates to:
  /// **'Speaker labels'**
  String get label6d2a3d905d65;

  /// No description provided for @labelc92a7237efe6.
  ///
  /// In en, this message translates to:
  /// **'Speakers'**
  String get labelc92a7237efe6;

  /// No description provided for @label278f200e0954.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation about your files.'**
  String get label278f200e0954;

  /// No description provided for @labelcae7d57bc067.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get labelcae7d57bc067;

  /// No description provided for @labelcfa16e25a1b7.
  ///
  /// In en, this message translates to:
  /// **'Stop following audio'**
  String get labelcfa16e25a1b7;

  /// No description provided for @label576b015da398.
  ///
  /// In en, this message translates to:
  /// **'Stop recording?'**
  String get label576b015da398;

  /// No description provided for @label1ff87776e254.
  ///
  /// In en, this message translates to:
  /// **'Stop upload'**
  String get label1ff87776e254;

  /// No description provided for @labela69c4dece144.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get labela69c4dece144;

  /// No description provided for @label87b46d07344a.
  ///
  /// In en, this message translates to:
  /// **'Summarize the key decisions'**
  String get label87b46d07344a;

  /// No description provided for @label8e76a94ac832.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get label8e76a94ac832;

  /// No description provided for @label897f93c2a3b8.
  ///
  /// In en, this message translates to:
  /// **'Summary instructions'**
  String get label897f93c2a3b8;

  /// No description provided for @label69427a25853c.
  ///
  /// In en, this message translates to:
  /// **'Summary language'**
  String get label69427a25853c;

  /// No description provided for @label7530b89a4c88.
  ///
  /// In en, this message translates to:
  /// **'Summary template'**
  String get label7530b89a4c88;

  /// No description provided for @label062bcea801e1.
  ///
  /// In en, this message translates to:
  /// **'Summary unavailable'**
  String get label062bcea801e1;

  /// No description provided for @label0d681ad655bb.
  ///
  /// In en, this message translates to:
  /// **'Summary versions'**
  String get label0d681ad655bb;

  /// No description provided for @labele2d55694b6a7.
  ///
  /// In en, this message translates to:
  /// **'Supported files'**
  String get labele2d55694b6a7;

  /// No description provided for @label16d7372e3162.
  ///
  /// In en, this message translates to:
  /// **'Switch to Edited text to make changes. The original stays unchanged.'**
  String get label16d7372e3162;

  /// No description provided for @label5f905992d185.
  ///
  /// In en, this message translates to:
  /// **'Sync recordings to this phone'**
  String get label5f905992d185;

  /// No description provided for @label7b905ed0eaf2.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get label7b905ed0eaf2;

  /// No description provided for @label1ad5d815ceef.
  ///
  /// In en, this message translates to:
  /// **'Template options'**
  String get label1ad5d815ceef;

  /// No description provided for @label56b564b75c7f.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get label56b564b75c7f;

  /// No description provided for @label1e43824cfa40.
  ///
  /// In en, this message translates to:
  /// **'Teno Web preview'**
  String get label1e43824cfa40;

  /// No description provided for @label971dc8d18395.
  ///
  /// In en, this message translates to:
  /// **'Teno account'**
  String get label971dc8d18395;

  /// No description provided for @label2504d9c7417d.
  ///
  /// In en, this message translates to:
  /// **'The action could not be completed. Try again.'**
  String get label2504d9c7417d;

  /// No description provided for @label0852dd932048.
  ///
  /// In en, this message translates to:
  /// **'The answer could not be generated.'**
  String get label0852dd932048;

  /// No description provided for @label1074f8d0c278.
  ///
  /// In en, this message translates to:
  /// **'The cloud content will stay in your library.'**
  String get label1074f8d0c278;

  /// No description provided for @labelef525ba5f521.
  ///
  /// In en, this message translates to:
  /// **'The cloud recording will stay in your library.'**
  String get labelef525ba5f521;

  /// No description provided for @labelc15e0ed239f9.
  ///
  /// In en, this message translates to:
  /// **'The complete audio file stays on this phone.'**
  String get labelc15e0ed239f9;

  /// No description provided for @label9fedf65e0ac5.
  ///
  /// In en, this message translates to:
  /// **'The complete audio remains available to play.'**
  String get label9fedf65e0ac5;

  /// No description provided for @labelbc9c04e2af0b.
  ///
  /// In en, this message translates to:
  /// **'The complete file is checked before it is saved and uploaded. Originals stay on your recorder.'**
  String get labelbc9c04e2af0b;

  /// No description provided for @labeld87528954e3a.
  ///
  /// In en, this message translates to:
  /// **'The complete recording will be saved on this phone. Your cloud processing preference will apply.'**
  String get labeld87528954e3a;

  /// No description provided for @label8f16804b7f33.
  ///
  /// In en, this message translates to:
  /// **'The current note is available on this page.'**
  String get label8f16804b7f33;

  /// No description provided for @label5a6ad55a1421.
  ///
  /// In en, this message translates to:
  /// **'The source transcript has changed. This note retains its earlier version.'**
  String get label5a6ad55a1421;

  /// No description provided for @label785bd7747acd.
  ///
  /// In en, this message translates to:
  /// **'The transcript has changed since this summary was generated.'**
  String get label785bd7747acd;

  /// No description provided for @labelf033a57053af.
  ///
  /// In en, this message translates to:
  /// **'The transcript has changed. This note retains its earlier version.'**
  String get labelf033a57053af;

  /// No description provided for @labelefb52e7172b7.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get labelefb52e7172b7;

  /// No description provided for @label281a1ea9ebc2.
  ///
  /// In en, this message translates to:
  /// **'This answer is taking longer. Refresh this conversation to check again.'**
  String get label281a1ea9ebc2;

  /// No description provided for @label663517e589cf.
  ///
  /// In en, this message translates to:
  /// **'This file has not been uploaded. Its local copy will be permanently deleted.'**
  String get label663517e589cf;

  /// No description provided for @labelc29cd21b0ce4.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the cloud recording and its results.'**
  String get labelc29cd21b0ce4;

  /// No description provided for @label3c12c196ecfa.
  ///
  /// In en, this message translates to:
  /// **'This recording has not been uploaded. Its local audio will be permanently deleted.'**
  String get label3c12c196ecfa;

  /// No description provided for @labeld5f64f34a299.
  ///
  /// In en, this message translates to:
  /// **'This recording is no longer available.'**
  String get labeld5f64f34a299;

  /// No description provided for @labelb519667d4c17.
  ///
  /// In en, this message translates to:
  /// **'This removes the event from Teno. Your phone calendar is unchanged.'**
  String get labelb519667d4c17;

  /// No description provided for @labelec2d8412977b.
  ///
  /// In en, this message translates to:
  /// **'This removes the selected cloud content and its shared links. Local copies stay on this phone.'**
  String get labelec2d8412977b;

  /// No description provided for @label755f099dbf49.
  ///
  /// In en, this message translates to:
  /// **'Timestamps'**
  String get label755f099dbf49;

  /// No description provided for @label7e8cd2056da7.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get label7e8cd2056da7;

  /// No description provided for @label2b065c7c9ce4.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get label2b065c7c9ce4;

  /// No description provided for @labelea93d6a262ec.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get labelea93d6a262ec;

  /// No description provided for @labelfe69a43d8568.
  ///
  /// In en, this message translates to:
  /// **'Transcribe again'**
  String get labelfe69a43d8568;

  /// No description provided for @label9ee39146dee1.
  ///
  /// In en, this message translates to:
  /// **'Transcribe again?'**
  String get label9ee39146dee1;

  /// No description provided for @label721164f0dc70.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get label721164f0dc70;

  /// No description provided for @label4a2f872776b1.
  ///
  /// In en, this message translates to:
  /// **'Transcript actions'**
  String get label4a2f872776b1;

  /// No description provided for @label2eeff6f159ed.
  ///
  /// In en, this message translates to:
  /// **'Transcript excerpt'**
  String get label2eeff6f159ed;

  /// No description provided for @label441836b87229.
  ///
  /// In en, this message translates to:
  /// **'Transcript is being prepared'**
  String get label441836b87229;

  /// No description provided for @labelc304d04ca0b6.
  ///
  /// In en, this message translates to:
  /// **'Transcript version'**
  String get labelc304d04ca0b6;

  /// No description provided for @label8bc7ce62eec1.
  ///
  /// In en, this message translates to:
  /// **'Transcription & summary'**
  String get label8bc7ce62eec1;

  /// No description provided for @labelc560122ac470.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get labelc560122ac470;

  /// No description provided for @label52a78027bdd9.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get label52a78027bdd9;

  /// No description provided for @labelaa877d97e3f2.
  ///
  /// In en, this message translates to:
  /// **'Trim audio'**
  String get labelaa877d97e3f2;

  /// No description provided for @labele38240ff7d06.
  ///
  /// In en, this message translates to:
  /// **'Trim range · start,end in seconds'**
  String get labele38240ff7d06;

  /// No description provided for @labele54a1a0afd40.
  ///
  /// In en, this message translates to:
  /// **'Try a different word or phrase.'**
  String get labele54a1a0afd40;

  /// No description provided for @labelb4084a52d9d2.
  ///
  /// In en, this message translates to:
  /// **'Try another word or adjust your filters.'**
  String get labelb4084a52d9d2;

  /// No description provided for @labelbaaddf70fb5d.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get labelbaaddf70fb5d;

  /// No description provided for @label849a11b7a0fb.
  ///
  /// In en, this message translates to:
  /// **'Type main ideas'**
  String get label849a11b7a0fb;

  /// No description provided for @label63e39c39bfbb.
  ///
  /// In en, this message translates to:
  /// **'Type note'**
  String get label63e39c39bfbb;

  /// No description provided for @label325ffdb1396d.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized device · Check recording service'**
  String get label325ffdb1396d;

  /// No description provided for @labelf59ab8d1331b.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get labelf59ab8d1331b;

  /// No description provided for @labele93736573a33.
  ///
  /// In en, this message translates to:
  /// **'Untitled note'**
  String get labele93736573a33;

  /// No description provided for @label567fb2d64a3d.
  ///
  /// In en, this message translates to:
  /// **'Untitled recording'**
  String get label567fb2d64a3d;

  /// No description provided for @labelc26ea11155cf.
  ///
  /// In en, this message translates to:
  /// **'Upload and process'**
  String get labelc26ea11155cf;

  /// No description provided for @labelaedad2135947.
  ///
  /// In en, this message translates to:
  /// **'Upload needs attention'**
  String get labelaedad2135947;

  /// No description provided for @label3c414b7123b8.
  ///
  /// In en, this message translates to:
  /// **'Upload on Wi-Fi only'**
  String get label3c414b7123b8;

  /// No description provided for @labeld541bdf9758b.
  ///
  /// In en, this message translates to:
  /// **'Upload saved files'**
  String get labeld541bdf9758b;

  /// No description provided for @label8b898ca34ce7.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get label8b898ca34ce7;

  /// No description provided for @label65189a29b993.
  ///
  /// In en, this message translates to:
  /// **'Uploading. Keep this tab open until upload finishes.'**
  String get label65189a29b993;

  /// No description provided for @labelb16a23ba57f3.
  ///
  /// In en, this message translates to:
  /// **'Use original key'**
  String get labelb16a23ba57f3;

  /// No description provided for @label82dbedf99ae9.
  ///
  /// In en, this message translates to:
  /// **'Use the menu to connect your calendar or add an event.'**
  String get label82dbedf99ae9;

  /// No description provided for @label1a439ee577c7.
  ///
  /// In en, this message translates to:
  /// **'Use this template'**
  String get label1a439ee577c7;

  /// No description provided for @label467e685ec21a.
  ///
  /// In en, this message translates to:
  /// **'Use your existing Teno account. Library, transcripts, summaries, templates and Ask share the same cloud data as the app.'**
  String get label467e685ec21a;

  /// No description provided for @labeleb4b0ba0995a.
  ///
  /// In en, this message translates to:
  /// **'Use your phone’s screen lock to open Teno.'**
  String get labeleb4b0ba0995a;

  /// No description provided for @labele3b89e9d33f8.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get labele3b89e9d33f8;

  /// No description provided for @labeldd167905de0d.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get labeldd167905de0d;

  /// No description provided for @labela6df11e706c5.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get labela6df11e706c5;

  /// No description provided for @label6ee818aa2de3.
  ///
  /// In en, this message translates to:
  /// **'View source'**
  String get label6ee818aa2de3;

  /// No description provided for @label8748f23993a8.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get label8748f23993a8;

  /// No description provided for @label9e320fd47505.
  ///
  /// In en, this message translates to:
  /// **'Waiting for recorder'**
  String get label9e320fd47505;

  /// No description provided for @labelcf7ca0c9fd5d.
  ///
  /// In en, this message translates to:
  /// **'Waiting to upload'**
  String get labelcf7ca0c9fd5d;

  /// No description provided for @labelcaf8ca93250b.
  ///
  /// In en, this message translates to:
  /// **'What are the next steps?'**
  String get labelcaf8ca93250b;

  /// No description provided for @labelee3986c25932.
  ///
  /// In en, this message translates to:
  /// **'What should I follow up on?'**
  String get labelee3986c25932;

  /// No description provided for @label7b3091d59ac7.
  ///
  /// In en, this message translates to:
  /// **'What would you like to know?'**
  String get label7b3091d59ac7;

  /// No description provided for @label87bb59ba2f92.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get label87bb59ba2f92;

  /// No description provided for @label28fbf97242b1.
  ///
  /// In en, this message translates to:
  /// **'Write your note…'**
  String get label28fbf97242b1;

  /// No description provided for @labelfe1bb9b9b4d7.
  ///
  /// In en, this message translates to:
  /// **'You can leave this page while processing continues.'**
  String get labelfe1bb9b9b4d7;

  /// No description provided for @label42dcdde2fdda.
  ///
  /// In en, this message translates to:
  /// **'You can leave this page. Processing continues in the background.'**
  String get label42dcdde2fdda;

  /// No description provided for @label69a45f93d227.
  ///
  /// In en, this message translates to:
  /// **'You can restore this cloud recording from Trash.'**
  String get label69a45f93d227;

  /// No description provided for @label99bff501c410.
  ///
  /// In en, this message translates to:
  /// **'You can restore this recording from Trash.'**
  String get label99bff501c410;

  /// No description provided for @label11ae56a716fc.
  ///
  /// In en, this message translates to:
  /// **'Your audio remains available.'**
  String get label11ae56a716fc;

  /// No description provided for @labelf20283e2f772.
  ///
  /// In en, this message translates to:
  /// **'Your brief'**
  String get labelf20283e2f772;

  /// No description provided for @label066bb7662174.
  ///
  /// In en, this message translates to:
  /// **'Your brief will appear here when a note is ready.'**
  String get label066bb7662174;

  /// No description provided for @labelaa9ebfad71c7.
  ///
  /// In en, this message translates to:
  /// **'Your existing Teno account'**
  String get labelaa9ebfad71c7;

  /// No description provided for @label55576676783c.
  ///
  /// In en, this message translates to:
  /// **'Your notes'**
  String get label55576676783c;

  /// No description provided for @label2fb2d67edf83.
  ///
  /// In en, this message translates to:
  /// **'Your question is saved. Retry when ready.'**
  String get label2fb2d67edf83;

  /// No description provided for @label5b8980b8296a.
  ///
  /// In en, this message translates to:
  /// **'Your recorder'**
  String get label5b8980b8296a;

  /// No description provided for @labelc390405502f1.
  ///
  /// In en, this message translates to:
  /// **'Your recordings and imports are automatically kept here.'**
  String get labelc390405502f1;

  /// No description provided for @labelae0ea9dc7f8c.
  ///
  /// In en, this message translates to:
  /// **'Your recordings start here'**
  String get labelae0ea9dc7f8c;

  /// No description provided for @labelbc183962239b.
  ///
  /// In en, this message translates to:
  /// **'Your templates'**
  String get labelbc183962239b;

  /// No description provided for @label0ad1dcc94259.
  ///
  /// In en, this message translates to:
  /// **'A complete audio file is always kept on this phone. These choices are saved to this account on this device.'**
  String get label0ad1dcc94259;

  /// No description provided for @label200d05914172.
  ///
  /// In en, this message translates to:
  /// **'Android may delay background uploads and completion notifications. Reopen Teno to resume app work. Live text is a preview; final results use the complete recording.'**
  String get label200d05914172;

  /// No description provided for @label5098dcb4379e.
  ///
  /// In en, this message translates to:
  /// **'Audio and video: 120 minutes / 250 MiB. Images: 20 MB. Documents: 15 MB. Text: 2 MB. Calendar files: 1 MiB. Use unencrypted documents.'**
  String get label5098dcb4379e;

  /// No description provided for @label738e03c827d3.
  ///
  /// In en, this message translates to:
  /// **'Audio/video: 120 minutes / 250 MiB. Images (PNG/JPEG): 20 MB. Documents (PDF, Word, PowerPoint, MSG): 15 MB. Text/Markdown: 2 MB. Use unencrypted documents.'**
  String get label738e03c827d3;

  /// No description provided for @label938be793bada.
  ///
  /// In en, this message translates to:
  /// **'Selected files are saved in this browser for retry under their original account. Browser storage can be cleared or evicted; keep your original files. Sign in again to resume an interrupted upload.'**
  String get label938be793bada;

  /// No description provided for @labelc85f64f70b34.
  ///
  /// In en, this message translates to:
  /// **'Overview, key points and next steps'**
  String get labelc85f64f70b34;

  /// No description provided for @labelc4e33bbe61e6.
  ///
  /// In en, this message translates to:
  /// **'Change interface language without changing your recordings or generated content.'**
  String get labelc4e33bbe61e6;

  /// No description provided for @label15f98a3794f0.
  ///
  /// In en, this message translates to:
  /// **'Your conversations,\nyour clarity.'**
  String get label15f98a3794f0;

  /// No description provided for @labelf40d7f51f69e.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get labelf40d7f51f69e;

  /// No description provided for @labeld1eb39b09bf5.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get labeld1eb39b09bf5;

  /// No description provided for @label58339f45df96.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get label58339f45df96;

  /// No description provided for @label7da11212ed34.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get label7da11212ed34;

  /// No description provided for @label66dab40cea1d.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get label66dab40cea1d;

  /// No description provided for @labelfdeb71b569e0.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get labelfdeb71b569e0;

  /// No description provided for @labeldb18f17fe532.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get labeldb18f17fe532;

  /// No description provided for @label5c5db120cb11.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get label5c5db120cb11;

  /// No description provided for @labelcaf71b3f582d.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get labelcaf71b3f582d;

  /// No description provided for @labelb4b7d3818dbf.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get labelb4b7d3818dbf;

  /// No description provided for @label617531b4fec3.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get label617531b4fec3;

  /// No description provided for @label8c78fe5b9936.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get label8c78fe5b9936;

  /// No description provided for @labelb27fd46ed1b6.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get labelb27fd46ed1b6;

  /// No description provided for @labelc43f56b9807e.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get labelc43f56b9807e;

  /// No description provided for @label41e1d82aa990.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get label41e1d82aa990;

  /// No description provided for @label451e2b719061.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get label451e2b719061;

  /// No description provided for @label6877e8494c3a.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get label6877e8494c3a;

  /// No description provided for @label3e630d2964a0.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get label3e630d2964a0;

  /// No description provided for @labelf2a0cfbcf191.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get labelf2a0cfbcf191;

  /// No description provided for @labeld98eb49ceb4b.
  ///
  /// In en, this message translates to:
  /// **'Teno · Saving recording'**
  String get labeld98eb49ceb4b;

  /// No description provided for @label71469cab82c6.
  ///
  /// In en, this message translates to:
  /// **'Teno · Recording paused'**
  String get label71469cab82c6;

  /// No description provided for @label331d2129ed6b.
  ///
  /// In en, this message translates to:
  /// **'Teno · Recording'**
  String get label331d2129ed6b;

  /// No description provided for @label145ee0765c43.
  ///
  /// In en, this message translates to:
  /// **'Audio is saved on this phone.'**
  String get label145ee0765c43;

  /// No description provided for @label6be804aeece9.
  ///
  /// In en, this message translates to:
  /// **'Stop and save'**
  String get label6be804aeece9;

  /// No description provided for @label57bb71e63419.
  ///
  /// In en, this message translates to:
  /// **'Uploads and processing'**
  String get label57bb71e63419;

  /// No description provided for @label4d1e89c3f939.
  ///
  /// In en, this message translates to:
  /// **'Recorder connection'**
  String get label4d1e89c3f939;

  /// No description provided for @label1fe47a729aaf.
  ///
  /// In en, this message translates to:
  /// **'Teno · Recorder'**
  String get label1fe47a729aaf;

  /// No description provided for @labelc2bc6d5282a7.
  ///
  /// In en, this message translates to:
  /// **'Teno · Syncing recordings'**
  String get labelc2bc6d5282a7;

  /// No description provided for @labeld14b24f9ebe0.
  ///
  /// In en, this message translates to:
  /// **'Teno · Reminder'**
  String get labeld14b24f9ebe0;

  /// No description provided for @label3701e28787a3.
  ///
  /// In en, this message translates to:
  /// **'Speak your question'**
  String get label3701e28787a3;

  /// No description provided for @label24cd990fcc96.
  ///
  /// In en, this message translates to:
  /// **'Up to 60 seconds. You can edit the text before sending.'**
  String get label24cd990fcc96;

  /// No description provided for @label3cfcdc5d210b.
  ///
  /// In en, this message translates to:
  /// **'Export from Teno'**
  String get label3cfcdc5d210b;

  /// No description provided for @label8ab78c95bb63.
  ///
  /// In en, this message translates to:
  /// **'Share from Teno'**
  String get label8ab78c95bb63;

  /// No description provided for @label60baea44888e.
  ///
  /// In en, this message translates to:
  /// **'Processing · Local copy kept'**
  String get label60baea44888e;

  /// No description provided for @labelf79ec89e7d95.
  ///
  /// In en, this message translates to:
  /// **'Upload paused · Local copy kept'**
  String get labelf79ec89e7d95;

  /// No description provided for @label0303e1824670.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get label0303e1824670;

  /// No description provided for @label0b4bb3eed1bb.
  ///
  /// In en, this message translates to:
  /// **'Not received'**
  String get label0b4bb3eed1bb;

  /// No description provided for @label9c1f7ff256de.
  ///
  /// In en, this message translates to:
  /// **'Recorder service'**
  String get label9c1f7ff256de;

  /// No description provided for @labelb18237558cf3.
  ///
  /// In en, this message translates to:
  /// **'Recorder is recording'**
  String get labelb18237558cf3;

  /// No description provided for @labela4348acc6d9c.
  ///
  /// In en, this message translates to:
  /// **'Recording paused'**
  String get labela4348acc6d9c;

  /// No description provided for @label02acf8170c9a.
  ///
  /// In en, this message translates to:
  /// **'Receiving audio over Bluetooth'**
  String get label02acf8170c9a;

  /// No description provided for @label570d8b1483dd.
  ///
  /// In en, this message translates to:
  /// **'Saved on recorder · Syncing to this phone'**
  String get label570d8b1483dd;

  /// No description provided for @label944daea70213.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the recorder to finish saving…'**
  String get label944daea70213;

  /// No description provided for @labelb18eeb0d43f6.
  ///
  /// In en, this message translates to:
  /// **'Compatibility scan · 15 seconds'**
  String get labelb18eeb0d43f6;

  /// No description provided for @labele2d7f6d7f18b.
  ///
  /// In en, this message translates to:
  /// **'Scanning · Keep the recorder available for connection'**
  String get labele2d7f6d7f18b;

  /// No description provided for @label15fd3168e6c2.
  ///
  /// In en, this message translates to:
  /// **'No recorder found. Wake the recorder and close other recorder apps, then try again.'**
  String get label15fd3168e6c2;

  /// No description provided for @labelabad6f3dc147.
  ///
  /// In en, this message translates to:
  /// **'Scan complete. Verify the service before connecting.'**
  String get labelabad6f3dc147;

  /// No description provided for @label196574e3aa9c.
  ///
  /// In en, this message translates to:
  /// **'Disconnected. Check the recorder: it may still be recording.'**
  String get label196574e3aa9c;

  /// No description provided for @labela610dc54b358.
  ///
  /// In en, this message translates to:
  /// **'Sync paused. Originals stay on the recorder. Reconnect to try again.'**
  String get labela610dc54b358;

  /// No description provided for @labeleec2b22a86dc.
  ///
  /// In en, this message translates to:
  /// **'Device key not accepted. Enter the original 16-character key, or check Recorder help before resetting the device.'**
  String get labeleec2b22a86dc;

  /// No description provided for @label0cc1ba39d071.
  ///
  /// In en, this message translates to:
  /// **'Saved on recorder. Sign in and set recording preferences to sync automatically.'**
  String get label0cc1ba39d071;

  /// No description provided for @labelcf2759aff016.
  ///
  /// In en, this message translates to:
  /// **'Permission was not granted. Enable it in Android Settings to use this feature.'**
  String get labelcf2759aff016;

  /// No description provided for @labelfc25221a1fc1.
  ///
  /// In en, this message translates to:
  /// **'Finish the current permission request first.'**
  String get labelfc25221a1fc1;

  /// No description provided for @labelca44e25205d6.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access in Android Settings.'**
  String get labelca44e25205d6;

  /// No description provided for @label533f1648108c.
  ///
  /// In en, this message translates to:
  /// **'No audio received from recorder'**
  String get label533f1648108c;

  /// No description provided for @label2a0b3310ed0f.
  ///
  /// In en, this message translates to:
  /// **'Live preview is off'**
  String get label2a0b3310ed0f;

  /// No description provided for @labeld403c686f6a1.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get labeld403c686f6a1;

  /// No description provided for @label22965568d22a.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get label22965568d22a;

  /// No description provided for @label04dfac3671b4.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get label04dfac3671b4;

  /// No description provided for @label7971dd752669.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get label7971dd752669;

  /// No description provided for @fullMeetingNotes.
  ///
  /// In en, this message translates to:
  /// **'Full meeting notes'**
  String get fullMeetingNotes;

  /// No description provided for @fullNoteVersion.
  ///
  /// In en, this message translates to:
  /// **'Full note · v{version}'**
  String fullNoteVersion(String version);

  /// No description provided for @label548dc526803d.
  ///
  /// In en, this message translates to:
  /// **'Scan for recorders'**
  String get label548dc526803d;

  /// No description provided for @label2d56922b543d.
  ///
  /// In en, this message translates to:
  /// **'Any folder'**
  String get label2d56922b543d;

  /// No description provided for @labelb05fc1fe6984.
  ///
  /// In en, this message translates to:
  /// **'Any type'**
  String get labelb05fc1fe6984;

  /// No description provided for @label73843394f5ee.
  ///
  /// In en, this message translates to:
  /// **'Any speaker'**
  String get label73843394f5ee;

  /// No description provided for @label0951734d8ac4.
  ///
  /// In en, this message translates to:
  /// **'Cleaned-up text'**
  String get label0951734d8ac4;

  /// No description provided for @otherDeviceCount.
  ///
  /// In en, this message translates to:
  /// **'Other Bluetooth devices ({count})'**
  String otherDeviceCount(int count);

  /// No description provided for @label7dcd94452308.
  ///
  /// In en, this message translates to:
  /// **'A fixed version is shared. Revoke links in Settings → Shared links.'**
  String get label7dcd94452308;

  /// No description provided for @label401584c4ad5b.
  ///
  /// In en, this message translates to:
  /// **'Copy transcript'**
  String get label401584c4ad5b;

  /// No description provided for @labele58a1a86879f.
  ///
  /// In en, this message translates to:
  /// **'Export files'**
  String get labele58a1a86879f;

  /// No description provided for @label758ba0c08150.
  ///
  /// In en, this message translates to:
  /// **'Transcript copied'**
  String get label758ba0c08150;

  /// No description provided for @label8876eaf42b3b.
  ///
  /// In en, this message translates to:
  /// **'Open the existing transcript without generating a new note.'**
  String get label8876eaf42b3b;

  /// No description provided for @dayCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 day} other {{count} days}}'**
  String dayCount(int count);

  /// No description provided for @label0c00c2a6d16e.
  ///
  /// In en, this message translates to:
  /// **'A complete copy stays on this phone after upload.'**
  String get label0c00c2a6d16e;

  /// No description provided for @labelc8e9021fd812.
  ///
  /// In en, this message translates to:
  /// **'A new transcript version will be generated from the complete audio.'**
  String get labelc8e9021fd812;

  /// No description provided for @label1118a899f7f2.
  ///
  /// In en, this message translates to:
  /// **'Teno device key'**
  String get label1118a899f7f2;

  /// No description provided for @label86f468a6b1d9.
  ///
  /// In en, this message translates to:
  /// **'Unlock to view your recorder\'s binding key.'**
  String get label86f468a6b1d9;

  /// No description provided for @labeled7d0390e6c9.
  ///
  /// In en, this message translates to:
  /// **'Keep this key private. It is needed to connect this recorder from another phone.'**
  String get labeled7d0390e6c9;

  /// No description provided for @label20bb8fece4b5.
  ///
  /// In en, this message translates to:
  /// **'Share Teno notes'**
  String get label20bb8fece4b5;

  /// No description provided for @labeldde65e3126c3.
  ///
  /// In en, this message translates to:
  /// **'Check the recorder service before saving a device key.'**
  String get labeldde65e3126c3;

  /// No description provided for @labelbcf0cd2bc357.
  ///
  /// In en, this message translates to:
  /// **'Finish recording and transfers before changing accounts.'**
  String get labelbcf0cd2bc357;

  /// No description provided for @labelb8d5ef9344ff.
  ///
  /// In en, this message translates to:
  /// **'Finish the current recording first.'**
  String get labelb8d5ef9344ff;

  /// No description provided for @label1f45e77f2c0c.
  ///
  /// In en, this message translates to:
  /// **'Finish the phone recording first.'**
  String get label1f45e77f2c0c;

  /// No description provided for @labelc43a281ad04f.
  ///
  /// In en, this message translates to:
  /// **'Invalid local recording.'**
  String get labelc43a281ad04f;

  /// No description provided for @labelfc576d907ff7.
  ///
  /// In en, this message translates to:
  /// **'Recording could not start. Open the app and try again.'**
  String get labelfc576d907ff7;

  /// No description provided for @label2bd2ab92015b.
  ///
  /// In en, this message translates to:
  /// **'Recording notes are too long.'**
  String get label2bd2ab92015b;

  /// No description provided for @labelaf8da0a68f14.
  ///
  /// In en, this message translates to:
  /// **'Sign in to this recording\'s account.'**
  String get labelaf8da0a68f14;

  /// No description provided for @label7fe5b32b587a.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your Teno account first.'**
  String get label7fe5b32b587a;

  /// No description provided for @label2d211ecaebe2.
  ///
  /// In en, this message translates to:
  /// **'Sign out before changing accounts.'**
  String get label2d211ecaebe2;

  /// No description provided for @labelc161ed9c9526.
  ///
  /// In en, this message translates to:
  /// **'There is no active phone recording.'**
  String get labelc161ed9c9526;

  /// No description provided for @label7afc8612d3d2.
  ///
  /// In en, this message translates to:
  /// **'This recorder already has a saved key.'**
  String get label7afc8612d3d2;

  /// No description provided for @label27d81c15395f.
  ///
  /// In en, this message translates to:
  /// **'Unsupported API request.'**
  String get label27d81c15395f;

  /// No description provided for @label6dd96f6320f1.
  ///
  /// In en, this message translates to:
  /// **'Wait for the active recording or upload to finish.'**
  String get label6dd96f6320f1;

  /// No description provided for @label268703d4af88.
  ///
  /// In en, this message translates to:
  /// **'Account changed. Import the file again.'**
  String get label268703d4af88;

  /// No description provided for @labelaf4e0f09019e.
  ///
  /// In en, this message translates to:
  /// **'Account changed. Open the export again.'**
  String get labelaf4e0f09019e;

  /// No description provided for @label2ddae4d82d4c.
  ///
  /// In en, this message translates to:
  /// **'Choose playable audio up to 120 minutes.'**
  String get label2ddae4d82d4c;

  /// No description provided for @label1a0c74b79fc2.
  ///
  /// In en, this message translates to:
  /// **'Finish the current device key request.'**
  String get label1a0c74b79fc2;

  /// No description provided for @label2395f9d173b3.
  ///
  /// In en, this message translates to:
  /// **'Finish the current import first.'**
  String get label2395f9d173b3;

  /// No description provided for @label419205d06a9d.
  ///
  /// In en, this message translates to:
  /// **'Invalid recording.'**
  String get label419205d06a9d;

  /// No description provided for @labele5a17d74835d.
  ///
  /// In en, this message translates to:
  /// **'No device key is saved.'**
  String get labele5a17d74835d;

  /// No description provided for @label6452bb49b9fd.
  ///
  /// In en, this message translates to:
  /// **'Playback request changed.'**
  String get label6452bb49b9fd;

  /// No description provided for @label1d00f99f5e44.
  ///
  /// In en, this message translates to:
  /// **'Screen-lock verification is unavailable.'**
  String get label1d00f99f5e44;

  /// No description provided for @label5fdfb782b25b.
  ///
  /// In en, this message translates to:
  /// **'Set a phone screen lock before viewing a device key.'**
  String get label5fdfb782b25b;

  /// No description provided for @label6977460770a2.
  ///
  /// In en, this message translates to:
  /// **'Supported formats: WAV, MP3, M4A, MP4 and OGG.'**
  String get label6977460770a2;

  /// No description provided for @label65d0add78333.
  ///
  /// In en, this message translates to:
  /// **'The import limit is 250 MiB.'**
  String get label65d0add78333;

  /// No description provided for @label686dfdbc0bd6.
  ///
  /// In en, this message translates to:
  /// **'The selected file is unavailable.'**
  String get label686dfdbc0bd6;

  /// No description provided for @label4eabe69bda69.
  ///
  /// In en, this message translates to:
  /// **'This audio could not be played.'**
  String get label4eabe69bda69;

  /// No description provided for @labela9b9f6f9c8bb.
  ///
  /// In en, this message translates to:
  /// **'Unsupported export.'**
  String get labela9b9f6f9c8bb;

  /// No description provided for @label1ac024f120c6.
  ///
  /// In en, this message translates to:
  /// **'Unsupported playback speed.'**
  String get label1ac024f120c6;

  /// No description provided for @labeld642f9d8fbbd.
  ///
  /// In en, this message translates to:
  /// **'Account changed during export.'**
  String get labeld642f9d8fbbd;

  /// No description provided for @labela69f32f2be19.
  ///
  /// In en, this message translates to:
  /// **'Account changed during import.'**
  String get labela69f32f2be19;

  /// No description provided for @labelaf589e0ed460.
  ///
  /// In en, this message translates to:
  /// **'Account changed during voice input.'**
  String get labelaf589e0ed460;

  /// No description provided for @label82cab6a7cf93.
  ///
  /// In en, this message translates to:
  /// **'Choose a file shared with read permission.'**
  String get label82cab6a7cf93;

  /// No description provided for @label4780fd8ca280.
  ///
  /// In en, this message translates to:
  /// **'Choose a supported audio, video, document or image file.'**
  String get label4780fd8ca280;

  /// No description provided for @label69f231493a92.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid image up to 25 megapixels.'**
  String get label69f231493a92;

  /// No description provided for @labeldfd6f617b710.
  ///
  /// In en, this message translates to:
  /// **'Choose audio or video up to 120 minutes.'**
  String get labeldfd6f617b710;

  /// No description provided for @label78bf8ff7bab7.
  ///
  /// In en, this message translates to:
  /// **'Finish phone recording before using voice input.'**
  String get label78bf8ff7bab7;

  /// No description provided for @labele10607ef7236.
  ///
  /// In en, this message translates to:
  /// **'Import up to 20 files at a time.'**
  String get labele10607ef7236;

  /// No description provided for @labelfaedf3084288.
  ///
  /// In en, this message translates to:
  /// **'Invalid export request.'**
  String get labelfaedf3084288;

  /// No description provided for @label412eadfa55af.
  ///
  /// In en, this message translates to:
  /// **'Invalid pending import.'**
  String get label412eadfa55af;

  /// No description provided for @label3249da300236.
  ///
  /// In en, this message translates to:
  /// **'Set a screen lock in Android Settings before enabling App lock.'**
  String get label3249da300236;

  /// No description provided for @labeld0bc2276463c.
  ///
  /// In en, this message translates to:
  /// **'Share up to 20 files at a time.'**
  String get labeld0bc2276463c;

  /// No description provided for @labelcdbfee510021.
  ///
  /// In en, this message translates to:
  /// **'The local copy is missing. Import the file again.'**
  String get labelcdbfee510021;

  /// No description provided for @label42eb27c3baf6.
  ///
  /// In en, this message translates to:
  /// **'The selected file is empty.'**
  String get label42eb27c3baf6;

  /// No description provided for @label6578f2c3deff.
  ///
  /// In en, this message translates to:
  /// **'The shared file is unavailable.'**
  String get label6578f2c3deff;

  /// No description provided for @label3eee87dc352b.
  ///
  /// In en, this message translates to:
  /// **'The shared item does not contain a file.'**
  String get label3eee87dc352b;

  /// No description provided for @label31efa9c0d5f1.
  ///
  /// In en, this message translates to:
  /// **'This file exceeds the import size limit.'**
  String get label31efa9c0d5f1;

  /// No description provided for @label3a5ad967765d.
  ///
  /// In en, this message translates to:
  /// **'This file has no supported audio track.'**
  String get label3a5ad967765d;

  /// No description provided for @label1bb4f67fef3a.
  ///
  /// In en, this message translates to:
  /// **'Unlock was cancelled.'**
  String get label1bb4f67fef3a;

  /// No description provided for @labela69fc6732df7.
  ///
  /// In en, this message translates to:
  /// **'Unsupported Android action.'**
  String get labela69fc6732df7;

  /// No description provided for @labele5c81a03c8e4.
  ///
  /// In en, this message translates to:
  /// **'No valid audio file found'**
  String get labele5c81a03c8e4;

  /// No description provided for @label8957795f2687.
  ///
  /// In en, this message translates to:
  /// **'Sign in to the recording\'s account.'**
  String get label8957795f2687;

  /// No description provided for @labelc27cda07904f.
  ///
  /// In en, this message translates to:
  /// **'The local recording is unavailable.'**
  String get labelc27cda07904f;

  /// No description provided for @label7160d98ed12a.
  ///
  /// In en, this message translates to:
  /// **'Upload is stopping. Try signing out again in a moment.'**
  String get label7160d98ed12a;

  /// No description provided for @label6e403d1365f7.
  ///
  /// In en, this message translates to:
  /// **'Audio saved, but its details could not be updated.'**
  String get label6e403d1365f7;

  /// No description provided for @labeld1497761ce3d.
  ///
  /// In en, this message translates to:
  /// **'Microphone interrupted. The saved audio has been kept.'**
  String get labeld1497761ce3d;

  /// No description provided for @labelfb7fabb3f59b.
  ///
  /// In en, this message translates to:
  /// **'Sign in before recording'**
  String get labelfb7fabb3f59b;

  /// No description provided for @label86a0a120d000.
  ///
  /// In en, this message translates to:
  /// **'The 54-minute recording limit was reached. Audio has been saved.'**
  String get label86a0a120d000;

  /// No description provided for @label6aacf8f7a4f4.
  ///
  /// In en, this message translates to:
  /// **'The microphone could not be opened'**
  String get label6aacf8f7a4f4;

  /// No description provided for @labelf77d844bd3e6.
  ///
  /// In en, this message translates to:
  /// **'Android requested Bluetooth pairing. Cancel the prompt and export diagnostics. This is separate from the device key.'**
  String get labelf77d844bd3e6;

  /// No description provided for @labelb4abac09ddaa.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is unavailable'**
  String get labelb4abac09ddaa;

  /// No description provided for @label2696acc675bb.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth scanning is unavailable'**
  String get label2696acc675bb;

  /// No description provided for @label12ccdafe98af.
  ///
  /// In en, this message translates to:
  /// **'Connect and authorize the recorder first'**
  String get label12ccdafe98af;

  /// No description provided for @label881358b23a3e.
  ///
  /// In en, this message translates to:
  /// **'Decoding audio…'**
  String get label881358b23a3e;

  /// No description provided for @label60be0d723450.
  ///
  /// In en, this message translates to:
  /// **'Device discovery could not start. Try again.'**
  String get label60be0d723450;

  /// No description provided for @labele6de9857d9de.
  ///
  /// In en, this message translates to:
  /// **'Device status is unknown. Refresh it first.'**
  String get labele6de9857d9de;

  /// No description provided for @label9a83d411be97.
  ///
  /// In en, this message translates to:
  /// **'Disconnect the current device or wait for verification to finish'**
  String get label9a83d411be97;

  /// No description provided for @labele3612e46803e.
  ///
  /// In en, this message translates to:
  /// **'File list is incomplete. Load it again.'**
  String get labele3612e46803e;

  /// No description provided for @label624978a9fdb9.
  ///
  /// In en, this message translates to:
  /// **'File received. Verifying and decoding audio…'**
  String get label624978a9fdb9;

  /// No description provided for @label6e10b5d9ac7c.
  ///
  /// In en, this message translates to:
  /// **'Finish or cancel the current transfer first'**
  String get label6e10b5d9ac7c;

  /// No description provided for @labelc84c53e325b9.
  ///
  /// In en, this message translates to:
  /// **'Folder list is incomplete. Refresh it.'**
  String get labelc84c53e325b9;

  /// No description provided for @label1d6fa934a135.
  ///
  /// In en, this message translates to:
  /// **'Invalid Bluetooth address'**
  String get label1d6fa934a135;

  /// No description provided for @label73f3b91129b4.
  ///
  /// In en, this message translates to:
  /// **'Not enough phone storage to receive and decode this file'**
  String get label73f3b91129b4;

  /// No description provided for @labela67fbae8b37e.
  ///
  /// In en, this message translates to:
  /// **'Recorder busy. Wait for the current action to finish.'**
  String get labela67fbae8b37e;

  /// No description provided for @label56293b946edb.
  ///
  /// In en, this message translates to:
  /// **'Recording has not been confirmed. Refresh device status.'**
  String get label56293b946edb;

  /// No description provided for @label99cb9dbb575f.
  ///
  /// In en, this message translates to:
  /// **'Recordings must be under 60 minutes. For a connection test, record 10–30 seconds.'**
  String get label99cb9dbb575f;

  /// No description provided for @label582e2241c5e0.
  ///
  /// In en, this message translates to:
  /// **'Refresh the device file list'**
  String get label582e2241c5e0;

  /// No description provided for @label6de22cdd3fbe.
  ///
  /// In en, this message translates to:
  /// **'Save a device key before connecting'**
  String get label6de22cdd3fbe;

  /// No description provided for @label3d0eedf458fb.
  ///
  /// In en, this message translates to:
  /// **'Sign in before syncing to this phone.'**
  String get label3d0eedf458fb;

  /// No description provided for @label4898fd2ce8a9.
  ///
  /// In en, this message translates to:
  /// **'Sign in first. Imported recordings are saved to that account on this phone.'**
  String get label4898fd2ce8a9;

  /// No description provided for @label8835e8dff9c4.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use live transcription.'**
  String get label8835e8dff9c4;

  /// No description provided for @labeld1ded7701d16.
  ///
  /// In en, this message translates to:
  /// **'Stop recording and refresh device status first'**
  String get labeld1ded7701d16;

  /// No description provided for @labele915c9021cf0.
  ///
  /// In en, this message translates to:
  /// **'The account changed. The original file was kept without adding it to another account.'**
  String get labele915c9021cf0;

  /// No description provided for @labeld39fe5ae8670.
  ///
  /// In en, this message translates to:
  /// **'The previous transcript is finishing. Try again shortly.'**
  String get labeld39fe5ae8670;

  /// No description provided for @labeld081d82e7bac.
  ///
  /// In en, this message translates to:
  /// **'Turn on Bluetooth'**
  String get labeld081d82e7bac;

  /// No description provided for @labelbf84d4f787ce.
  ///
  /// In en, this message translates to:
  /// **'Turn on Bluetooth first'**
  String get labelbf84d4f787ce;

  /// No description provided for @labeld7cf4941b136.
  ///
  /// In en, this message translates to:
  /// **'Wait for the decoded file to finish saving before disconnecting'**
  String get labeld7cf4941b136;

  /// No description provided for @label3380d425195b.
  ///
  /// In en, this message translates to:
  /// **'The network request failed. Check your connection and try again.'**
  String get label3380d425195b;

  /// No description provided for @label1b144c8c7d14.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Sign in again.'**
  String get label1b144c8c7d14;

  /// No description provided for @label1d1152d6d52f.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to this item.'**
  String get label1d1152d6d52f;

  /// No description provided for @label197c299e08a2.
  ///
  /// In en, this message translates to:
  /// **'This item is no longer available.'**
  String get label197c299e08a2;

  /// No description provided for @label5063fc19cf22.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Try again shortly.'**
  String get label5063fc19cf22;

  /// No description provided for @labelea44638d3340.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Try again later.'**
  String get labelea44638d3340;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @speakerLabel.
  ///
  /// In en, this message translates to:
  /// **'Speaker {name}'**
  String speakerLabel(String name);

  /// No description provided for @savedVersionDate.
  ///
  /// In en, this message translates to:
  /// **'Saved version · {date}'**
  String savedVersionDate(String date);

  /// No description provided for @labelb17d3954b0f0.
  ///
  /// In en, this message translates to:
  /// **'Account changed. Sign in and retry.'**
  String get labelb17d3954b0f0;

  /// No description provided for @label715d2af9f81b.
  ///
  /// In en, this message translates to:
  /// **'Audio could not be loaded. Retry playback.'**
  String get label715d2af9f81b;

  /// No description provided for @labelf7c4df5ebfc0.
  ///
  /// In en, this message translates to:
  /// **'Browser storage is unavailable. Allow website storage and retry.'**
  String get labelf7c4df5ebfc0;

  /// No description provided for @labelcfa0dfffb662.
  ///
  /// In en, this message translates to:
  /// **'Choose a supported audio, video, document or PNG/JPEG file.'**
  String get labelcfa0dfffb662;

  /// No description provided for @label1b1aff5e5100.
  ///
  /// In en, this message translates to:
  /// **'Choose up to 20 files at a time.'**
  String get label1b1aff5e5100;

  /// No description provided for @label033eedd28183.
  ///
  /// In en, this message translates to:
  /// **'Close other Teno tabs and retry.'**
  String get label033eedd28183;

  /// No description provided for @label450f7807e5e7.
  ///
  /// In en, this message translates to:
  /// **'Could not save the file in this browser. Free up storage and retry.'**
  String get label450f7807e5e7;

  /// No description provided for @label7f5bff4d3e6d.
  ///
  /// In en, this message translates to:
  /// **'File unavailable for this account.'**
  String get label7f5bff4d3e6d;

  /// No description provided for @labelbe125b0e02ff.
  ///
  /// In en, this message translates to:
  /// **'Invalid interface language.'**
  String get labelbe125b0e02ff;

  /// No description provided for @label42ff5192c1e3.
  ///
  /// In en, this message translates to:
  /// **'RECORDING_UNAVAILABLE: This recording is no longer available.'**
  String get label42ff5192c1e3;

  /// No description provided for @label4776d0f30a16.
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled.'**
  String get label4776d0f30a16;

  /// No description provided for @labeld213c1d485d4.
  ///
  /// In en, this message translates to:
  /// **'Stop the upload before deleting this browser copy.'**
  String get labeld213c1d485d4;

  /// No description provided for @label3ee0417ca776.
  ///
  /// In en, this message translates to:
  /// **'This action is not available in the Web preview.'**
  String get label3ee0417ca776;

  /// No description provided for @label05fa01dff97b.
  ///
  /// In en, this message translates to:
  /// **'This audio cannot be played in this browser.'**
  String get label05fa01dff97b;

  /// No description provided for @label12bfad5e9bb0.
  ///
  /// In en, this message translates to:
  /// **'This file is uploading in another tab.'**
  String get label12bfad5e9bb0;

  /// No description provided for @label009a19b41a91.
  ///
  /// In en, this message translates to:
  /// **'This request is not a Teno API request.'**
  String get label009a19b41a91;

  /// No description provided for @labelc691c2b42bd2.
  ///
  /// In en, this message translates to:
  /// **'Upload result was incomplete. Retry safely.'**
  String get labelc691c2b42bd2;

  /// No description provided for @label6122f155474f.
  ///
  /// In en, this message translates to:
  /// **'Upload or request stopped. Retry when ready.'**
  String get label6122f155474f;

  /// No description provided for @label8c7103817ec7.
  ///
  /// In en, this message translates to:
  /// **'Connection interrupted. Check your internet connection and retry.'**
  String get label8c7103817ec7;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
