import '../../../pro/presentation/pro_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubits/workspace_cubit.dart';

AppStrings strings(BuildContext context) => AppStrings.of(context);
String dateLabel(BuildContext context, LocalDate date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString())
        .format(DateTime.utc(date.year, date.month, date.day));
String unitLabel(AppStrings s, IntervalUnit unit) => switch (unit) {
  IntervalUnit.day => s.days,
  IntervalUnit.week => s.weeks,
  IntervalUnit.month => s.months,
  IntervalUnit.year => s.years,
};
String outcomeLabel(AppStrings s, CareOutcome outcome, StandardCareKind kind) =>
    switch (outcome) {
      CareOutcome.actualCare => kindLabel(s, kind, actual: true),
      CareOutcome.checkedNotNeeded => s.checkedNotNeeded,
      CareOutcome.skipped => s.skipCheck,
    };

Future<CareOutcome?> chooseOutcome(
  BuildContext context,
  StandardCareKind kind, {
  CareOutcome initial = CareOutcome.actualCare,
}) => showDialog<CareOutcome>(
  context: context,
  builder: (context) {
    final s = strings(context);
    return SimpleDialog(
      title: Text(s.careOutcome),
      children: [
        for (final value in CareOutcome.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, value),
            child: Row(
              children: [
                Icon(
                  value == initial
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(outcomeLabel(s, value, kind))),
              ],
            ),
          ),
      ],
    );
  },
);

Future<CareInterval?> chooseInterval(
  BuildContext context,
  CareInterval current,
) async {
  var rawCount = current.count.toString();
  var unit = current.unit;
  var invalid = false;
  final result = await showDialog<CareInterval>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        final s = strings(context);
        return AlertDialog(
          title: Text(s.editInterval),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: rawCount,
                onChanged: (value) => rawCount = value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: s.interval,
                  errorText: invalid ? s.positiveInterval : null,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<IntervalUnit>(
                initialValue: unit,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.intervalUnit),
                items: [
                  for (final value in IntervalUnit.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(unitLabel(s, value)),
                    ),
                ],
                onChanged: (value) => unit = value!,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () {
                final count = RegExp(r'^[0-9]+$').hasMatch(rawCount)
                    ? int.tryParse(rawCount)
                    : null;
                if (count == null || count < 1 || count > 9999) {
                  update(() => invalid = true);
                  return;
                }
                Navigator.pop(context, CareInterval(count, unit));
              },
              child: Text(s.continueLabel),
            ),
          ],
        );
      },
    ),
  );
  return result;
}

String kindLabel(AppStrings s, StandardCareKind kind, {bool actual = false}) =>
    switch (kind) {
      StandardCareKind.water => actual ? s.watered : s.checkWatering,
      StandardCareKind.fertilize => actual ? s.fertilized : s.fertilize,
      StandardCareKind.mist => actual ? s.misted : s.mist,
      StandardCareKind.repot => actual ? s.repotted : s.repot,
      StandardCareKind.rotate => actual ? s.rotated : s.rotate,
    };

String errorLabel(AppStrings s, String code) => switch (code) {
  'CAMERA_DENIED' => s.cameraDenied,
  'CAMERA_UNAVAILABLE' || 'MEDIA_UNAVAILABLE' => s.cameraUnavailable,
  'MEDIA_INVALID' => s.photoInvalid,
  'MEDIA_TOO_LARGE' => s.photoTooLarge,
  'MEDIA_BUSY' || 'MEDIA_NOT_READY' => s.photoNotReady,
  'MEDIA_MISSING' => s.photoMissing,
  'MEDIA_SELECTION_EXPIRED' => s.photoSelectionExpired,
  'FUTURE_OBSERVATION_DATE' => s.futureObservation,
  'EMPTY_ENTRY' => s.emptyJournal,
  'CATALOG_SELECTION_STALE' || 'CATALOG_CHANGED' => s.catalogStale,
  'UNDO_EXPIRED' || 'UNDO_CHANGED' || 'UNDO_UNAVAILABLE' => s.undoUnavailable,
  'STALE_TARGET' ||
  'PREVIEW_STALE' ||
  'READ_STALE' ||
  'DRAFT_CONFLICT' => s.staleSelection,
  'ACTIVE_LIMIT' => s.activeLimit,
  'FUTURE_CARE_DATE' => s.futureCare,
  'CARE_PRECEDES_LATEST' => s.earlierCare,
  'FIRST_CHECK_REQUIRED' => s.firstCheckRequired,
  'FIELD_INVALID' || 'DATE_OVERFLOW' => s.fieldInvalid,
  'UNKNOWN_OUTCOME' => s.unknownSave,
  'NOT_FOUND' || 'NOT_ELIGIBLE' || 'DATASET_CHANGED' => s.notAvailable,
  _ => s.storageFailure,
};

class ErrorNotice extends StatelessWidget {
  final String code;
  const ErrorNotice(this.code, {super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        errorLabel(strings(context), code),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}

Future<LocalDate?> chooseDate(
  BuildContext context, {
  LocalDate? initial,
  LocalDate? latest,
  LocalDate? earliest,
  String? helpText,
}) async {
  final today = context.read<WorkspaceCubit>().today;
  final candidate = initial ?? today;
  final start = latest != null && candidate.compareTo(latest) > 0
      ? latest
      : candidate;
  final chosen = await showDatePicker(
    context: context,
    helpText: helpText,
    initialDate: DateTime(start.year, start.month, start.day),
    firstDate: earliest == null
        ? DateTime(1)
        : DateTime(earliest.year, earliest.month, earliest.day),
    lastDate: latest == null
        ? DateTime(9999, 12, 31)
        : DateTime(latest.year, latest.month, latest.day),
  );
  return chosen == null
      ? null
      : LocalDate(chosen.year, chosen.month, chosen.day);
}

/// Modal keeps the exact preview while resolving errors. Cancel abandons only a
/// known uncommitted command. It never turns an uncertain save into a new one.
Future<CommandSuccess?> reviewCommand(
  BuildContext context,
  PreparedCommand preview, {
  String? title,
  String? explanation,
}) => showDialog<CommandSuccess>(
  context: context,
  barrierDismissible: false,
  builder: (_) => BlocProvider.value(
    value: context.read<WorkspaceCubit>(),
    child: _CommandReview(
      preview: preview,
      title: title,
      explanation: explanation,
    ),
  ),
);

class _CommandReview extends StatefulWidget {
  final PreparedCommand preview;
  final String? title;
  final String? explanation;
  const _CommandReview({required this.preview, this.title, this.explanation});
  @override
  State<_CommandReview> createState() => _CommandReviewState();
}

class _CommandReviewState extends State<_CommandReview> {
  late PreparedCommand currentPreview = widget.preview;
  Future<void> upgrade() async {
    final workspace = context.read<WorkspaceCubit>();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final purchased = await openPro(context, command: currentPreview.intent);
      if (!mounted) return;
      if (purchased) {
        final old = currentPreview.intent;
        final resolution = await workspace.resolveCommand(old.commandId);
        if (resolution.committed) {
          if (mounted) Navigator.of(context).pop(resolution.result);
          return;
        }
        currentPreview = await workspace.prepare(
          old.command,
          commandId: old.commandId,
        );
      }
    } catch (e) {
      error = WorkspaceCubit.code(e);
    }
    if (mounted) setState(() => busy = false);
  }

  bool busy = false;
  String? error;
  Set<String> affected = {};
  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    final preview = currentPreview;
    final command = preview.intent.command;
    final stale = const {
      'STALE_TARGET',
      'PREVIEW_STALE',
      'PREVIEW_EXPIRED',
      'NOT_FOUND',
      'NOT_ELIGIBLE',
      'DRAFT_CONFLICT',
      'DATASET_CHANGED',
    }.contains(error);
    final actualDate = switch (command) {
      CompleteCurrent c => c.careDate,
      BulkComplete c => c.careDate,
      AddPastCare c => c.careDate,
      CorrectEvent c => c.careDate,
      CheckNotNeeded c => c.checkDate,
      _ => null,
    };
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.title ?? s.previewHeading),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.explanation != null) Text(widget.explanation!),
            if (preview.effects.historyOnly) Text(s.historyOnly),
            if (command is BulkComplete)
              Text(s.selectionCount(command.targets.length)),
            if (actualDate != null)
              Text(
                '${command is CheckNotNeeded ? s.checkDate : s.actualCareDate}: ${dateLabel(context, actualDate)}',
              ),
            if (command is SetInterval)
              Text(
                s.routineEvery(
                  command.interval.count,
                  unitLabel(s, command.interval.unit),
                ),
              ),
            if (command is DeletePlant)
              Text(
                s.deletionCounts(
                  preview.effects.routines,
                  preview.effects.events,
                  preview.effects.corrections,
                  preview.effects.scheduleChanges,
                  preview.effects.drafts,
                ),
              ),
            for (final row in preview.effects.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.plantName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (row.careKind != null) Text(kindLabel(s, row.careKind!)),
                    if (affected.contains(row.routineId))
                      Text(
                        s.affectedPlant(row.plantName),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (row.newNextCheck != null)
                      Text(s.nextAfter(dateLabel(context, row.newNextCheck!))),
                  ],
                ),
              ),
            if (preview.effects.gate == PreviewGate.activeLimit)
              Text(s.activeLimit),
            if (error != null) ErrorNotice(error!),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
        actions: [
          if (preview.effects.gate == PreviewGate.activeLimit &&
              ProHost.maybeOf(context) != null)
            FilledButton(
              onPressed: busy ? null : upgrade,
              child: Text(s.proTitle),
            ),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final resolution = await context
                          .read<WorkspaceCubit>()
                          .abandon(preview);
                      if (context.mounted) {
                        Navigator.of(context).pop(resolution.result);
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          busy = false;
                          error = WorkspaceCubit.code(e);
                          affected = e is CommandRejected
                              ? e.fields.keys.toSet()
                              : {};
                        });
                      }
                    }
                  },
            child: Text(stale ? s.returnToReview : s.cancel),
          ),
          FilledButton(
            onPressed:
                busy || stale || preview.effects.gate != PreviewGate.allowed
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final result = await context
                          .read<WorkspaceCubit>()
                          .confirm(preview);
                      if (context.mounted) Navigator.of(context).pop(result);
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          busy = false;
                          error = WorkspaceCubit.code(e);
                          affected = e is CommandRejected
                              ? e.fields.keys.toSet()
                              : {};
                        });
                      }
                    }
                  },
            child: Text(error == null ? s.confirm : s.retry),
          ),
        ],
      ),
    );
  }
}
