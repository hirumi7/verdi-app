import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppStrings
/// returned by `AppStrings.of(context)`.
///
/// Applications need to include `AppStrings.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppStrings.localizationsDelegates,
///   supportedLocales: AppStrings.supportedLocales,
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
/// be consistent with the languages listed in the AppStrings.supportedLocales
/// property.
abstract class AppStrings {
  AppStrings(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings)!;
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Verdi'**
  String get appTitle;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @plants.
  ///
  /// In en, this message translates to:
  /// **'Plants'**
  String get plants;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @developmentNotice.
  ///
  /// In en, this message translates to:
  /// **'Development preview · on-device storage'**
  String get developmentNotice;

  /// No description provided for @developmentDetails.
  ///
  /// In en, this message translates to:
  /// **'Plants, care history, journals, photos and drafts stay on this device between launches. Purchases and notifications are not connected yet.'**
  String get developmentDetails;

  /// No description provided for @noPlants.
  ///
  /// In en, this message translates to:
  /// **'No plants yet'**
  String get noPlants;

  /// No description provided for @noPlantsBody.
  ///
  /// In en, this message translates to:
  /// **'Give your first plant a place here, then choose when to check on it.'**
  String get noPlantsBody;

  /// No description provided for @addPlant.
  ///
  /// In en, this message translates to:
  /// **'Add a plant'**
  String get addPlant;

  /// No description provided for @editPlant.
  ///
  /// In en, this message translates to:
  /// **'Edit plant'**
  String get editPlant;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @searchPlants.
  ///
  /// In en, this message translates to:
  /// **'Search plants'**
  String get searchPlants;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No plants match your search.'**
  String get noMatches;

  /// No description provided for @noChecksDue.
  ///
  /// In en, this message translates to:
  /// **'No checks due today'**
  String get noChecksDue;

  /// No description provided for @noRoutines.
  ///
  /// In en, this message translates to:
  /// **'No checks scheduled. Add a routine when you add your next sample plant.'**
  String get noRoutines;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue checks'**
  String get overdue;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Next seven days'**
  String get upcoming;

  /// No description provided for @doneToday.
  ///
  /// In en, this message translates to:
  /// **'Done today'**
  String get doneToday;

  /// No description provided for @checkWatering.
  ///
  /// In en, this message translates to:
  /// **'Check watering'**
  String get checkWatering;

  /// No description provided for @water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// No description provided for @fertilize.
  ///
  /// In en, this message translates to:
  /// **'Fertilize'**
  String get fertilize;

  /// No description provided for @mist.
  ///
  /// In en, this message translates to:
  /// **'Mist'**
  String get mist;

  /// No description provided for @repot.
  ///
  /// In en, this message translates to:
  /// **'Repot'**
  String get repot;

  /// No description provided for @rotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotate;

  /// No description provided for @watered.
  ///
  /// In en, this message translates to:
  /// **'Watered'**
  String get watered;

  /// No description provided for @fertilized.
  ///
  /// In en, this message translates to:
  /// **'Fertilized'**
  String get fertilized;

  /// No description provided for @misted.
  ///
  /// In en, this message translates to:
  /// **'Misted'**
  String get misted;

  /// No description provided for @repotted.
  ///
  /// In en, this message translates to:
  /// **'Repotted'**
  String get repotted;

  /// No description provided for @rotated.
  ///
  /// In en, this message translates to:
  /// **'Rotated'**
  String get rotated;

  /// No description provided for @checkedNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'Checked — not needed'**
  String get checkedNotNeeded;

  /// No description provided for @moveCheck.
  ///
  /// In en, this message translates to:
  /// **'Move check'**
  String get moveCheck;

  /// No description provided for @skipCheck.
  ///
  /// In en, this message translates to:
  /// **'Skip check'**
  String get skipCheck;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @selectCare.
  ///
  /// In en, this message translates to:
  /// **'Select care'**
  String get selectCare;

  /// No description provided for @markSelectedWatered.
  ///
  /// In en, this message translates to:
  /// **'Mark selected as watered'**
  String get markSelectedWatered;

  /// No description provided for @confirmCare.
  ///
  /// In en, this message translates to:
  /// **'Confirm care'**
  String get confirmCare;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @reviewSave.
  ///
  /// In en, this message translates to:
  /// **'Review and save'**
  String get reviewSave;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'Care history'**
  String get history;

  /// No description provided for @audit.
  ///
  /// In en, this message translates to:
  /// **'Include removed entries'**
  String get audit;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No care history yet'**
  String get historyEmpty;

  /// No description provided for @scheduleChange.
  ///
  /// In en, this message translates to:
  /// **'Schedule change'**
  String get scheduleChange;

  /// No description provided for @removed.
  ///
  /// In en, this message translates to:
  /// **'Removed from care counts'**
  String get removed;

  /// No description provided for @corrected.
  ///
  /// In en, this message translates to:
  /// **'Corrected'**
  String get corrected;

  /// No description provided for @historyOnly.
  ///
  /// In en, this message translates to:
  /// **'History only — the next check will not change.'**
  String get historyOnly;

  /// No description provided for @actualCareDate.
  ///
  /// In en, this message translates to:
  /// **'Date care happened'**
  String get actualCareDate;

  /// No description provided for @checkDate.
  ///
  /// In en, this message translates to:
  /// **'Date checked'**
  String get checkDate;

  /// No description provided for @nextCheckDate.
  ///
  /// In en, this message translates to:
  /// **'Next check'**
  String get nextCheckDate;

  /// No description provided for @chooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get chooseDate;

  /// No description provided for @knownCare.
  ///
  /// In en, this message translates to:
  /// **'I know the last care date'**
  String get knownCare;

  /// No description provided for @unknownCare.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get unknownCare;

  /// No description provided for @lastCare.
  ///
  /// In en, this message translates to:
  /// **'Last care'**
  String get lastCare;

  /// No description provided for @firstCheck.
  ///
  /// In en, this message translates to:
  /// **'First check'**
  String get firstCheck;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Plant name'**
  String get nickname;

  /// No description provided for @species.
  ///
  /// In en, this message translates to:
  /// **'Custom species name'**
  String get species;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get location;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notes;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light — user supplied'**
  String get light;

  /// No description provided for @toxicity.
  ///
  /// In en, this message translates to:
  /// **'Toxicity — user supplied'**
  String get toxicity;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @lowLight.
  ///
  /// In en, this message translates to:
  /// **'Low light'**
  String get lowLight;

  /// No description provided for @mediumLight.
  ///
  /// In en, this message translates to:
  /// **'Medium light'**
  String get mediumLight;

  /// No description provided for @brightIndirect.
  ///
  /// In en, this message translates to:
  /// **'Bright indirect light'**
  String get brightIndirect;

  /// No description provided for @directLight.
  ///
  /// In en, this message translates to:
  /// **'Direct light'**
  String get directLight;

  /// No description provided for @toxic.
  ///
  /// In en, this message translates to:
  /// **'Toxic'**
  String get toxic;

  /// No description provided for @nonToxic.
  ///
  /// In en, this message translates to:
  /// **'Non-toxic'**
  String get nonToxic;

  /// No description provided for @waterRoutine.
  ///
  /// In en, this message translates to:
  /// **'Watering routine'**
  String get waterRoutine;

  /// No description provided for @interval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get interval;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @weeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get weeks;

  /// No description provided for @months.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get months;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get years;

  /// No description provided for @draftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get draftSaved;

  /// No description provided for @savingDraft.
  ///
  /// In en, this message translates to:
  /// **'Saving draft…'**
  String get savingDraft;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Your entries are still here.'**
  String get saveFailed;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discard;

  /// No description provided for @discardQuestion.
  ///
  /// In en, this message translates to:
  /// **'Discard your changes?'**
  String get discardQuestion;

  /// No description provided for @discardBody.
  ///
  /// In en, this message translates to:
  /// **'This removes this editor’s draft. Your saved plant and care history stay as they are.'**
  String get discardBody;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive plant'**
  String get archive;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore plant'**
  String get restore;

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteForever;

  /// No description provided for @archiveBody.
  ///
  /// In en, this message translates to:
  /// **'This plant will leave active lists and reminders. Its routines and history are kept.'**
  String get archiveBody;

  /// No description provided for @restoreBody.
  ///
  /// In en, this message translates to:
  /// **'Restore this plant to the active collection. Review the resulting check dates below.'**
  String get restoreBody;

  /// No description provided for @deleteBody.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove this archived plant, routines and history? External exports and shared copies are unaffected.'**
  String get deleteBody;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause routine'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume routine'**
  String get resume;

  /// No description provided for @retire.
  ///
  /// In en, this message translates to:
  /// **'Remove routine'**
  String get retire;

  /// No description provided for @editInterval.
  ///
  /// In en, this message translates to:
  /// **'Edit interval'**
  String get editInterval;

  /// No description provided for @clearOverride.
  ///
  /// In en, this message translates to:
  /// **'Clear moved date'**
  String get clearOverride;

  /// No description provided for @addPastCare.
  ///
  /// In en, this message translates to:
  /// **'Add past care'**
  String get addPastCare;

  /// No description provided for @correctCare.
  ///
  /// In en, this message translates to:
  /// **'Correct care'**
  String get correctCare;

  /// No description provided for @removeCare.
  ///
  /// In en, this message translates to:
  /// **'Remove mistaken entry'**
  String get removeCare;

  /// No description provided for @restoreCare.
  ///
  /// In en, this message translates to:
  /// **'Restore entry'**
  String get restoreCare;

  /// No description provided for @careSaved.
  ///
  /// In en, this message translates to:
  /// **'Care recorded. Review it in Done today or history.'**
  String get careSaved;

  /// No description provided for @undoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Undo is no longer available. You can correct the entry in history.'**
  String get undoUnavailable;

  /// No description provided for @staleSelection.
  ///
  /// In en, this message translates to:
  /// **'Something changed. Review the current plants and choose again.'**
  String get staleSelection;

  /// No description provided for @storageFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not finish this operation. Keep your entries and retry.'**
  String get storageFailure;

  /// No description provided for @unknownSave.
  ///
  /// In en, this message translates to:
  /// **'The save result is uncertain. Resolve it before trying another save.'**
  String get unknownSave;

  /// No description provided for @activeLimit.
  ///
  /// In en, this message translates to:
  /// **'The development Free limit is reached. Archive a plant to free a place; existing history stays available.'**
  String get activeLimit;

  /// No description provided for @fieldInvalid.
  ///
  /// In en, this message translates to:
  /// **'Review the highlighted fields and date choices.'**
  String get fieldInvalid;

  /// No description provided for @futureCare.
  ///
  /// In en, this message translates to:
  /// **'Completed care cannot be dated in the future.'**
  String get futureCare;

  /// No description provided for @earlierCare.
  ///
  /// In en, this message translates to:
  /// **'This date is earlier than the latest recorded care. Use Add past care for a history-only entry.'**
  String get earlierCare;

  /// No description provided for @firstCheckRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a first-check date; no care history will be invented.'**
  String get firstCheckRequired;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'That action is no longer available. Refresh the current plant.'**
  String get notAvailable;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @removedEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry removed; the next check is unchanged.'**
  String get removedEntry;

  /// No description provided for @allActions.
  ///
  /// In en, this message translates to:
  /// **'Care actions'**
  String get allActions;

  /// No description provided for @noSelection.
  ///
  /// In en, this message translates to:
  /// **'Select at least one compatible care check.'**
  String get noSelection;

  /// No description provided for @previewHeading.
  ///
  /// In en, this message translates to:
  /// **'Review your changes'**
  String get previewHeading;

  /// No description provided for @aboutPreview.
  ///
  /// In en, this message translates to:
  /// **'About this preview'**
  String get aboutPreview;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'Use device appearance'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @plantCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No active plants} =1{1 active plant} other{{count} active plants}}'**
  String plantCount(int count);

  /// No description provided for @selectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 check selected} other{{count} checks selected}}'**
  String selectionCount(int count);

  /// No description provided for @dueOn.
  ///
  /// In en, this message translates to:
  /// **'Check on {date}'**
  String dueOn(String date);

  /// No description provided for @lateDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Check is 1 day overdue} other{Check is {count} days overdue}}'**
  String lateDays(int count);

  /// No description provided for @nextForPlant.
  ///
  /// In en, this message translates to:
  /// **'Next: {name} · {date}'**
  String nextForPlant(String name, String date);

  /// No description provided for @nextAfter.
  ///
  /// In en, this message translates to:
  /// **'Next check: {date}'**
  String nextAfter(String date);

  /// No description provided for @routineEvery.
  ///
  /// In en, this message translates to:
  /// **'Every {count} {unit}'**
  String routineEvery(int count, String unit);

  /// No description provided for @plantNamed.
  ///
  /// In en, this message translates to:
  /// **'{name} · {species}'**
  String plantNamed(String name, String species);

  /// No description provided for @routineNamed.
  ///
  /// In en, this message translates to:
  /// **'{name} routine'**
  String routineNamed(String name);

  /// No description provided for @intervalUnit.
  ///
  /// In en, this message translates to:
  /// **'Interval unit'**
  String get intervalUnit;

  /// No description provided for @positiveInterval.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 1 to 9,999.'**
  String get positiveInterval;

  /// No description provided for @chooseCareBranch.
  ///
  /// In en, this message translates to:
  /// **'Choose a known last-care date or Not sure.'**
  String get chooseCareBranch;

  /// No description provided for @keepCurrentSchedules.
  ///
  /// In en, this message translates to:
  /// **'Existing care schedules and original suggestions will be kept. You can edit each routine from the plant details.'**
  String get keepCurrentSchedules;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused — no checks scheduled'**
  String get paused;

  /// No description provided for @retired.
  ///
  /// In en, this message translates to:
  /// **'Removed routine — history retained'**
  String get retired;

  /// No description provided for @deletionCounts.
  ///
  /// In en, this message translates to:
  /// **'This removes {routines} routines, {events} care entries, {corrections} corrections, {changes} schedule changes and {drafts} drafts.'**
  String deletionCounts(
    int routines,
    int events,
    int corrections,
    int changes,
    int drafts,
  );

  /// No description provided for @recordedOn.
  ///
  /// In en, this message translates to:
  /// **'Recorded: {date}'**
  String recordedOn(String date);

  /// No description provided for @careOutcome.
  ///
  /// In en, this message translates to:
  /// **'Care outcome'**
  String get careOutcome;

  /// No description provided for @reviewLatest.
  ///
  /// In en, this message translates to:
  /// **'Review current version'**
  String get reviewLatest;

  /// No description provided for @keepMyFields.
  ///
  /// In en, this message translates to:
  /// **'Keep my entered fields'**
  String get keepMyFields;

  /// No description provided for @conflictReview.
  ///
  /// In en, this message translates to:
  /// **'Another action changed this plant or draft. Review the current values below. Keeping your entered fields replaces this draft version; final saving still needs a new review. Current care schedules are kept.'**
  String get conflictReview;

  /// No description provided for @returnToReview.
  ///
  /// In en, this message translates to:
  /// **'Return to review'**
  String get returnToReview;

  /// No description provided for @affectedPlant.
  ///
  /// In en, this message translates to:
  /// **'Changed selection: {name}'**
  String affectedPlant(String name);

  /// No description provided for @openingPlants.
  ///
  /// In en, this message translates to:
  /// **'Opening your plants'**
  String get openingPlants;

  /// No description provided for @recoveryHeading.
  ///
  /// In en, this message translates to:
  /// **'Recover unfinished actions'**
  String get recoveryHeading;

  /// No description provided for @developmentStorage.
  ///
  /// In en, this message translates to:
  /// **'Development storage • Saved on this device'**
  String get developmentStorage;

  /// No description provided for @retainedStorageError.
  ///
  /// In en, this message translates to:
  /// **'Your saved files are retained. Storage could not complete this action.'**
  String get retainedStorageError;

  /// No description provided for @retryOpening.
  ///
  /// In en, this message translates to:
  /// **'Retry opening'**
  String get retryOpening;

  /// No description provided for @pendingActionExplanation.
  ///
  /// In en, this message translates to:
  /// **'An earlier action has no confirmed result. Review it before making new changes.'**
  String get pendingActionExplanation;

  /// No description provided for @retryPendingAction.
  ///
  /// In en, this message translates to:
  /// **'Retry action'**
  String get retryPendingAction;

  /// No description provided for @cancelPendingAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel action'**
  String get cancelPendingAction;

  /// No description provided for @cancelPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this pending action?'**
  String get cancelPendingTitle;

  /// No description provided for @retainDraftExplanation.
  ///
  /// In en, this message translates to:
  /// **'Saved plants and the retained draft stay available.'**
  String get retainDraftExplanation;

  /// No description provided for @keepPending.
  ///
  /// In en, this message translates to:
  /// **'Keep pending'**
  String get keepPending;

  /// No description provided for @recoveredActionReview.
  ///
  /// In en, this message translates to:
  /// **'Review the recovered action before saving.'**
  String get recoveredActionReview;

  /// No description provided for @saveDraftAction.
  ///
  /// In en, this message translates to:
  /// **'Save unfinished draft'**
  String get saveDraftAction;

  /// No description provided for @searchSpecies.
  ///
  /// In en, this message translates to:
  /// **'Search species'**
  String get searchSpecies;

  /// No description provided for @popularSpecies.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popularSpecies;

  /// No description provided for @catalogLimited.
  ///
  /// In en, this message translates to:
  /// **'Some plant guides are unavailable'**
  String get catalogLimited;

  /// No description provided for @catalogCustomAvailable.
  ///
  /// In en, this message translates to:
  /// **'You can still add a custom plant. Your saved plants and care history are kept.'**
  String get catalogCustomAvailable;

  /// No description provided for @noSpeciesMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches for “{query}”'**
  String noSpeciesMatches(String query);

  /// No description provided for @customPlant.
  ///
  /// In en, this message translates to:
  /// **'Add a custom plant'**
  String get customPlant;

  /// No description provided for @speciesInformation.
  ///
  /// In en, this message translates to:
  /// **'Species information'**
  String get speciesInformation;

  /// No description provided for @genericIllustration.
  ///
  /// In en, this message translates to:
  /// **'Generic illustration'**
  String get genericIllustration;

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// No description provided for @suggestionOnly.
  ///
  /// In en, this message translates to:
  /// **'A starting suggestion for checks. Adjust it to your plant and conditions.'**
  String get suggestionOnly;

  /// No description provided for @sourcesCredits.
  ///
  /// In en, this message translates to:
  /// **'Sources and credits'**
  String get sourcesCredits;

  /// No description provided for @catalogCredits.
  ///
  /// In en, this message translates to:
  /// **'Care summaries: Verdi. Generic illustration: Verdi design import. Names and source references are included for attribution. Source websites require an internet connection.'**
  String get catalogCredits;

  /// No description provided for @changeSpecies.
  ///
  /// In en, this message translates to:
  /// **'Change species'**
  String get changeSpecies;

  /// No description provided for @keepRoutine.
  ///
  /// In en, this message translates to:
  /// **'Keep current routine'**
  String get keepRoutine;

  /// No description provided for @applySuggestion.
  ///
  /// In en, this message translates to:
  /// **'Apply suggestion'**
  String get applySuggestion;

  /// No description provided for @chooseSpeciesRoutine.
  ///
  /// In en, this message translates to:
  /// **'Choose what happens to each existing routine.'**
  String get chooseSpeciesRoutine;

  /// No description provided for @originalSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Original suggestion'**
  String get originalSuggestion;

  /// No description provided for @appliedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Last applied suggestion'**
  String get appliedSuggestion;

  /// No description provided for @catalogIdentity.
  ///
  /// In en, this message translates to:
  /// **'Catalog species'**
  String get catalogIdentity;

  /// No description provided for @customIdentity.
  ///
  /// In en, this message translates to:
  /// **'User-supplied species and observations'**
  String get customIdentity;

  /// No description provided for @chooseSpecies.
  ///
  /// In en, this message translates to:
  /// **'Choose species'**
  String get chooseSpecies;

  /// No description provided for @catalogStale.
  ///
  /// In en, this message translates to:
  /// **'This guide changed. Choose the species again or use a custom plant; your other fields are kept.'**
  String get catalogStale;

  /// No description provided for @selectedSpecies.
  ///
  /// In en, this message translates to:
  /// **'Selected species'**
  String get selectedSpecies;

  /// No description provided for @contentReviewed.
  ///
  /// In en, this message translates to:
  /// **'Content reviewed'**
  String get contentReviewed;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @createCustomQuery.
  ///
  /// In en, this message translates to:
  /// **'Create “{query}” as a custom plant'**
  String createCustomQuery(String query);

  /// No description provided for @journalAndPhotos.
  ///
  /// In en, this message translates to:
  /// **'Journal and photos'**
  String get journalAndPhotos;

  /// No description provided for @plantPhoto.
  ///
  /// In en, this message translates to:
  /// **'Plant photo'**
  String get plantPhoto;

  /// No description provided for @photoUnavailableRetry.
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable · Retry'**
  String get photoUnavailableRetry;

  /// No description provided for @newJournalEntry.
  ///
  /// In en, this message translates to:
  /// **'New journal entry'**
  String get newJournalEntry;

  /// No description provided for @editJournalEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get editJournalEntry;

  /// No description provided for @saveJournal.
  ///
  /// In en, this message translates to:
  /// **'Save entry'**
  String get saveJournal;

  /// No description provided for @journalSaveExplanation.
  ///
  /// In en, this message translates to:
  /// **'Save this observation and its attached photo to this plant. Care history and next checks stay unchanged.'**
  String get journalSaveExplanation;

  /// No description provided for @journalNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get journalNote;

  /// No description provided for @journalNoteLimit.
  ///
  /// In en, this message translates to:
  /// **'Use up to 2,000 characters.'**
  String get journalNoteLimit;

  /// No description provided for @observationDate.
  ///
  /// In en, this message translates to:
  /// **'Observation date'**
  String get observationDate;

  /// No description provided for @photoObservationDate.
  ///
  /// In en, this message translates to:
  /// **'Photo observation date'**
  String get photoObservationDate;

  /// No description provided for @chooseObservationDate.
  ///
  /// In en, this message translates to:
  /// **'Choose observation date'**
  String get chooseObservationDate;

  /// No description provided for @invalidObservationDate.
  ///
  /// In en, this message translates to:
  /// **'Choose today or an earlier date.'**
  String get invalidObservationDate;

  /// No description provided for @journalHint.
  ///
  /// In en, this message translates to:
  /// **'A photo or a note is enough. Change the date to log an earlier observation. All journal history stays available.'**
  String get journalHint;

  /// No description provided for @discardJournal.
  ///
  /// In en, this message translates to:
  /// **'Discard this entry draft?'**
  String get discardJournal;

  /// No description provided for @discardJournalExplanation.
  ///
  /// In en, this message translates to:
  /// **'Unsaved notes and newly attached photos in this draft will be removed. Saved entries and originals remain.'**
  String get discardJournalExplanation;

  /// No description provided for @saveNoteOnly.
  ///
  /// In en, this message translates to:
  /// **'Save note only'**
  String get saveNoteOnly;

  /// No description provided for @saveNoteOnlyExplanation.
  ///
  /// In en, this message translates to:
  /// **'Continue without the photo that failed to attach. Your note will be saved after you review it.'**
  String get saveNoteOnlyExplanation;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @removeAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get removeAttachment;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @reviewJournalConflict.
  ///
  /// In en, this message translates to:
  /// **'Review newer version'**
  String get reviewJournalConflict;

  /// No description provided for @rebaseJournalExplanation.
  ///
  /// In en, this message translates to:
  /// **'Keep this draft’s note, date and photos while accepting the current saved entry as its editing base. Review and save the entry separately.'**
  String get rebaseJournalExplanation;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @photosEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved photos yet. Add a photo to a journal entry or plant cover.'**
  String get photosEmpty;

  /// No description provided for @coverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Cover photo'**
  String get coverPhoto;

  /// No description provided for @setCover.
  ///
  /// In en, this message translates to:
  /// **'Set as cover'**
  String get setCover;

  /// No description provided for @removeCover.
  ///
  /// In en, this message translates to:
  /// **'Remove cover'**
  String get removeCover;

  /// No description provided for @changePhotoDate.
  ///
  /// In en, this message translates to:
  /// **'Change photo date'**
  String get changePhotoDate;

  /// No description provided for @photoDateExplanation.
  ///
  /// In en, this message translates to:
  /// **'Change only this photo’s observation date. Journal dates and care history remain unchanged.'**
  String get photoDateExplanation;

  /// No description provided for @exportOriginal.
  ///
  /// In en, this message translates to:
  /// **'Export original'**
  String get exportOriginal;

  /// No description provided for @shareOriginal.
  ///
  /// In en, this message translates to:
  /// **'Share original'**
  String get shareOriginal;

  /// No description provided for @originalMetadataWarning.
  ///
  /// In en, this message translates to:
  /// **'The original file may include location, device and other embedded metadata. Share only if you want the selected destination to receive that information.'**
  String get originalMetadataWarning;

  /// No description provided for @originalHandedToOS.
  ///
  /// In en, this message translates to:
  /// **'Original handed to the selected app.'**
  String get originalHandedToOS;

  /// No description provided for @shareCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sharing cancelled.'**
  String get shareCancelled;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'The original could not be shared. Please retry.'**
  String get shareFailed;

  /// No description provided for @deletePhoto.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get deletePhoto;

  /// No description provided for @deletePhotoExplanation.
  ///
  /// In en, this message translates to:
  /// **'Remove this original from covers, journal entries and drafts. Notes and unrelated care history stay. Photo-only entries that become empty are removed. Any open replacement or affected entry draft must be finished or discarded first.'**
  String get deletePhotoExplanation;

  /// No description provided for @replacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get replacePhoto;

  /// No description provided for @replacementExplanation.
  ///
  /// In en, this message translates to:
  /// **'Every saved reference keeps the same photo identity. The existing original stays available until the replacement is saved successfully.'**
  String get replacementExplanation;

  /// No description provided for @reviewReplacement.
  ///
  /// In en, this message translates to:
  /// **'Review replacement'**
  String get reviewReplacement;

  /// No description provided for @checkAttachment.
  ///
  /// In en, this message translates to:
  /// **'Check attachment status'**
  String get checkAttachment;

  /// No description provided for @rebasePhotoExplanation.
  ///
  /// In en, this message translates to:
  /// **'Keep the prepared replacement and accept the current photo as its base. Review the replacement separately before saving.'**
  String get rebasePhotoExplanation;

  /// No description provided for @discardReplacement.
  ///
  /// In en, this message translates to:
  /// **'Discard replacement'**
  String get discardReplacement;

  /// No description provided for @discardReplacementExplanation.
  ///
  /// In en, this message translates to:
  /// **'Remove this prepared replacement. The saved original and its references remain unchanged.'**
  String get discardReplacementExplanation;

  /// No description provided for @deleteJournalEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get deleteJournalEntry;

  /// No description provided for @deleteJournalExplanation.
  ///
  /// In en, this message translates to:
  /// **'Remove this entry and its open edit draft, including any unsaved draft photos. Saved originals remain in the gallery. Unrelated notes and care history stay.'**
  String get deleteJournalExplanation;

  /// No description provided for @photoOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'A photo is optional. Your other plant fields stay in the draft.'**
  String get photoOptionalHint;

  /// No description provided for @cameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. You can open Settings, choose Library, or continue without a photo.'**
  String get cameraDenied;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera is unavailable on this device. Choose Library or continue without a photo.'**
  String get cameraUnavailable;

  /// No description provided for @photoInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose a complete still JPEG, PNG or HEIC image. Animated or unreadable files cannot be attached.'**
  String get photoInvalid;

  /// No description provided for @photoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo no larger than 64 MB and 100 megapixels.'**
  String get photoTooLarge;

  /// No description provided for @photoNotReady.
  ///
  /// In en, this message translates to:
  /// **'The photo is not ready. Check its status or retry before saving.'**
  String get photoNotReady;

  /// No description provided for @photoMissing.
  ///
  /// In en, this message translates to:
  /// **'The original file is unavailable. Your note and care history are still retained.'**
  String get photoMissing;

  /// No description provided for @photoSelectionExpired.
  ///
  /// In en, this message translates to:
  /// **'Choose the photo again. This temporary selection is no longer available.'**
  String get photoSelectionExpired;

  /// No description provided for @futureObservation.
  ///
  /// In en, this message translates to:
  /// **'An observation cannot be dated in the future.'**
  String get futureObservation;

  /// No description provided for @emptyJournal.
  ///
  /// In en, this message translates to:
  /// **'Add a note or a photo before saving.'**
  String get emptyJournal;

  /// No description provided for @photoContinueWithout.
  ///
  /// In en, this message translates to:
  /// **'Continue without the new photo'**
  String get photoContinueWithout;

  /// No description provided for @journalDraftConflictExplanation.
  ///
  /// In en, this message translates to:
  /// **'This draft changed elsewhere. Keep the text, date and selected photos shown in this editor, replacing the current draft fields? Saved journal entries remain unchanged until you review and save.'**
  String get journalDraftConflictExplanation;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get backupTitle;

  /// No description provided for @backupExplanation.
  ///
  /// In en, this message translates to:
  /// **'Keep a portable copy of your plants, care history, journals, photos and saved drafts. Backup and restore are free.'**
  String get backupExplanation;

  /// No description provided for @backupPrivacy.
  ///
  /// In en, this message translates to:
  /// **'The ZIP includes your private notes and photos. It is not password-encrypted. Share it only with a destination you trust.'**
  String get backupPrivacy;

  /// No description provided for @backupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get backupCreate;

  /// No description provided for @backupChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose backup file'**
  String get backupChoose;

  /// No description provided for @backupReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace this collection?'**
  String get backupReplaceTitle;

  /// No description provided for @backupReplaceWarning.
  ///
  /// In en, this message translates to:
  /// **'Restoring replaces all plants, care history, journals, photos, saved drafts and preferences on this device with the backup. It does not merge collections. Create a backup first if you want to keep your current collection.'**
  String get backupReplaceWarning;

  /// No description provided for @backupReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace collection'**
  String get backupReplace;

  /// No description provided for @backupWorking.
  ///
  /// In en, this message translates to:
  /// **'Preparing and checking your backup…'**
  String get backupWorking;

  /// No description provided for @backupReplacing.
  ///
  /// In en, this message translates to:
  /// **'Restoring your collection. Wait for verification before leaving this screen.'**
  String get backupReplacing;

  /// No description provided for @backupPreview.
  ///
  /// In en, this message translates to:
  /// **'Ready to restore'**
  String get backupPreview;

  /// No description provided for @backupCounts.
  ///
  /// In en, this message translates to:
  /// **'{active} active plants · {archived} archived plants\n{events} history entries · {journals} journal entries · {photos} photos'**
  String backupCounts(
    String active,
    String archived,
    String events,
    String journals,
    String photos,
  );

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'File created'**
  String get backupCreated;

  /// No description provided for @backupHanded.
  ///
  /// In en, this message translates to:
  /// **'Shared with another app'**
  String get backupHanded;

  /// No description provided for @backupKeepOutside.
  ///
  /// In en, this message translates to:
  /// **'Save a copy outside Verdi and this device. Creating a file or opening the share sheet does not verify an external backup.'**
  String get backupKeepOutside;

  /// No description provided for @backupShare.
  ///
  /// In en, this message translates to:
  /// **'Share / Save a copy'**
  String get backupShare;

  /// No description provided for @backupShareCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sharing was cancelled. The file is still available here.'**
  String get backupShareCancelled;

  /// No description provided for @backupShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Sharing did not finish. Your file is still available; try another destination.'**
  String get backupShareFailed;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Your backup was restored and the collection was reopened.'**
  String get backupRestored;

  /// No description provided for @backupCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled. Your current collection is unchanged.'**
  String get backupCancelled;

  /// No description provided for @backupCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'Check restore status'**
  String get backupCheckStatus;

  /// No description provided for @backupReviewAgain.
  ///
  /// In en, this message translates to:
  /// **'Validate and review again'**
  String get backupReviewAgain;

  /// No description provided for @backupStale.
  ///
  /// In en, this message translates to:
  /// **'Your collection or saved drafts changed after this preview. Validate again and review the new preview.'**
  String get backupStale;

  /// No description provided for @backupBusy.
  ///
  /// In en, this message translates to:
  /// **'Finish any pending save or photo selection and close any share sheet, then try again. Your collection has not been replaced.'**
  String get backupBusy;

  /// No description provided for @backupDiskFull.
  ///
  /// In en, this message translates to:
  /// **'There is not enough free space to create and verify a safe copy. Free some device storage, then try again.'**
  String get backupDiskFull;

  /// No description provided for @backupMissingPhoto.
  ///
  /// In en, this message translates to:
  /// **'An original photo is missing. Your other content is still available. Resolve the missing photo before creating a complete backup.'**
  String get backupMissingPhoto;

  /// No description provided for @backupUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This backup version is not supported by this version of Verdi. Your collection is unchanged.'**
  String get backupUnsupported;

  /// No description provided for @backupLimit.
  ///
  /// In en, this message translates to:
  /// **'This backup exceeds a supported size or content limit. Nothing was truncated or replaced.'**
  String get backupLimit;

  /// No description provided for @backupInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file is incomplete, damaged or not a supported Verdi backup. Your collection has not been replaced.'**
  String get backupInvalid;

  /// No description provided for @backupFailure.
  ///
  /// In en, this message translates to:
  /// **'The operation could not finish. Keep your backup file. Check the status or try again; Verdi retains the previous collection during recovery.'**
  String get backupFailure;

  /// No description provided for @backupLocaleFallback.
  ///
  /// In en, this message translates to:
  /// **'The restored language preference is retained, but is not supported yet. Verdi is using device formatting.'**
  String get backupLocaleFallback;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(lookupAppStrings(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

AppStrings lookupAppStrings(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppStringsEn();
  }

  throw FlutterError(
    'AppStrings.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
