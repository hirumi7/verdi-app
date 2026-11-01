import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../collection/presentation/widgets/presentation_helpers.dart';
import '../data/store_service.dart';
import 'pro_cubit.dart';
import '../../../l10n/app_localizations.dart';

class ProHost extends InheritedWidget {
  final StoreService service;
  final String datasetId;
  final String Function() newId;
  const ProHost({
    super.key,
    required this.service,
    required this.datasetId,
    required this.newId,
    required super.child,
  });
  static ProHost? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProHost>();
  @override
  bool updateShouldNotify(ProHost oldWidget) =>
      oldWidget.service != service || oldWidget.datasetId != datasetId;
}

Future<bool> openPro(BuildContext context, {FrozenCommand? command}) async {
  final host = ProHost.maybeOf(context);
  if (host == null) return false;
  return await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(
          builder: (_) => ProPage(
            service: host.service,
            request: {
              'intentId': host.newId(),
              'datasetId': host.datasetId,
              'commandId': command?.commandId,
              'payloadHash': command?.payloadHash,
            },
          ),
        ),
      ) ??
      false;
}

class ProPage extends StatefulWidget {
  final StoreService service;
  final Map<String, Object?> request;
  const ProPage({super.key, required this.service, required this.request});
  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> with WidgetsBindingObserver {
  late final cubit = ProCubit(widget.service);
  bool leaving = false;
  bool attemptedPurchase = false;
  String? submittedIntentId;
  bool confirmingPending = false;
  BuildContext? pendingDialogContext;
  bool get gated => widget.request['commandId'] != null;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cubit.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) cubit.read(refresh: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cubit.close();
    super.dispose();
  }

  Future<void> leave(bool success) async {
    if (leaving) return;
    leaving = true;
    if (!success) {
      final prior = cubit.state.attempt;
      final id =
          submittedIntentId ??
          (prior != null &&
                  prior['commandId'] == widget.request['commandId'] &&
                  prior['datasetId'] == widget.request['datasetId']
              ? prior['intentId'] as String
              : widget.request['intentId']! as String);
      try {
        await cubit.abandon(id);
      } catch (_) {
        // Leaving the view cannot cancel the payment. No callback saves content;
        // restart recovery still requires an explicit current command review.
      }
    }
    if (mounted) Navigator.of(context).pop(success);
  }

  Map<String, Object?> purchaseRequest() {
    final prior = cubit.state.attempt;
    if (prior != null &&
        const ['prepared', 'recoveryRequired'].contains(prior['phase'])) {
      return {
        'intentId': prior['intentId'],
        'datasetId': prior['datasetId'],
        'commandId': prior['commandId'],
        'payloadHash': prior['payloadHash'],
      };
    }
    return widget.request;
  }

  Future<void> retryPending() async {
    if (confirmingPending || cubit.state.working) return;
    confirmingPending = true;
    try {
      await cubit.read(refresh: true);
      if (!mounted ||
          cubit.state.pro ||
          !cubit.state.pendingApproval ||
          cubit.state.access['busy'] == true ||
          cubit.state.status == 'recoveryUnavailable') {
        return;
      }
      final intent = cubit.state.attempt!['intentId'];
      final s = strings(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          pendingDialogContext = context;
          return AlertDialog(
            title: Text(s.proRetryPending),
            content: Text(s.proRetryPendingBody),
            actions: [
              TextButton(
                onPressed: () {
                  pendingDialogContext = null;
                  Navigator.pop(context, false);
                },
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () {
                  pendingDialogContext = null;
                  Navigator.pop(context, true);
                },
                child: Text(s.proRetryPending),
              ),
            ],
          );
        },
      );
      if (confirmed == true && mounted && !cubit.state.pro) {
        attemptedPurchase = true;
        submittedIntentId = intent as String;
        await cubit.perform('retryPending', {'intentId': intent});
      }
    } finally {
      confirmingPending = false;
      pendingDialogContext = null;
      if (mounted && gated && cubit.state.pro && !cubit.state.working) {
        await leave(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    return BlocConsumer<ProCubit, ProState>(
      bloc: cubit,
      listener: (_, state) {
        if (gated && state.pro && !state.working) {
          if (confirmingPending) {
            final dialog = pendingDialogContext;
            pendingDialogContext = null;
            if (dialog != null &&
                dialog.mounted &&
                ModalRoute.of(dialog)?.isCurrent == true) {
              Navigator.of(dialog).pop(false);
            }
          } else {
            leave(true);
          }
        }
        if (attemptedPurchase &&
            state.status == 'cancelled' &&
            !state.working) {
          leave(false);
        }
      },
      builder: (context, state) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) leave(false);
        },
        child: Scaffold(
          appBar: AppPageBar(
            context: context,
            title: Text(s.proTitle),
            leading: IconButton(
              onPressed: () => leave(false),
              icon: const Icon(Icons.close),
              tooltip: s.close,
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: AppLayout.pagePadding,
              children: [
                AppScrollTitle(title: Text(s.proTitle)),
                Icon(
                  Icons.local_florist_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  state.pro ? s.proActive : s.proRoom,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
                Text(s.proBenefit),
                const SizedBox(height: 12),
                Text(s.proFree),
                const SizedBox(height: 20),
                if (state.access['testEnvironment'] == true)
                  Text(s.proTestNotice),
                if (state.access['freshness'] == 'cached' && state.pro)
                  Text(s.proCached),
                if (state.loading || state.working)
                  const LinearProgressIndicator(),
                const SizedBox(height: 16),
                if (!state.pro)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.proOneTime,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.offer?['displayPrice'] as String? ??
                                s.proUnavailable,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed:
                                state.offer == null ||
                                    state.working ||
                                    state.outstanding ||
                                    state.status == 'recoveryUnavailable'
                                ? null
                                : () {
                                    attemptedPurchase = true;
                                    final request = purchaseRequest();
                                    submittedIntentId =
                                        request['intentId']! as String;
                                    cubit.perform('purchase', request);
                                  },
                            child: Text(s.proBuy),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Semantics(liveRegion: true, child: Text(_status(s, state))),
                const SizedBox(height: 16),
                if (!state.pro && state.pendingApproval)
                  OutlinedButton(
                    onPressed:
                        state.working ||
                            state.access['busy'] == true ||
                            state.status == 'recoveryUnavailable'
                        ? null
                        : retryPending,
                    child: Text(s.proRetryPending),
                  ),
                OutlinedButton(
                  onPressed: state.working || state.access['busy'] == true
                      ? null
                      : () => cubit.perform('restore'),
                  child: Text(s.restorePurchases),
                ),
                TextButton(
                  onPressed: state.working
                      ? null
                      : () async {
                          await cubit.read(refresh: true);
                          await cubit.load();
                        },
                  child: Text(s.retry),
                ),
                TextButton(
                  onPressed: () => leave(state.pro),
                  child: Text(state.pro ? s.proContinue : s.proContinueFree),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _status(AppStrings s, ProState state) {
    if (state.error != null || state.status == 'recoveryUnavailable') {
      return s.proRecovery;
    }
    if (state.pendingApproval) return s.proPending;
    if (state.working || state.access['busy'] == true) return s.proWorking;
    return switch (state.status) {
      'cancelled' => s.proCancelled,
      'failed' || 'unverified' => s.proFailed,
      'noneFound' => s.proNoneFound,
      'revoked' => s.proRevoked,
      _ => state.phase == 'recoveryRequired' ? s.proRecovery : '',
    };
  }
}
