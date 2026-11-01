import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../collection/presentation/widgets/presentation_helpers.dart';
import '../../backup/presentation/backup_page.dart';
import '../../reminders/presentation/reminder_page.dart';
import '../../pro/presentation/pro_page.dart';
import '../data/feedback_service.dart';
import 'cubits/feedback_cubit.dart';

Future<void> openPrivacy(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(MaterialPageRoute(builder: (_) => const PrivacyPage()));
Future<void> openHelp(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(MaterialPageRoute(builder: (_) => const HelpPage()));
Widget section(BuildContext context, String heading, String body) =>
    FigmaFormSection(
      children: [
        Semantics(
          header: true,
          child: Text(heading, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 12),
        Text(body),
      ],
    );

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    return Scaffold(
      appBar: AppPageBar(context: context, title: Text(s.privacyTitle)),
      body: SafeArea(
        child: ListView(
          padding: AppLayout.pagePadding,
          children: [
            AppScrollTitle(title: Text(s.privacyTitle)),
            section(context, s.privacyLocalTitle, s.privacyLocalBody),
            section(context, s.privacyExternalTitle, s.privacyExternalBody),
            section(context, s.privacyBackupTitle, s.privacyBackupBody),
            section(context, s.privacyDeleteTitle, s.privacyDeleteBody),
            section(context, s.privacyReviewTitle, s.privacyReviewBody),
          ],
        ),
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    return Scaffold(
      appBar: AppPageBar(context: context, title: Text(s.helpTitle)),
      body: SafeArea(
        child: ListView(
          padding: AppLayout.pagePadding,
          children: [
            AppScrollTitle(title: Text(s.helpTitle)),
            section(context, s.helpCareTitle, s.helpCareBody),
            section(context, s.helpHistoryTitle, s.helpHistoryBody),
            section(context, s.helpCatalogTitle, s.helpCatalogBody),
            section(context, s.helpReminderTitle, s.helpReminderBody),
            if (ReminderHost.maybeOf(context) != null)
              OutlinedButton(
                onPressed: () => openReminders(context),
                child: Text(s.remindersTitle),
              ),
            section(context, s.helpBackupTitle, s.helpBackupBody),
            if (BackupHost.maybeOf(context) != null)
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BackupPage(),
                      ),
                    ),
                child: Text(s.backupTitle),
              ),
            section(context, s.helpMediaTitle, s.helpMediaBody),
            if (ProHost.maybeOf(context) != null)
              OutlinedButton(
                onPressed: () => openPro(context),
                child: Text(s.proTitle),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(builder: (_) => const FeedbackPage()),
              ),
              icon: const Icon(Icons.edit_note),
              label: Text(s.feedbackTitle),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbackPage extends StatefulWidget {
  final FeedbackService? service;
  const FeedbackPage({super.key, this.service});
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  FeedbackCubit? cubit;
  final subject = TextEditingController(), body = TextEditingController();
  bool allowLeave = false, asking = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (cubit != null) return;
    final s = strings(context);
    cubit = FeedbackCubit(
      widget.service ?? NativeFeedbackService(),
      initialSubject: s.feedbackDefaultSubject,
      initialBody: (metadata) => s.feedbackDefaultBody(
        metadata.appVersion ?? s.feedbackUnavailable,
        metadata.build ?? s.feedbackUnavailable,
        metadata.osVersion ?? s.feedbackUnavailable,
      ),
    );
    cubit!.load();
  }

  @override
  void dispose() {
    cubit?.close();
    subject.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (asking) return;
    asking = true;
    final s = strings(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        scrollable: true,
        title: Text(s.feedbackDiscardTitle),
        content: Text(s.feedbackDiscardBody),
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
      ),
    );
    asking = false;
    if (yes == true && mounted) {
      setState(() => allowLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    return BlocConsumer<FeedbackCubit, FeedbackState>(
      bloc: cubit!,
      listenWhen: (old, next) => !old.ready && next.ready,
      listener: (context, state) {
        subject.text = state.subject;
        body.text = state.body;
      },
      builder: (context, state) => PopScope(
        canPop: allowLeave || !state.dirty,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) leave();
        },
        child: Scaffold(
          appBar: AppPageBar(
            context: context,
            title: Text(s.feedbackTitle),
            leading: Navigator.canPop(context)
                ? BackButton(
                    onPressed: () {
                      if (cubit!.state.dirty) {
                        leave();
                      } else {
                        Navigator.maybePop(context);
                      }
                    },
                  )
                : null,
          ),
          body: SafeArea(
            child: ListView(
              padding: AppLayout.pagePadding,
              children: [
                AppScrollTitle(title: Text(s.feedbackTitle)),
                Text(s.feedbackNoDestination),
                const SizedBox(height: 12),
                Text(s.feedbackPrivacy),
                const SizedBox(height: 16),
                if (state.busy) const LinearProgressIndicator(),
                if (state.status == 'loadFailed') ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(s.feedbackLoadFailed),
                  ),
                  OutlinedButton(
                    onPressed: state.busy ? null : cubit!.load,
                    child: Text(s.retry),
                  ),
                ],
                FigmaFormSection(
                  title: s.feedbackTitle,
                  children: [
                    TextField(
                      controller: subject,
                      enabled: state.ready && !state.busy,
                      decoration: InputDecoration(
                        labelText: s.feedbackSubject,
                        errorText: state.subjectError == null
                            ? null
                            : s.feedbackSubjectError,
                      ),
                      onChanged: (value) => cubit!.edit(subject: value),
                      maxLines: null,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: body,
                      enabled: state.ready && !state.busy,
                      decoration: InputDecoration(
                        labelText: s.feedbackMessage,
                        errorText: state.bodyError == null
                            ? null
                            : s.feedbackBodyError,
                      ),
                      onChanged: (value) => cubit!.edit(body: value),
                      minLines: 6,
                      maxLines: null,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
                if (state.status == 'copied')
                  Semantics(liveRegion: true, child: Text(s.feedbackCopied)),
                if (state.status == 'copyUnknown')
                  Semantics(
                    liveRegion: true,
                    child: Text(s.feedbackCopyUnknown),
                  ),
                FilledButton.icon(
                  onPressed: state.ready && !state.busy ? cubit!.copy : null,
                  icon: const Icon(Icons.copy),
                  label: Text(s.feedbackCopy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
