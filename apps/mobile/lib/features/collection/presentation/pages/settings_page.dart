import '../../../help/presentation/help_pages.dart';
import 'custom_care_page.dart';
import '../../../pro/presentation/pro_page.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../widgets/presentation_helpers.dart';
import '../../../backup/presentation/backup_page.dart';
import '../../../reminders/presentation/reminder_page.dart';

@RoutePage()
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    return Scaffold(
      body: ListView(
        padding: AppLayout.pagePadding,
        children: [
          AppPageHeader(title: s.settings),
          if (ProHost.maybeOf(context) != null)
            _SettingsCard(
              child: ListTile(
                leading: const Icon(Icons.local_florist_outlined),
                title: Text(s.proTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openPro(context),
              ),
            ),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.checklist),
              title: Text(s.careTypes),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openCareTypes(context),
            ),
          ),
          if (ReminderHost.maybeOf(context) != null)
            _SettingsCard(
              child: ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: Text(s.remindersTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openReminders(context),
              ),
            ),
          if (BackupHost.maybeOf(context) != null)
            _SettingsCard(
              child: ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text(s.backupTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(builder: (_) => const BackupPage()),
                ),
              ),
            ),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(s.privacyTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openPrivacy(context),
            ),
          ),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(s.helpTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openHelp(context),
            ),
          ),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(s.licensesTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: s.appTitle,
              ),
            ),
          ),
          _SettingsCard(
            child: Padding(
              padding: AppLayout.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.aboutPreview,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(s.developmentDetails),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppLayout.cardGap),
    child: Card(child: child),
  );
}
