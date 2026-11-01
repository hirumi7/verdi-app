import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../../core/di/injection.dart';
import '../../data/repositories/collection_repository.dart';
import '../cubits/workspace_cubit.dart';
import '../widgets/presentation_helpers.dart';

Future<void> openCareTypes(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<WorkspaceCubit>(),
          child: const CareTypesPage(),
        ),
      ),
    );
Future<void> openAddCare(BuildContext context, String plantId) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<WorkspaceCubit>(),
          child: AddCarePage(plantId: plantId),
        ),
      ),
    );

Future<bool> discardCareForm(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) {
        final s = strings(context);
        return AlertDialog(
          title: Text(s.careFormDiscard),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.discard),
            ),
          ],
        );
      },
    ) ??
    false;

Future<CommandSuccess?> prepareAndReviewCare(
  BuildContext context,
  CoreCommand command, {
  required String title,
  String? explanation,
}) async {
  try {
    final preview = await context.read<WorkspaceCubit>().prepare(command);
    if (!context.mounted) return null;
    return await reviewCommand(
      context,
      preview,
      title: title,
      explanation: explanation,
    );
  } on UnknownCommandOutcome catch (error) {
    if (!context.mounted) return null;
    return showDialog<CommandSuccess>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<WorkspaceCubit>(),
        child: _CarePreparationRecovery(
          command: command,
          id: error.commandId,
          title: title,
          explanation: explanation,
        ),
      ),
    );
  }
}

class _CarePreparationRecovery extends StatefulWidget {
  final CoreCommand command;
  final String id, title;
  final String? explanation;
  const _CarePreparationRecovery({
    required this.command,
    required this.id,
    required this.title,
    this.explanation,
  });
  @override
  State<_CarePreparationRecovery> createState() =>
      _CarePreparationRecoveryState();
}

class _CarePreparationRecoveryState extends State<_CarePreparationRecovery> {
  bool busy = false;
  String? error;
  Future<void> recover(bool cancel) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = getIt<CollectionRepository>();
      final resolution = cancel
          ? await repo.abandon(widget.id)
          : await repo.resolve(widget.id);
      if (!mounted) return;
      if (cancel || resolution.committed) {
        Navigator.pop(context, resolution.result);
        return;
      }
      final preview = await context.read<WorkspaceCubit>().prepare(
        widget.command,
        commandId: widget.id,
      );
      if (!mounted) return;
      final result = await reviewCommand(
        context,
        preview,
        title: widget.title,
        explanation: widget.explanation,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() => error = WorkspaceCubit.code(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.title),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.unknownSave),
            if (error != null) ErrorNotice(error!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => recover(true),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: busy ? null : () => recover(false),
            child: Text(s.retry),
          ),
        ],
      ),
    );
  }
}

class CareTypesPage extends StatefulWidget {
  const CareTypesPage({super.key});
  @override
  State<CareTypesPage> createState() => _CareTypesPageState();
}

class _CareTypesPageState extends State<CareTypesPage> {
  List<CustomCareType> types = [];
  String? error;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final snapshot = await getIt<CollectionRepository>().mediaSnapshot();
      final next = snapshot.customCareTypes.values.toList()
        ..sort((a, b) {
          final order = a.label.compareTo(b.label);
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
      if (mounted) {
        setState(() {
          types = next;
          busy = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = WorkspaceCubit.code(e);
          busy = false;
        });
      }
    }
  }

  Future<void> edit([CustomCareType? type]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<WorkspaceCubit>(),
          child: _CareTypeForm(type: type),
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> retire(CustomCareType type) async {
    setState(() => busy = true);
    try {
      await prepareAndReviewCare(
        context,
        RetireCustomCareType(type.id, type.revision),
        title: '${strings(context).retireCareType}: ${type.label}',
        explanation: strings(context).retireCareTypeBody,
      );
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = WorkspaceCubit.code(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.careTypes)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (busy && types.isEmpty) const LinearProgressIndicator(),
          if (error != null) ErrorNotice(error!),
          for (final kind in standardCareKinds)
            ListTile(title: Text(kindLabel(s, kind))),
          const Divider(),
          for (final type in types)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (type.retired) Text(s.retiredCareType),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: busy ? null : () => edit(type),
                          child: Text(s.renameCareType),
                        ),
                        if (!type.retired)
                          TextButton(
                            onPressed: busy ? null : () => retire(type),
                            child: Text(s.retireCareType),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: busy ? null : () => edit(),
            icon: const Icon(Icons.add),
            label: Text(s.addCustomCare),
          ),
        ],
      ),
    );
  }
}

class _CareTypeForm extends StatefulWidget {
  final CustomCareType? type;
  const _CareTypeForm({this.type});
  @override
  State<_CareTypeForm> createState() => _CareTypeFormState();
}

class _CareTypeFormState extends State<_CareTypeForm> {
  late final input = TextEditingController(text: widget.type?.label ?? '');
  bool busy = false, leaving = false, invalid = false;
  String? error;
  bool get dirty => input.text != (widget.type?.label ?? '');
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> close() async {
    if (busy) return;
    if (!dirty || await discardCareForm(context)) {
      if (mounted) {
        setState(() => leaving = true);
        Navigator.pop(context);
      }
    }
  }

  Future<void> save() async {
    final label = input.text.trim();
    if (label.isEmpty ||
        label.characters.length > 24 ||
        label.contains('\u0000')) {
      setState(() => invalid = true);
      return;
    }
    setState(() {
      busy = true;
      error = null;
      invalid = false;
    });
    try {
      final type = widget.type;
      final result = await prepareAndReviewCare(
        context,
        type == null
            ? CreateCustomCareType(label)
            : RenameCustomCareType(type.id, type.revision, label),
        title: type == null
            ? strings(context).addCustomCare
            : strings(context).renameCareType,
        explanation: type == null ? null : strings(context).renameCareTypeBody,
      );
      if (result != null && mounted) {
        setState(() => leaving = true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = WorkspaceCubit.code(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    return PopScope(
      canPop: leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.type == null ? s.addCustomCare : s.renameCareType),
          leading: IconButton(
            onPressed: busy ? null : close,
            tooltip: s.cancel,
            icon: const Icon(Icons.close),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: input,
              enabled: !busy,
              autofocus: true,
              decoration: InputDecoration(
                labelText: s.careTypeLabel,
                errorText: invalid ? s.careTypeLabelInvalid : null,
              ),
            ),
            if (error != null) ErrorNotice(error!),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(s.continueLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class AddCarePage extends StatefulWidget {
  final String plantId;
  const AddCarePage({super.key, required this.plantId});
  @override
  State<AddCarePage> createState() => _AddCarePageState();
}

class _AddCarePageState extends State<AddCarePage> {
  CollectionSnapshot? snapshot;
  final count = TextEditingController();
  String? choice, error;
  IntervalUnit unit = IntervalUnit.day;
  SeedKind? seed;
  LocalDate? date;
  bool busy = true, leaving = false, invalid = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    count.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final next = await getIt<CollectionRepository>().mediaSnapshot();
      if (mounted) setState(() => snapshot = next);
    } catch (e) {
      if (mounted) setState(() => error = WorkspaceCubit.code(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> close() async {
    if (busy) return;
    if ((choice == null &&
            count.text.isEmpty &&
            seed == null &&
            unit == IntervalUnit.day) ||
        await discardCareForm(context)) {
      if (mounted) {
        setState(() => leaving = true);
        Navigator.pop(context);
      }
    }
  }

  Future<void> save() async {
    final n = RegExp(r'^[0-9]+$').hasMatch(count.text)
        ? int.tryParse(count.text)
        : null;
    if (choice == null ||
        n == null ||
        n < 1 ||
        n > 9999 ||
        seed == null ||
        date == null) {
      setState(() => invalid = true);
      return;
    }
    setState(() {
      busy = true;
      error = null;
      invalid = false;
    });
    try {
      final state = snapshot!, plant = state.plants[widget.plantId]!;
      final custom = state.customCareTypes[choice];
      final kind = custom == null
          ? standardCareKinds.singleWhere((k) => k.name == choice)
          : StandardCareKind.custom;
      final selection =
          custom == null && plant.catalogSelection?.suggestion(kind) != null
          ? plant.catalogSelection
          : null;
      final command = CreateRoutine(
        plantId: plant.id,
        plantRevision: plant.revision,
        careKind: kind,
        customTypeId: custom?.id,
        customTypeRevision: custom?.revision,
        interval: CareInterval(n, unit),
        seedKind: seed!,
        seedDate: date!,
        catalogSelection: selection,
      );
      final result = await prepareAndReviewCare(
        context,
        command,
        title: strings(context).addCare,
      );
      if (result != null && mounted) {
        setState(() => leaving = true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = WorkspaceCubit.code(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(context), state = snapshot;
    final choices = <String, String>{
      if (state != null) ...{
        for (final kind in standardCareKinds)
          if (!state.routines.values.any(
            (r) =>
                r.plantId == widget.plantId &&
                r.status != RoutineStatus.retired &&
                state.careKinds[r.id] == kind,
          ))
            kind.name: kindLabel(s, kind),
        for (final type in state.customCareTypes.values.where(
          (t) => !t.retired,
        ))
          type.id: type.label,
      },
    };
    return PopScope(
      canPop: leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.addCare),
          leading: IconButton(
            onPressed: busy ? null : close,
            tooltip: s.cancel,
            icon: const Icon(Icons.close),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy && state == null) const LinearProgressIndicator(),
            if (error != null) ErrorNotice(error!),
            if (state != null) ...[
              if (choices.isEmpty) Text(s.noCareChoices),
              DropdownButtonFormField<String>(
                initialValue: choice,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.careType),
                items: [
                  for (final entry in choices.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() => choice = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: count,
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: s.interval),
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
                onChanged: busy
                    ? null
                    : (value) => setState(() => unit = value!),
              ),
              RadioGroup<SeedKind>(
                groupValue: seed,
                onChanged: (value) {
                  if (!busy) {
                    setState(() {
                      seed = value;
                      date = null;
                    });
                  }
                },
                child: Column(
                  children: [
                    RadioListTile(
                      value: SeedKind.known,
                      title: Text(s.knownCare),
                    ),
                    RadioListTile(
                      value: SeedKind.unknown,
                      title: Text(s.unknownCare),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy || seed == null
                    ? null
                    : () async {
                        final result = await chooseDate(
                          context,
                          initial: date,
                          latest: seed == SeedKind.known
                              ? context.read<WorkspaceCubit>().today
                              : null,
                          helpText: seed == SeedKind.known
                              ? s.actualCareDate
                              : s.firstCheck,
                        );
                        if (result != null && mounted) {
                          setState(() => date = result);
                        }
                      },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  date == null ? s.chooseDate : dateLabel(context, date!),
                ),
              ),
              if (seed != null)
                Text(seed == SeedKind.known ? s.lastCare : s.firstCheck),
              if (invalid)
                Text(
                  s.fieldInvalid,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy || choices.isEmpty ? null : save,
                child: Text(s.continueLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
