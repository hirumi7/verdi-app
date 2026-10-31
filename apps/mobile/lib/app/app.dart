import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/collection/presentation/cubits/workspace_cubit.dart';
import '../l10n/app_localizations.dart';

class VerdiApp extends StatefulWidget {
  final WorkspaceCubit? workspace;
  final Locale? locale;
  final ThemeMode themeMode;
  final bool restored, localeFallback;
  const VerdiApp({
    super.key,
    this.workspace,
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
  @override
  void initState() {
    super.initState();
    _workspace = widget.workspace ?? getIt<WorkspaceCubit>();
    WidgetsBinding.instance.addObserver(this);
    _workspace.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _workspace.invalidateUndo();
    } else {
      _workspace.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    if (widget.workspace == null) _workspace.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
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
}
