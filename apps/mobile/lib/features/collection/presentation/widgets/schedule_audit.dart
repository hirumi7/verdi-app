import 'package:flutter/material.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../data/repositories/collection_repository.dart';
import 'presentation_helpers.dart';

Future<void> showScheduleAudit(
  BuildContext context, {
  required CollectionRepository repository,
  required String datasetId,
  required String plantId,
  required String changeId,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ScheduleAudit(
    repository: repository,
    datasetId: datasetId,
    plantId: plantId,
    changeId: changeId,
  ),
);

class _ScheduleAudit extends StatefulWidget {
  const _ScheduleAudit({
    required this.repository,
    required this.datasetId,
    required this.plantId,
    required this.changeId,
  });
  final CollectionRepository repository;
  final String datasetId, plantId, changeId;
  @override
  State<_ScheduleAudit> createState() => _ScheduleAuditState();
}

class _ScheduleAuditState extends State<_ScheduleAudit> {
  late Future<ScheduleChange> read = load();
  Future<ScheduleChange> load() async {
    final snapshot = await widget.repository.mediaSnapshot();
    if (snapshot.datasetId != widget.datasetId) {
      throw DomainException('DATASET_CHANGED');
    }
    final change = snapshot.scheduleChanges[widget.changeId];
    if (!snapshot.plants.containsKey(widget.plantId) ||
        change == null ||
        change.plantId != widget.plantId) {
      throw DomainException('NOT_FOUND');
    }
    return change;
  }

  Widget values(String title, RoutineHeadValues v) {
    final s = strings(context);
    String date(LocalDate? d) =>
        d == null ? s.auditNone : dateLabel(context, d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text('${s.auditInterval}: ${careIntervalLabel(s, v.interval)}'),
        Text('${s.auditNext}: ${date(v.nextCheck)}'),
        Text('${s.auditAnchor}: ${date(v.anchor)}'),
        Text(v.firstCheckAnchor ? s.auditFirstAnchor : s.auditCareAnchor),
        Text('${s.auditFirstDate}: ${date(v.firstCheckDate)}'),
        Text('${s.auditOverride}: ${date(v.overrideDate)}'),
        Text(
          '${s.auditStatus}: ${switch (v.status) {
            RoutineStatus.active => s.auditActive,
            RoutineStatus.paused => s.auditPaused,
            RoutineStatus.retired => s.auditRetired,
          }}',
        ),
        Text('${s.auditArchived}: ${v.archived ? s.auditYes : s.auditNo}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    return AppAlertDialog(
      scrollable: true,
      title: Text(s.scheduleChange),
      content: FutureBuilder<ScheduleChange>(
        future: read,
        builder: (context, result) {
          if (result.hasError) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ErrorNotice(
                  result.error is DomainException
                      ? (result.error as DomainException).code
                      : 'STORAGE_UNAVAILABLE',
                ),
                TextButton(
                  onPressed: () => setState(() {
                    read = load();
                  }),
                  child: Text(s.retry),
                ),
              ],
            );
          }
          final c = result.data;
          if (c == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c.careLabel, style: Theme.of(context).textTheme.titleMedium),
              Text(switch (c.kind) {
                ScheduleChangeKind.interval => s.auditIntervalChange,
                ScheduleChangeKind.speciesApply => s.auditSpeciesChange,
                ScheduleChangeKind.override => s.auditOverrideChange,
                ScheduleChangeKind.pause => s.auditPause,
                ScheduleChangeKind.resume => s.auditResume,
                ScheduleChangeKind.retire => s.auditRetire,
                ScheduleChangeKind.archive => s.auditArchive,
                ScheduleChangeKind.restore => s.auditRestore,
                ScheduleChangeKind.undo => s.auditUndo,
              }),
              Text(dateLabel(context, c.changeDate)),
              Text(
                '${s.auditRecorded}: ${c.changedAt.toUtc().toIso8601String()}',
              ),
              values(s.auditBefore, c.before),
              values(s.auditAfter, c.after),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.close),
        ),
      ],
    );
  }
}
