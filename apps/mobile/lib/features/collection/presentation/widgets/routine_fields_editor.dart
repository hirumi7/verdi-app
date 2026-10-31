import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_core/verdi_core.dart';

import '../cubits/workspace_cubit.dart';
import 'presentation_helpers.dart';

class RoutineFieldsEditor extends StatelessWidget {
  final List<RoutineInput> routines;
  final List<CatalogSuggestion> suggestions;
  final Map<String, String> errors;
  final ValueChanged<List<RoutineInput>> onChanged;
  final Map<String, GlobalKey> fieldKeys;
  final Map<String, FocusNode> fieldFocus;
  const RoutineFieldsEditor({
    super.key,
    required this.routines,
    this.suggestions = const [],
    required this.errors,
    required this.onChanged,
    required this.fieldKeys,
    required this.fieldFocus,
  });

  void replace(StandardCareKind kind, RoutineInput? value) {
    onChanged([
      for (final current in StandardCareKind.values)
        if (current == kind && value != null)
          value
        else if (current != kind)
          ...routines.where((r) => r.kind == current),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    return Column(
      children: [
        for (final kind in StandardCareKind.values)
          Builder(
            builder: (context) {
              final proposal = suggestions
                  .where((s) => s.careKind == kind)
                  .firstOrNull;
              final index = routines.indexWhere((r) => r.kind == kind);
              final raw = index < 0 ? null : routines[index];
              void update({
                String? count,
                IntervalUnit? unit,
                SeedKind? seed,
                String? date,
                bool resetDate = false,
              }) {
                replace(
                  kind,
                  RoutineInput(
                    kind: kind,
                    count: count ?? raw!.count,
                    unit: unit ?? raw!.unit,
                    seedKind: seed ?? raw!.seedKind,
                    date: resetDate ? '' : date ?? raw!.date,
                  ),
                );
              }

              return Column(
                key: ValueKey(kind),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      kind == StandardCareKind.water
                          ? s.waterRoutine
                          : s.routineNamed(kindLabel(s, kind)),
                    ),
                    value: raw != null,
                    onChanged: (enabled) => replace(
                      kind,
                      enabled
                          ? RoutineInput(
                              kind: kind,
                              count: proposal?.interval.count.toString() ?? '',
                              unit: proposal?.interval.unit ?? IntervalUnit.day,
                              seedKind: null,
                              date: '',
                            )
                          : null,
                    ),
                  ),
                  if (proposal != null) ...[
                    Text(s.suggestionOnly),
                    Text(proposal.context),
                    Text(proposal.sourceLabel),
                  ],
                  if (raw != null) ...[
                    TextFormField(
                      key: fieldKeys['${kind.name}-count'],
                      focusNode: fieldFocus['${kind.name}-count'],
                      initialValue: raw.count,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: s.interval,
                        errorText:
                            errors.containsKey('routineInputs[$index].count')
                            ? s.positiveInterval
                            : null,
                      ),
                      onChanged: (value) => update(count: value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<IntervalUnit>(
                      initialValue: raw.unit,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: s.intervalUnit),
                      items: [
                        for (final unit in IntervalUnit.values)
                          DropdownMenuItem(
                            value: unit,
                            child: Text(unitLabel(s, unit)),
                          ),
                      ],
                      onChanged: (value) => update(unit: value),
                    ),
                    Focus(
                      key: fieldKeys['${kind.name}-seed'],
                      focusNode: fieldFocus['${kind.name}-seed'],
                      child: RadioGroup<SeedKind>(
                        groupValue: raw.seedKind,
                        onChanged: (value) =>
                            update(seed: value, resetDate: true),
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
                    ),
                    if (errors.containsKey('routineInputs[$index].seed'))
                      Text(
                        s.chooseCareBranch,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    OutlinedButton.icon(
                      key: fieldKeys['${kind.name}-date'],
                      focusNode: fieldFocus['${kind.name}-date'],
                      onPressed: raw.seedKind == null
                          ? null
                          : () async {
                              LocalDate? initial;
                              try {
                                initial = LocalDate.parse(raw.date);
                              } on DomainException {
                                /* Preserve invalid raw draft until selection. */
                              }
                              final date = await chooseDate(
                                context,
                                initial: initial,
                                latest: raw.seedKind == SeedKind.known
                                    ? context.read<WorkspaceCubit>().today
                                    : null,
                                helpText: raw.seedKind == SeedKind.known
                                    ? s.actualCareDate
                                    : s.firstCheck,
                              );
                              if (date != null) update(date: date.toString());
                            },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(raw.date.isEmpty ? s.chooseDate : raw.date),
                    ),
                    if (errors.containsKey('routineInputs[$index].date'))
                      Text(
                        errorLabel(s, errors['routineInputs[$index].date']!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (raw.seedKind != null)
                      Text(
                        raw.seedKind == SeedKind.known
                            ? s.lastCare
                            : s.firstCheck,
                      ),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}
