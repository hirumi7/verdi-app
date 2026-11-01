import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../collection/presentation/widgets/presentation_helpers.dart';
import 'reminder_cubit.dart';

class ReminderHost extends InheritedWidget {
  final ReminderCubit cubit;
  const ReminderHost({super.key, required this.cubit, required super.child});
  static ReminderCubit? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReminderHost>()?.cubit;
  @override
  bool updateShouldNotify(ReminderHost oldWidget) => cubit != oldWidget.cubit;
}

void openReminders(BuildContext context) {
  final cubit = ReminderHost.maybeOf(context)!;
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => ReminderHost(cubit: cubit, child: const ReminderPage()),
    ),
  );
}

class ReminderPage extends StatelessWidget {
  const ReminderPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cubit = ReminderHost.maybeOf(context)!;
    return BlocBuilder<ReminderCubit, ReminderState>(
      bloc: cubit,
      builder: (context, state) {
        final s = strings(context), locked = state.busy || state.unresolved;
        String time(String key) {
          final n = (state.draft[key] as int?) ?? 0;
          return TimeOfDay(hour: n ~/ 60, minute: n % 60).format(context);
        }

        Widget clock(String key, String label) => ListTile(
          title: Text(label),
          subtitle: AppLayout.largeText(context) ? Text(time(key)) : null,
          trailing: AppLayout.largeText(context)
              ? const Icon(Icons.schedule)
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(time(key)),
                  ),
                ),
          onTap: locked
              ? null
              : () async {
                  final n = (state.draft[key] as int?) ?? 0;
                  final value = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: n ~/ 60, minute: n % 60),
                  );
                  if (value != null) {
                    cubit.edit(key, value.hour * 60 + value.minute);
                  }
                },
        );
        return Scaffold(
          appBar: AppPageBar(context: context, title: Text(s.remindersTitle)),
          body: ListView(
            padding: AppLayout.pagePadding,
            children: [
              AppScrollTitle(title: Text(s.remindersTitle)),
              FigmaSection(
                footer: s.remindersBestEffort,
                child: FigmaGroup(
                  children: [
                    SwitchListTile(
                      title: Text(s.remindersEnable),
                      value: state.draft['enabled'] == true,
                      onChanged: locked || state.data == null
                          ? null
                          : (v) => cubit.edit('enabled', v),
                    ),
                    clock('preferredMinute', s.remindersPreferredTime),
                  ],
                ),
              ),
              FigmaSection(
                footer: s.remindersQuietExplanation,
                child: FigmaGroup(
                  children: [
                    clock('quietStartMinute', s.remindersQuietStart),
                    clock('quietEndMinute', s.remindersQuietEnd),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: state.busy || state.data == null ? null : cubit.save,
                child: Text(
                  state.unresolved ? s.remindersRetrySave : s.remindersSave,
                ),
              ),
              if (!state.unresolved && state.error != null)
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => cubit.refresh(reload: true),
                  child: Text(s.remindersReload),
                ),
              const SizedBox(height: 24),
              FigmaFormSection(
                children: [
                  Text(
                    s.remindersPermission(
                      permissionLabel(context, state.permission),
                    ),
                  ),
                  if (state.busy) const LinearProgressIndicator(),
                  if (state.error != null) ...[
                    ErrorNotice(state.error!),
                    Text(
                      state.unresolved
                          ? s.remindersUnknownSave
                          : s.remindersUnavailable,
                    ),
                  ],
                  if (state.saved)
                    Semantics(liveRegion: true, child: Text(s.remindersSaved)),
                  if (state.permission == 'notDetermined')
                    FilledButton(
                      onPressed: locked || !state.hasSchedule
                          ? null
                          : cubit.permission,
                      child: Text(s.remindersAllow),
                    ),
                  if (!state.hasSchedule) Text(s.remindersNeedsSchedule),
                  if (state.permission != 'notDetermined')
                    OutlinedButton(
                      onPressed: locked ? null : cubit.openSettings,
                      child: Text(s.remindersSystemSettings),
                    ),
                ],
              ),
              FigmaFormSection(
                children: [
                  Text(
                    projectionLabel(context, state),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    s.remindersQueueCounts(
                      (state.projection['pendingConfirmed'] as int?) ?? 0,
                      (state.projection['omittedCapacity'] as int?) ?? 0,
                      (state.projection['pastCount'] as int?) ?? 0,
                    ),
                  ),
                  Text(s.remindersTodayAuthority),
                  OutlinedButton(
                    onPressed: locked ? null : cubit.retryQueue,
                    child: Text(s.remindersRetryQueue),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

String permissionLabel(BuildContext context, String permission) {
  final s = strings(context);
  return switch (permission) {
    'notDetermined' => s.remindersNotAsked,
    'denied' => s.remindersDenied,
    'authorized' => s.remindersAuthorized,
    'provisional' => s.remindersQuietPermission,
    _ => s.remindersUnavailable,
  };
}

String projectionLabel(BuildContext context, ReminderState state) {
  final s = strings(context);
  return switch (state.projection['state']) {
    'complete' => s.remindersQueueReady,
    'disabled' => s.remindersOff,
    'denied' => s.remindersDenied,
    'partial' => s.remindersPartial,
    _ => s.remindersDeferred,
  };
}

class ReminderTodayCard extends StatelessWidget {
  const ReminderTodayCard({super.key});
  @override
  Widget build(BuildContext context) {
    final cubit = ReminderHost.maybeOf(context);
    if (cubit == null) return const SizedBox.shrink();
    return BlocBuilder<ReminderCubit, ReminderState>(
      bloc: cubit,
      builder: (context, state) {
        final s = strings(context);
        if (!state.hasSchedule && state.error == null) {
          return const SizedBox.shrink();
        }
        if (state.error == null &&
            state.projection['state'] == 'complete' &&
            const [
              'authorized',
              'provisional',
              'ephemeral',
            ].contains(state.permission)) {
          return const SizedBox.shrink();
        }
        return Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(s.remindersTitle),
            subtitle: Text(
              state.permission == 'notDetermined'
                  ? s.remindersContextOffer
                  : projectionLabel(context, state),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openReminders(context),
          ),
        );
      },
    );
  }
}

class ReminderNotice extends StatelessWidget {
  final String state;
  final VoidCallback open, dismiss;
  const ReminderNotice({
    super.key,
    required this.state,
    required this.open,
    required this.dismiss,
  });
  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    return Material(
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .35,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state == 'waiting'
                        ? s.remindersWaitingTap
                        : state == 'current'
                        ? s.remindersCurrentTap
                        : s.remindersStaleTap,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (state == 'waiting')
                        TextButton(
                          onPressed: open,
                          child: Text(s.remindersOpenToday),
                        ),
                      TextButton(onPressed: dismiss, child: Text(s.close)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
