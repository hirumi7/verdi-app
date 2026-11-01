import 'package:auto_route/auto_route.dart';

import 'dart:async';

import '../features/reminders/data/reminder_service.dart';
import '../features/reminders/presentation/reminder_cubit.dart';
import '../features/reminders/presentation/reminder_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/collection/presentation/cubits/workspace_cubit.dart';
import '../l10n/app_localizations.dart';

class VerdiApp extends StatefulWidget {
  final WorkspaceCubit? workspace;
  final ReminderService? reminderService;
  final String Function()? reminderNewId;
  final Locale? locale;
  final ThemeMode themeMode;
  final bool restored, localeFallback;
  const VerdiApp({
    super.key,
    this.workspace,
    this.reminderService,
    this.reminderNewId,
    this.locale,
    this.themeMode = ThemeMode.system,
    this.restored = false,
    this.localeFallback = false,
  });
  @override
  State<VerdiApp> createState() => _VerdiAppState();
}

class _VerdiAppState extends State<VerdiApp> with WidgetsBindingObserver {
  final _router = AppRouter();
  bool _noticeDismissed = false;
  late final WorkspaceCubit _workspace;
  ReminderCubit? _reminders;
  StreamSubscription<ReminderState>? _reminderSubscription;
  StreamSubscription<WorkspaceState>? _workspaceSubscription;
  bool _routingReminder = false;
  String? _reminderNotice;
  Future<void> _routeReminder(ReminderState state) async {
    final tap = state.tap;
    if (tap == null || _routingReminder || !mounted) return;
    _routingReminder = true;
    try {
      // The native inbox can arrive before nested routes mount on cold launch.
      for (var attempt = 0; attempt < 4; attempt++) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        if (![
          RootShellRoute.name,
          TodayTabRoute.name,
          PlantsTabRoute.name,
        ].contains(_router.topRoute.name)) {
          break;
        }
      }
      final top = _router.topMostRouter();
      final todayStack = _router
          .innerRouterOf<TabsRouter>(RootShellRoute.name)
          ?.innerRouterOf<StackRouter>(TodayTabRoute.name);
      final retainedTodayRoute =
          todayStack != null &&
          (todayStack.hasPagelessTopRoute ||
              todayStack.stack.any(
                (page) => page.routeData.name != TodayRoute.name,
              ));
      if (_workspace.state.busy ||
          retainedTodayRoute ||
          ![
            TodayRoute.name,
            PlantsRoute.name,
            SettingsRoute.name,
          ].contains(_router.topRoute.name) ||
          (top is StackRouter && top.hasPagelessTopRoute)) {
        setState(() => _reminderNotice = 'waiting');
        return;
      }
      _router
          .navigate(
            const RootShellRoute(
              children: [
                TodayTabRoute(children: [TodayRoute()]),
              ],
            ),
          )
          .ignore();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _router.topRoute.name != TodayRoute.name) {
        return;
      }
      if (mounted) {
        setState(
          () => _reminderNotice = tap['current'] == true ? 'current' : 'stale',
        );
      }
      await _reminders!.acknowledgeTap(tap['eventId']! as String);
    } catch (_) {
      /* Keep the durable navigation item for a later foreground. */
    } finally {
      _routingReminder = false;
      final next = _reminders?.state.tap;
      if (mounted && next != null && next['eventId'] != tap['eventId']) {
        unawaited(_routeReminder(_reminders!.state));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _workspace = widget.workspace ?? getIt<WorkspaceCubit>();
    WidgetsBinding.instance.addObserver(this);
    _workspaceSubscription = _workspace.stream.listen((state) {
      if (!state.busy && _reminders?.state.tap != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _routeReminder(_reminders!.state);
        });
      }
    });
    _workspace.refresh();
    final service = widget.reminderService;
    if (service != null) {
      _reminders = ReminderCubit(service, widget.reminderNewId!);
      _reminderSubscription = _reminders!.stream.listen((state) {
        if (state.saved) _workspace.refresh();
        _routeReminder(state);
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reminders?.refresh(reconcile: true),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _workspace.invalidateUndo();
    } else {
      _workspace.refresh();
      _reminders?.refresh(reconcile: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderSubscription?.cancel();
    _workspaceSubscription?.cancel();
    _reminders?.close();
    _router.dispose();
    if (widget.workspace == null) _workspace.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = BlocProvider.value(
      value: _workspace,
      child: MaterialApp.router(
        title: 'Verdi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        themeMode: widget.themeMode,
        locale: widget.locale,
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('en', 'GB'),
          Locale('en'),
        ],
        localizationsDelegates: AppStrings.localizationsDelegates,
        routerConfig: _router.config(),
        builder: (context, child) => Column(
          children: [
            if (_reminderNotice != null)
              ReminderNotice(
                state: _reminderNotice!,
                open: () => _routeReminder(_reminders!.state),
                dismiss: () => setState(() => _reminderNotice = null),
              ),
            if (!_noticeDismissed && (widget.restored || widget.localeFallback))
              Material(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.localeFallback
                                ? AppStrings.of(context).backupLocaleFallback
                                : AppStrings.of(context).backupRestored,
                          ),
                        ),
                        Semantics(
                          label: AppStrings.of(context).close,
                          child: IconButton(
                            onPressed: () =>
                                setState(() => _noticeDismissed = true),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        ),
      ),
    );
    return _reminders == null
        ? app
        : ReminderHost(cubit: _reminders!, child: app);
  }
}
