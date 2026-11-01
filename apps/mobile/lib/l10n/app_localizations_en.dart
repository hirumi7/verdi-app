// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppStringsEn extends AppStrings {
  AppStringsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Verdi';

  @override
  String get today => 'Today';

  @override
  String get plants => 'Plants';

  @override
  String get settings => 'Settings';

  @override
  String get developmentNotice => 'Development preview · on-device storage';

  @override
  String get developmentDetails =>
      'Plants, care history, journals, photos and drafts stay on this device between launches. Local reminders depend on notification permission and system settings. Pro purchases use local StoreKit testing in this preview.';

  @override
  String get noPlants => 'No plants yet';

  @override
  String get noPlantsBody =>
      'Give your first plant a place here, then choose when to check on it.';

  @override
  String get addPlant => 'Add a plant';

  @override
  String get editPlant => 'Edit plant';

  @override
  String get active => 'Active';

  @override
  String get archived => 'Archived';

  @override
  String get searchPlants => 'Search plants';

  @override
  String get noMatches => 'No plants match your search.';

  @override
  String get noChecksDue => 'No checks due today';

  @override
  String get noRoutines =>
      'No checks scheduled. Open a plant and choose Add care.';

  @override
  String get overdue => 'Overdue checks';

  @override
  String get dueToday => 'Due today';

  @override
  String get upcoming => 'Next seven days';

  @override
  String get doneToday => 'Done today';

  @override
  String get checkWatering => 'Check watering';

  @override
  String get water => 'Water';

  @override
  String get fertilize => 'Fertilize';

  @override
  String get mist => 'Mist';

  @override
  String get repot => 'Repot';

  @override
  String get rotate => 'Rotate';

  @override
  String get watered => 'Watered';

  @override
  String get fertilized => 'Fertilized';

  @override
  String get misted => 'Misted';

  @override
  String get repotted => 'Repotted';

  @override
  String get rotated => 'Rotated';

  @override
  String get checkedNotNeeded => 'Checked — not needed';

  @override
  String get moveCheck => 'Move check';

  @override
  String get skipCheck => 'Skip check';

  @override
  String get moreActions => 'More actions';

  @override
  String get selectCare => 'Select care';

  @override
  String get markSelectedWatered => 'Mark selected as watered';

  @override
  String get confirmCare => 'Confirm care';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueLabel => 'Continue';

  @override
  String get save => 'Save';

  @override
  String get reviewSave => 'Review and save';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get undo => 'Undo';

  @override
  String get history => 'Care history';

  @override
  String get audit => 'Include removed entries';

  @override
  String get historyEmpty => 'No care history yet';

  @override
  String get scheduleChange => 'Schedule change';

  @override
  String get removed => 'Removed from care counts';

  @override
  String get corrected => 'Corrected';

  @override
  String get historyOnly => 'History only — the next check will not change.';

  @override
  String get actualCareDate => 'Date care happened';

  @override
  String get checkDate => 'Date checked';

  @override
  String get nextCheckDate => 'Next check';

  @override
  String get chooseDate => 'Choose a date';

  @override
  String get knownCare => 'I know the last care date';

  @override
  String get unknownCare => 'Not sure';

  @override
  String get lastCare => 'Last care';

  @override
  String get firstCheck => 'First check';

  @override
  String get nickname => 'Plant name';

  @override
  String get species => 'Custom species name';

  @override
  String get location => 'Location (optional)';

  @override
  String get notes => 'Notes (optional)';

  @override
  String get light => 'Light — user supplied';

  @override
  String get toxicity => 'Toxicity — user supplied';

  @override
  String get unknown => 'Unknown';

  @override
  String get lowLight => 'Low light';

  @override
  String get mediumLight => 'Medium light';

  @override
  String get brightIndirect => 'Bright indirect light';

  @override
  String get directLight => 'Direct light';

  @override
  String get toxic => 'Toxic';

  @override
  String get nonToxic => 'Non-toxic';

  @override
  String get waterRoutine => 'Watering routine';

  @override
  String get interval => 'Interval';

  @override
  String get days => 'Days';

  @override
  String get weeks => 'Weeks';

  @override
  String get months => 'Months';

  @override
  String get years => 'Years';

  @override
  String get draftSaved => 'Draft saved';

  @override
  String get savingDraft => 'Saving draft…';

  @override
  String get saveFailed => 'Could not save. Your entries are still here.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discard => 'Discard changes';

  @override
  String get discardQuestion => 'Discard your changes?';

  @override
  String get discardBody =>
      'This removes this editor’s draft. Your saved plant and care history stay as they are.';

  @override
  String get archive => 'Archive plant';

  @override
  String get restore => 'Restore plant';

  @override
  String get deleteForever => 'Delete forever';

  @override
  String get archiveBody =>
      'This plant will leave active lists and reminders. Its routines and history are kept.';

  @override
  String get restoreBody =>
      'Restore this plant to the active collection. Review the resulting check dates below.';

  @override
  String get deleteBody =>
      'Permanently remove this archived plant, routines and history? External exports and shared copies are unaffected.';

  @override
  String get pause => 'Pause routine';

  @override
  String get resume => 'Resume routine';

  @override
  String get retire => 'Remove routine';

  @override
  String get editInterval => 'Edit interval';

  @override
  String get clearOverride => 'Clear moved date';

  @override
  String get addPastCare => 'Add past care';

  @override
  String get correctCare => 'Correct care';

  @override
  String get removeCare => 'Remove mistaken entry';

  @override
  String get restoreCare => 'Restore entry';

  @override
  String get careSaved => 'Care recorded. Review it in Done today or history.';

  @override
  String get undoUnavailable =>
      'Undo is no longer available. You can correct the entry in history.';

  @override
  String get staleSelection =>
      'Something changed. Review the current plants and choose again.';

  @override
  String get storageFailure =>
      'Could not finish this operation. Keep your entries and retry.';

  @override
  String get unknownSave =>
      'The save result is uncertain. Resolve it before trying another save.';

  @override
  String get activeLimit =>
      'Free includes five active plants. Get Pro to add or restore more, or archive a plant. Your existing records stay available.';

  @override
  String get fieldInvalid => 'Review the highlighted fields and date choices.';

  @override
  String get futureCare => 'Completed care cannot be dated in the future.';

  @override
  String get earlierCare =>
      'This date is earlier than the latest recorded care. Use Add past care for a history-only entry.';

  @override
  String get firstCheckRequired =>
      'Choose a first-check date; no care history will be invented.';

  @override
  String get notAvailable =>
      'That action is no longer available. Refresh the current plant.';

  @override
  String get saved => 'Saved';

  @override
  String get removedEntry => 'Entry removed; the next check is unchanged.';

  @override
  String get allActions => 'Care actions';

  @override
  String get noSelection => 'Select at least one compatible care check.';

  @override
  String get previewHeading => 'Review your changes';

  @override
  String get aboutPreview => 'About this preview';

  @override
  String get appearance => 'Appearance';

  @override
  String get systemTheme => 'Use device appearance';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String plantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active plants',
      one: '1 active plant',
      zero: 'No active plants',
    );
    return '$_temp0';
  }

  @override
  String selectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count checks selected',
      one: '1 check selected',
    );
    return '$_temp0';
  }

  @override
  String dueOn(String date) {
    return 'Check on $date';
  }

  @override
  String lateDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Check is $count days overdue',
      one: 'Check is 1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String nextForPlant(String name, String date) {
    return 'Next: $name · $date';
  }

  @override
  String nextAfter(String date) {
    return 'Next check: $date';
  }

  @override
  String routineEvery(int count, String unit) {
    return 'Every $count $unit';
  }

  @override
  String plantNamed(String name, String species) {
    return '$name · $species';
  }

  @override
  String routineNamed(String name) {
    return '$name routine';
  }

  @override
  String get intervalUnit => 'Interval unit';

  @override
  String get positiveInterval => 'Enter a whole number from 1 to 9,999.';

  @override
  String get chooseCareBranch => 'Choose a known last-care date or Not sure.';

  @override
  String get keepCurrentSchedules =>
      'Existing care schedules and original suggestions will be kept. You can edit each routine from the plant details.';

  @override
  String get loadMore => 'Load more';

  @override
  String get paused => 'Paused — no checks scheduled';

  @override
  String get retired => 'Removed routine — history retained';

  @override
  String deletionCounts(
    int routines,
    int events,
    int corrections,
    int changes,
    int drafts,
  ) {
    return 'This removes $routines routines, $events care entries, $corrections corrections, $changes schedule changes and $drafts drafts.';
  }

  @override
  String recordedOn(String date) {
    return 'Recorded: $date';
  }

  @override
  String get careOutcome => 'Care outcome';

  @override
  String get reviewLatest => 'Review current version';

  @override
  String get keepMyFields => 'Keep my entered fields';

  @override
  String get conflictReview =>
      'Another action changed this plant or draft. Review the current values below. Keeping your entered fields replaces this draft version; final saving still needs a new review. Current care schedules are kept.';

  @override
  String get returnToReview => 'Return to review';

  @override
  String affectedPlant(String name) {
    return 'Changed selection: $name';
  }

  @override
  String get openingPlants => 'Opening your plants';

  @override
  String get recoveryHeading => 'Recover unfinished actions';

  @override
  String get developmentStorage => 'Development storage • Saved on this device';

  @override
  String get retainedStorageError =>
      'Your saved files are retained. Storage could not complete this action.';

  @override
  String get retryOpening => 'Retry opening';

  @override
  String get pendingActionExplanation =>
      'An earlier action has no confirmed result. Review it before making new changes.';

  @override
  String get retryPendingAction => 'Retry action';

  @override
  String get cancelPendingAction => 'Cancel action';

  @override
  String get cancelPendingTitle => 'Cancel this pending action?';

  @override
  String get retainDraftExplanation =>
      'Saved plants and the retained draft stay available.';

  @override
  String get keepPending => 'Keep pending';

  @override
  String get recoveredActionReview =>
      'Review the recovered action before saving.';

  @override
  String get saveDraftAction => 'Save unfinished draft';

  @override
  String get searchSpecies => 'Search species';

  @override
  String get popularSpecies => 'Popular';

  @override
  String get catalogLimited => 'Some plant guides are unavailable';

  @override
  String get catalogCustomAvailable =>
      'You can still add a custom plant. Your saved plants and care history are kept.';

  @override
  String noSpeciesMatches(String query) {
    return 'No matches for “$query”';
  }

  @override
  String get customPlant => 'Add a custom plant';

  @override
  String get speciesInformation => 'Species information';

  @override
  String get genericIllustration => 'Generic illustration';

  @override
  String get difficulty => 'Difficulty';

  @override
  String get suggestionOnly =>
      'A starting suggestion for checks. Adjust it to your plant and conditions.';

  @override
  String get sourcesCredits => 'Sources and credits';

  @override
  String get catalogCredits =>
      'Care summaries: Verdi. Generic illustration: Verdi design import. Names and source references are included for attribution. Source websites require an internet connection.';

  @override
  String get changeSpecies => 'Change species';

  @override
  String get keepRoutine => 'Keep current routine';

  @override
  String get applySuggestion => 'Apply suggestion';

  @override
  String get chooseSpeciesRoutine =>
      'Choose what happens to each existing routine.';

  @override
  String get originalSuggestion => 'Original suggestion';

  @override
  String get appliedSuggestion => 'Last applied suggestion';

  @override
  String get catalogIdentity => 'Catalog species';

  @override
  String get customIdentity => 'User-supplied species and observations';

  @override
  String get chooseSpecies => 'Choose species';

  @override
  String get catalogStale =>
      'This guide changed. Choose the species again or use a custom plant; your other fields are kept.';

  @override
  String get selectedSpecies => 'Selected species';

  @override
  String get contentReviewed => 'Content reviewed';

  @override
  String get category => 'Category';

  @override
  String createCustomQuery(String query) {
    return 'Create “$query” as a custom plant';
  }

  @override
  String get journalAndPhotos => 'Journal and photos';

  @override
  String get plantPhoto => 'Plant photo';

  @override
  String get photoUnavailableRetry => 'Photo unavailable · Retry';

  @override
  String get newJournalEntry => 'New journal entry';

  @override
  String get editJournalEntry => 'Edit entry';

  @override
  String get saveJournal => 'Save entry';

  @override
  String get journalSaveExplanation =>
      'Save this observation and its attached photo to this plant. Care history and next checks stay unchanged.';

  @override
  String get journalNote => 'Note';

  @override
  String get journalNoteLimit => 'Use up to 2,000 characters.';

  @override
  String get observationDate => 'Observation date';

  @override
  String get photoObservationDate => 'Photo observation date';

  @override
  String get chooseObservationDate => 'Choose observation date';

  @override
  String get invalidObservationDate => 'Choose today or an earlier date.';

  @override
  String get journalHint =>
      'A photo or a note is enough. Change the date to log an earlier observation. All journal history stays available.';

  @override
  String get discardJournal => 'Discard this entry draft?';

  @override
  String get discardJournalExplanation =>
      'Unsaved notes and newly attached photos in this draft will be removed. Saved entries and originals remain.';

  @override
  String get saveNoteOnly => 'Save note only';

  @override
  String get saveNoteOnlyExplanation =>
      'Continue without the photo that failed to attach. Your note will be saved after you review it.';

  @override
  String get continueAction => 'Continue';

  @override
  String get removeAttachment => 'Remove attachment';

  @override
  String get camera => 'Camera';

  @override
  String get library => 'Library';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get reviewJournalConflict => 'Review newer version';

  @override
  String get rebaseJournalExplanation =>
      'Keep this draft’s note, date and photos while accepting the current saved entry as its editing base. Review and save the entry separately.';

  @override
  String get photos => 'Photos';

  @override
  String get photosEmpty =>
      'No saved photos yet. Add a photo to a journal entry or plant cover.';

  @override
  String get coverPhoto => 'Cover photo';

  @override
  String get setCover => 'Set as cover';

  @override
  String get removeCover => 'Remove cover';

  @override
  String get changePhotoDate => 'Change photo date';

  @override
  String get photoDateExplanation =>
      'Change only this photo’s observation date. Journal dates and care history remain unchanged.';

  @override
  String get exportOriginal => 'Export original';

  @override
  String get shareOriginal => 'Share original';

  @override
  String get originalMetadataWarning =>
      'The original file may include location, device and other embedded metadata. Share only if you want the selected destination to receive that information.';

  @override
  String get originalHandedToOS => 'Original handed to the selected app.';

  @override
  String get originalExportUnknown =>
      'The sharing result is uncertain. Check the selected app before sharing this original again.';

  @override
  String get originalExporting => 'Waiting for the sharing result…';

  @override
  String get shareCancelled => 'Sharing cancelled.';

  @override
  String get shareFailed => 'The original could not be shared. Please retry.';

  @override
  String get deletePhoto => 'Delete photo';

  @override
  String get deletePhotoExplanation =>
      'Remove this original from covers, journal entries and drafts. Notes and unrelated care history stay. Photo-only entries that become empty are removed. Any open replacement or affected entry draft must be finished or discarded first.';

  @override
  String get replacePhoto => 'Replace photo';

  @override
  String get replacementExplanation =>
      'Every saved reference keeps the same photo identity. The existing original stays available until the replacement is saved successfully.';

  @override
  String get reviewReplacement => 'Review replacement';

  @override
  String get checkAttachment => 'Check attachment status';

  @override
  String get rebasePhotoExplanation =>
      'Keep the prepared replacement and accept the current photo as its base. Review the replacement separately before saving.';

  @override
  String get discardReplacement => 'Discard replacement';

  @override
  String get discardReplacementExplanation =>
      'Remove this prepared replacement. The saved original and its references remain unchanged.';

  @override
  String get deleteJournalEntry => 'Delete entry';

  @override
  String get deleteJournalExplanation =>
      'Remove this entry and its open edit draft, including any unsaved draft photos. Saved originals remain in the gallery. Unrelated notes and care history stay.';

  @override
  String get photoOptionalHint =>
      'A photo is optional. Your other plant fields stay in the draft.';

  @override
  String get cameraDenied =>
      'Camera access is off. You can open Settings, choose Library, or continue without a photo.';

  @override
  String get cameraUnavailable =>
      'The camera is unavailable on this device. Choose Library or continue without a photo.';

  @override
  String get photoInvalid =>
      'Choose a complete still JPEG, PNG or HEIC image. Animated or unreadable files cannot be attached.';

  @override
  String get photoTooLarge =>
      'Choose a photo no larger than 64 MB and 100 megapixels.';

  @override
  String get photoNotReady =>
      'The photo is not ready. Check its status or retry before saving.';

  @override
  String get photoMissing =>
      'The original file is unavailable. Your note and care history are still retained.';

  @override
  String get photoSelectionExpired =>
      'Choose the photo again. This temporary selection is no longer available.';

  @override
  String get futureObservation =>
      'An observation cannot be dated in the future.';

  @override
  String get emptyJournal => 'Add a note or a photo before saving.';

  @override
  String get photoContinueWithout => 'Continue without the new photo';

  @override
  String get journalDraftConflictExplanation =>
      'This draft changed elsewhere. Keep the text, date and selected photos shown in this editor, replacing the current draft fields? Saved journal entries remain unchanged until you review and save.';

  @override
  String get backupTitle => 'Backup & restore';

  @override
  String get backupExplanation =>
      'Keep a portable copy of your plants, care history, journals, photos and saved drafts. Backup and restore are free.';

  @override
  String get backupPrivacy =>
      'The ZIP includes your private notes and photos. It is not password-encrypted. Share it only with a destination you trust.';

  @override
  String get backupCreate => 'Create backup';

  @override
  String get backupChoose => 'Choose backup file';

  @override
  String get backupReplaceTitle => 'Replace this collection?';

  @override
  String get backupReplaceWarning =>
      'Restoring replaces all plants, care history, journals, photos, saved drafts and preferences on this device with the backup. It does not merge collections. Create a backup first if you want to keep your current collection.';

  @override
  String get backupReplace => 'Replace collection';

  @override
  String get backupWorking => 'Preparing and checking your backup…';

  @override
  String get backupReplacing =>
      'Restoring your collection. Wait for verification before leaving this screen.';

  @override
  String get backupPreview => 'Ready to restore';

  @override
  String backupCounts(
    String active,
    String archived,
    String events,
    String journals,
    String photos,
  ) {
    return '$active active plants · $archived archived plants\n$events history entries · $journals journal entries · $photos photos';
  }

  @override
  String get backupCreated => 'File created';

  @override
  String get backupHanded => 'Shared with another app';

  @override
  String get backupKeepOutside =>
      'Save a copy outside Verdi and this device. Creating a file or opening the share sheet does not verify an external backup.';

  @override
  String get backupShare => 'Share / Save a copy';

  @override
  String get backupShareCancelled =>
      'Sharing was cancelled. The file is still available here.';

  @override
  String get backupShareFailed =>
      'Sharing did not finish. Your file is still available; try another destination.';

  @override
  String get backupRestored =>
      'Your backup was restored and the collection was reopened.';

  @override
  String get backupCancelled =>
      'Cancelled. Your current collection is unchanged.';

  @override
  String get backupCheckStatus => 'Check restore status';

  @override
  String get backupReviewAgain => 'Validate and review again';

  @override
  String get backupStale =>
      'Your collection or saved drafts changed after this preview. Validate again and review the new preview.';

  @override
  String get backupBusy =>
      'Finish any pending save or photo selection and close any share sheet, then try again. Your collection has not been replaced.';

  @override
  String get backupDiskFull =>
      'There is not enough free space to create and verify a safe copy. Free some device storage, then try again.';

  @override
  String get backupMissingPhoto =>
      'An original photo is missing. Your other content is still available. Resolve the missing photo before creating a complete backup.';

  @override
  String get backupUnsupported =>
      'This backup version is not supported by this version of Verdi. Your collection is unchanged.';

  @override
  String get backupLimit =>
      'This backup exceeds a supported size or content limit. Nothing was truncated or replaced.';

  @override
  String get backupInvalid =>
      'This file is incomplete, damaged or not a supported Verdi backup. Your collection has not been replaced.';

  @override
  String get backupFailure =>
      'The operation could not finish. Keep your backup file. Check the status or try again; Verdi retains the previous collection during recovery.';

  @override
  String get backupLocaleFallback =>
      'The restored language preference is retained, but is not supported yet. Verdi is using device formatting.';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersBestEffort =>
      'Get local reminders to check your plants. Delivery is approximate and depends on your device settings.';

  @override
  String remindersPermission(String status) {
    return 'Notification permission: $status';
  }

  @override
  String get remindersEnable => 'Enable reminders';

  @override
  String get remindersAllow => 'Allow notifications';

  @override
  String get remindersSystemSettings => 'Open system settings';

  @override
  String get remindersNeedsSchedule =>
      'Save a plant with a care schedule before allowing notifications.';

  @override
  String get remindersPreferredTime => 'Preferred local time';

  @override
  String get remindersQuietStart => 'Quiet hours start';

  @override
  String get remindersQuietEnd => 'Quiet hours end';

  @override
  String get remindersQuietExplanation =>
      'Equal start and end times turn quiet hours off. Otherwise, reminders move to the end of quiet hours, sometimes the next day. Care dates stay unchanged.';

  @override
  String get remindersSave => 'Save reminder settings';

  @override
  String get remindersRetrySave => 'Resolve and retry save';

  @override
  String get remindersUnknownSave =>
      'Your save is unresolved. Keep these inputs and retry to check whether it was saved before sending it again.';

  @override
  String get remindersSaved =>
      'Reminder settings saved. Scheduling status is shown below.';

  @override
  String get remindersReload => 'Reload saved settings';

  @override
  String get remindersRetryQueue => 'Retry scheduling';

  @override
  String get remindersTodayAuthority =>
      'Today always shows your checks, even when a reminder is delayed or unavailable. Past reminder times do not trigger a catch-up burst.';

  @override
  String remindersQueueCounts(int pending, int omitted, int past) {
    return 'Confirmed pending: $pending. Omitted for capacity: $omitted. Past reminder times: $past.';
  }

  @override
  String get remindersNotAsked => 'Not requested';

  @override
  String get remindersDenied =>
      'Notifications are not permitted. Today and care logging still work.';

  @override
  String get remindersAuthorized => 'Allowed';

  @override
  String get remindersQuietPermission => 'Quiet authorization';

  @override
  String get remindersUnavailable =>
      'Reminder status is unavailable. Your saved care remains available.';

  @override
  String get remindersQueueReady =>
      'The current queue has been checked. This does not confirm delivery.';

  @override
  String get remindersOff => 'Reminders are off.';

  @override
  String get remindersPartial =>
      'Some reminders could not be scheduled. Retry or review system settings.';

  @override
  String get remindersDeferred => 'Scheduling is waiting for a fresh check.';

  @override
  String get remindersContextOffer =>
      'Your schedule is saved. Choose whether to allow local reminders.';

  @override
  String get remindersCurrentTap =>
      'Review your current checks below. Opening a reminder does not record care.';

  @override
  String get remindersStaleTap =>
      'This reminder has changed or is no longer current. Today shows your current checks; no care was recorded.';

  @override
  String get remindersWaitingTap =>
      'A reminder is waiting. Finish or save this screen, then open Today. No care has been recorded.';

  @override
  String get remindersOpenToday => 'Open Today';

  @override
  String get proTitle => 'Verdi Pro';

  @override
  String get proActive => 'Room to grow';

  @override
  String get proRoom => 'Make room for every plant';

  @override
  String get proBenefit =>
      'Pro gives you unlimited active plants, new custom care types and routines, and dated photo comparisons in this preview.';

  @override
  String get proFree =>
      'Free includes five active plants, standard care, all history, reminders and backup. Your existing plants and records stay yours.';

  @override
  String get proTestNotice =>
      'Local StoreKit test · simulated purchase, no real charge.';

  @override
  String get proCached => 'Your verified purchase is available offline.';

  @override
  String get proOneTime => 'One-time purchase';

  @override
  String get proUnavailable =>
      'The store offer is unavailable. You can still restore purchases or continue using Free.';

  @override
  String get proBuy => 'Get Pro';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get proContinue => 'Continue';

  @override
  String get proContinueFree => 'Continue Free';

  @override
  String get proRecovery =>
      'The purchase result could not be confirmed. Your data is safe. Retry the status check or restore purchases before trying again.';

  @override
  String get proPending =>
      'Approval is pending. You can continue using Free; approval will not save a plant automatically.';

  @override
  String get proWorking => 'Checking with the store…';

  @override
  String get proCancelled => 'Purchase cancelled. Your draft is still here.';

  @override
  String get proFailed =>
      'The purchase could not be verified. Your last verified access and existing data are preserved.';

  @override
  String get proNoneFound =>
      'No matching verified purchase was found. Any previously verified access is preserved.';

  @override
  String get proRevoked =>
      'Pro is no longer active. Your existing plants, history and care routines remain available.';

  @override
  String get proRetryPending => 'Retry pending purchase';

  @override
  String get proRetryPendingBody =>
      'An earlier approval request may still exist. Retrying does not cancel it and may open a new store request. No plant will save automatically. Continue?';

  @override
  String get customCare => 'Custom care';

  @override
  String get customCarePro =>
      'Creating custom care types and routines requires Pro. Existing care stays editable on Free.';

  @override
  String get careTypes => 'Care types';

  @override
  String get addCustomCare => 'Add custom care type';

  @override
  String get careTypeLabel => 'Care type name';

  @override
  String get careTypeLabelInvalid => 'Enter 1–24 characters.';

  @override
  String get renameCareType => 'Rename care type';

  @override
  String get retireCareType => 'Retire care type';

  @override
  String get retiredCareType => 'Retired — existing routines retained';

  @override
  String get retireCareTypeBody =>
      'Hide this type from new care choices. Existing routines and history remain.';

  @override
  String get renameCareTypeBody =>
      'Update current routine labels. Historical labels and reminder dates remain unchanged.';

  @override
  String get addCare => 'Add care';

  @override
  String get careType => 'Care type';

  @override
  String get careFormDiscard => 'Discard this unsaved care form?';

  @override
  String get noCareChoices =>
      'All standard care types are already added. Create custom care types in Settings.';

  @override
  String careTypeEffects(int count) {
    return 'Affected routines: $count';
  }

  @override
  String get sharePlantCard => 'Share plant card';

  @override
  String get comparePhotos => 'Compare photos';

  @override
  String get cardPrivacy =>
      'Only the previewed name, species, selected images and Verdi attribution are included. Comparisons also include the photo dates. Notes, location and original image metadata stay out. Sharing may send the image to an app you choose.';

  @override
  String get cardChooseTwo =>
      'Choose two photos. Their recorded dates appear on the comparison.';

  @override
  String get cardNeedsTwo =>
      'Add at least two photos of this plant to create a comparison.';

  @override
  String get cardUseIllustration => 'Use the plant illustration';

  @override
  String get cardPreview => 'Preview card';

  @override
  String get cardRefresh => 'Refresh preview';

  @override
  String get cardSave => 'Save image';

  @override
  String get cardShare => 'Share';

  @override
  String get cardViewPro => 'View one-time Pro';

  @override
  String get cardReload => 'Reload photos and choices';

  @override
  String get cardRefreshRequired =>
      'This preview is no longer current. Refresh it and review the image before saving or sharing.';

  @override
  String get cardReselectRequired =>
      'The collection or selected content changed. Reload and choose again.';

  @override
  String get cardMediaUnavailable =>
      'A selected photo is unavailable. Reload to choose another, or use the plant illustration. Your originals are unchanged.';

  @override
  String get cardProRequired =>
      'Photo comparison is a Pro feature. You can view one-time Pro or go back; every original photo remains available. After upgrading, choose Preview card again.';

  @override
  String get cardPermissionDenied =>
      'Photos access was denied. Allow Verdi to add photos in Settings, then retry if you want to save. Your preview is still available.';

  @override
  String get cardSaveUnknown =>
      'The save result is uncertain. Check Photos before choosing Save image again.';

  @override
  String get cardSaveFailed =>
      'The image could not be saved. Your preview is still available; you can retry.';

  @override
  String get cardFailed =>
      'The card could not be prepared or handed off. Your originals are unchanged. Please try again.';

  @override
  String get cardSaved => 'Image saved.';

  @override
  String get cardHandedToOS =>
      'Image handed to the selected app. Verdi cannot confirm publication or delivery.';

  @override
  String get cardCancelled =>
      'Sharing cancelled. Your preview is still available.';

  @override
  String get privacyTitle => 'Privacy & local data';

  @override
  String get helpTitle => 'Help & feedback';

  @override
  String get licensesTitle => 'Open-source licenses';

  @override
  String get privacyLocalTitle => 'Your collection on this device';

  @override
  String get privacyLocalBody =>
      'Verdi keeps plants, care history, journals, photos and drafts in local app storage. Core care needs no account. This preview has no app-operated sync, analytics SDK, automatic crash-report upload or remote AI. Photos are not used to infer species, health or pet safety.';

  @override
  String get privacyExternalTitle => 'Actions that can involve other services';

  @override
  String get privacyExternalBody =>
      'Purchases and Restore use the platform store and may need a connection. Sharing a photo, card or backup opens an operating-system destination chooser. Feedback is reviewed before you copy it; clipboard content can be read or shared according to your OS settings. These actions do not happen just because you open a plant or preview.';

  @override
  String get privacyBackupTitle => 'Keep a recoverable copy';

  @override
  String get privacyBackupBody =>
      'Device backup or transfer may include app data according to your OS settings; Verdi cannot guarantee its coverage or success. Before uninstalling, replacing or losing a device, keep an independently recoverable backup. Verdi portable backups are unencrypted and may contain photos, notes and drafts. Choose where you store or share them carefully. A share callback does not prove another device can restore the backup.';

  @override
  String get privacyDeleteTitle => 'Deletion and copies';

  @override
  String get privacyDeleteBody =>
      'Archiving keeps a plant and its history while hiding active care and reminders. Permanent deletion requires separate confirmation. Deleting local content cannot delete copies you already exported, shared or saved through Photos, device backup or another service.';

  @override
  String get privacyReviewTitle => 'Development preview';

  @override
  String get privacyReviewBody =>
      'This local-data guide describes the current preview. Public privacy-policy links, support contact details and platform data disclosures are still being prepared and reviewed against the release build. This is not a “Data Not Collected” declaration.';

  @override
  String get helpCareTitle => 'Check first, then record care';

  @override
  String get helpCareBody =>
      'A due or late check is a reminder to inspect your plant, not a diagnosis or proof it needs water. Choose the care you actually performed, or “Checked — not needed” and a new check date. Unknown last care creates no invented history.';

  @override
  String get helpHistoryTitle => 'Correct history without moving a reminder';

  @override
  String get helpHistoryBody =>
      'Adding past care or correcting a history entry updates the record while leaving the current next check unchanged. Edit the next-check date separately when needed. Archiving keeps existing records; permanent deletion is a separate confirmed action.';

  @override
  String get helpCatalogTitle => 'Species and safety';

  @override
  String get helpCatalogBody =>
      'If species content is unavailable, you can still add a custom plant. “Unknown” toxicity does not mean safe to ingest. Photos do not generate care, health or pet-safety advice.';

  @override
  String get helpReminderTitle => 'Reminder delivery';

  @override
  String get helpReminderBody =>
      'Reminders depend on notification permission and the operating system, including Focus, summaries and device settings. A queue check confirms scheduling work, not delivery. Paused and archived plants keep their records without active reminders.';

  @override
  String get helpBackupTitle => 'Restore replaces the collection';

  @override
  String get helpBackupBody =>
      'Review a backup before confirming restore. Restore replaces rather than merges this device’s collection, including valid saved drafts; it does not import a Pro entitlement. A failed or uncertain restore needs recovery, not a new empty collection.';

  @override
  String get helpMediaTitle => 'Photos, sharing and one-time Pro';

  @override
  String get helpMediaBody =>
      'Original photos and journal history remain available on Free. A plant card is free; dated photo comparison is Pro. Save image asks only for permission to add to Photos. If a save result is uncertain, check Photos before explicitly retrying. An OS handoff is not proof a post or message reached someone.';

  @override
  String get feedbackTitle => 'Prepare feedback';

  @override
  String get feedbackNoDestination =>
      'Direct support contact is not configured in this preview. You can edit and copy a message to use in a channel you choose. Nothing is sent here.';

  @override
  String get feedbackPrivacy =>
      'The initial message includes only app, build and OS versions. No plant, photo, history, log, device identifier or purchase evidence is attached. Review anything you add before copying. This draft is kept only while this page is open. Clipboard content may be read or shared according to your OS settings.';

  @override
  String get feedbackDefaultSubject => 'Verdi feedback';

  @override
  String feedbackDefaultBody(String version, String build, String os) {
    return 'Verdi Preview $version (build $build)\niOS $os\n\nDescribe your feedback:\n';
  }

  @override
  String get feedbackUnavailable => 'unavailable';

  @override
  String get feedbackSubject => 'Subject';

  @override
  String get feedbackMessage => 'Message';

  @override
  String get feedbackSubjectError => 'Enter 1–200 characters of valid text.';

  @override
  String get feedbackBodyError => 'Use up to 4,000 characters of valid text.';

  @override
  String get feedbackCopy => 'Copy feedback';

  @override
  String get feedbackCopied => 'Feedback copied. Nothing was sent.';

  @override
  String get feedbackCopyUnknown =>
      'Copying was not confirmed. Your edits are still here; check the clipboard or choose Copy feedback again.';

  @override
  String get feedbackLoadFailed =>
      'App details could not be loaded. Help and your collection are still available. Retry to prepare feedback.';

  @override
  String get feedbackDiscardTitle => 'Discard this feedback draft?';

  @override
  String get feedbackDiscardBody =>
      'Your edited message is kept only on this page. A copy you already made will remain on the clipboard.';

  @override
  String get optimizePhotos => 'Optimize photos';

  @override
  String get optimizationIntro =>
      'Choose up to 200 saved photos. Nothing is selected automatically. Optimization is optional and available for Free.';

  @override
  String get optimizationWarning =>
      'Replace the selected app-stored originals with JPEGs at quality 85%, up to 1280 pixels on the longest edge, without enlarging them. Metadata is removed. Cover and journal views will use the replacements. Files may not become smaller. Alpha-bearing images are skipped to preserve transparency. Export originals or make a backup first if you want to keep them. Copies outside Verdi are unchanged.';

  @override
  String get optimizationReview => 'Review selected photos';

  @override
  String get optimizationConfirm => 'Replace selected originals';

  @override
  String get optimizationCancel => 'Cancel remaining';

  @override
  String get optimizationRecovery => 'Resolve interrupted job';

  @override
  String get optimizationResults => 'Optimization results';

  @override
  String get optimizationRunning => 'Working on selected photos…';

  @override
  String get optimizationComplete =>
      'Finished. Each photo’s result is shown below.';

  @override
  String get optimizationCancelled =>
      'Remaining work cancelled. Completed replacements are kept.';

  @override
  String get optimizationInterrupted =>
      'Interrupted. Saved receipts were checked; no replacements were resumed.';

  @override
  String get optimizationFailureHelp =>
      'Failed and unattempted originals remain unchanged. A retained replacement draft can be opened or explicitly discarded in the photo viewer before a fresh selection and confirmation.';

  @override
  String get optimizationRecoveryNeeded =>
      'The stop result is not yet confirmed. Resolve this job before starting another or restoring a backup.';

  @override
  String get optimizationLeaveTitle => 'Cancel remaining optimization?';

  @override
  String get optimizationLeaveBody =>
      'Completed replacements will be kept. Resolve any pending result before leaving.';

  @override
  String get optimizationSucceeded => 'Replaced';

  @override
  String get optimizationFailed => 'Original kept — failed';

  @override
  String get optimizationNotAttempted => 'Not attempted';

  @override
  String get optimizationPending => 'Pending';

  @override
  String get optimizationNoPhotos =>
      'No saved photos are available for this plant.';

  @override
  String get optimizationConflict =>
      'Finish or explicitly discard this photo’s existing replacement draft before optimizing it.';

  @override
  String get optimizationUnsupported =>
      'Alpha-bearing or unsupported image; original kept.';

  @override
  String get optimizationGenericError =>
      'Optimization could not continue. Your saved photos and recoverable drafts remain available.';

  @override
  String get optimizationNotStarted =>
      'No optimization job was recorded. Review your selection again.';

  @override
  String optimizationPhoto(int number) {
    return 'Photo $number';
  }

  @override
  String optimizationDimensions(int width, int height, int bytes) {
    return '$width × $height pixels · $bytes bytes';
  }

  @override
  String get optimizationPhotoUnavailable =>
      'This photo is no longer available in this plant.';

  @override
  String get optimizationOpenPhoto => 'Open photo and replacement draft';

  @override
  String get optimizationDiskFull =>
      'Not enough storage to prepare this replacement. Free space, then review a new selection.';

  @override
  String get optimizationWriteFailure =>
      'The replacement file could not be saved. The prior photo was not replaced.';

  @override
  String get developmentShortNotice => 'Development preview';

  @override
  String get gridView => 'Grid view';

  @override
  String get listView => 'List view';

  @override
  String get careTab => 'Care';

  @override
  String get historyTab => 'History';

  @override
  String get statsTab => 'Stats';

  @override
  String get careAndReminders => 'Care & reminders';

  @override
  String get yourData => 'Your data';

  @override
  String get supportSection => 'Support';

  @override
  String get artworkCredits => 'Artwork credits';

  @override
  String get artworkAttribution =>
      'Botanical illustrations and interface icons: Verdi design import. Used with permission confirmed by the owner.';

  @override
  String get statsCareCount => 'Actual care recorded';

  @override
  String get statsExplanation =>
      'Counts include recorded actual care across all routines, including retired routines. Checks and skipped care are excluded.';

  @override
  String checksDueSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count checks to make.',
      one: 'One check to make.',
    );
    return '$_temp0';
  }

  @override
  String get checksDueBody => 'Check your plants before recording care.';

  @override
  String get plantDetailsSection => 'Plant details';

  @override
  String get routineSection => 'Care routines';

  @override
  String intervalDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Every $_temp0';
  }

  @override
  String intervalWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return 'Every $_temp0';
  }

  @override
  String intervalMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return 'Every $_temp0';
  }

  @override
  String intervalYear(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return 'Every $_temp0';
  }

  @override
  String get clearSearch => 'Clear search';

  @override
  String get noArchivedPlants => 'No archived plants';

  @override
  String get noArchivedPlantsBody =>
      'Archived plants stay here with their history and photos.';

  @override
  String get auditBefore => 'Before';

  @override
  String get auditAfter => 'After';

  @override
  String get auditInterval => 'Interval';

  @override
  String get auditNext => 'Next check';

  @override
  String get auditAnchor => 'Recurrence anchor';

  @override
  String get auditFirstAnchor => 'First-check anchor (no completed care)';

  @override
  String get auditCareAnchor => 'Completed-care anchor';

  @override
  String get auditFirstDate => 'Chosen first check';

  @override
  String get auditOverride => 'Date override';

  @override
  String get auditNone => 'None';

  @override
  String get auditActive => 'Active';

  @override
  String get auditPaused => 'Paused';

  @override
  String get auditRetired => 'Retired';

  @override
  String get auditStatus => 'Routine status';

  @override
  String get auditArchived => 'Plant archived';

  @override
  String get auditYes => 'Yes';

  @override
  String get auditNo => 'No';

  @override
  String get auditRecorded => 'Recorded at (UTC)';

  @override
  String get auditIntervalChange => 'Interval changed';

  @override
  String get auditSpeciesChange => 'Species suggestions applied';

  @override
  String get auditOverrideChange => 'Check date changed';

  @override
  String get auditPause => 'Routine paused';

  @override
  String get auditResume => 'Routine resumed';

  @override
  String get auditRetire => 'Routine removed';

  @override
  String get auditArchive => 'Plant archived';

  @override
  String get auditRestore => 'Plant restored';

  @override
  String get auditUndo => 'Action undone';
}
