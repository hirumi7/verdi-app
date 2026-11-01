import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../widgets/presentation_helpers.dart';
import '../../../help/presentation/help_pages.dart';
import 'custom_care_page.dart';
import '../../../pro/presentation/pro_page.dart';
import '../../../backup/presentation/backup_page.dart';
import '../../../reminders/presentation/reminder_page.dart';

@RoutePage()
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    Widget row(
      String icon,
      String label,
      VoidCallback onTap, {
      bool prominent = false,
    }) => ListTile(
      leading: FigmaIconTile(icon, prominent: prominent),
      title: Text(label),
      trailing: const FigmaIcon('chevron', size: 14),
      onTap: onTap,
    );
    return Scaffold(
      body: ListView(
        padding: AppLayout.pagePadding,
        children: [
          AppPageHeader(title: s.settings),
          if (ProHost.maybeOf(context) != null)
            FigmaSection(
              child: FigmaGroup(
                children: [
                  row(
                    'pro',
                    s.proTitle,
                    () => openPro(context),
                    prominent: true,
                  ),
                  row('restore', s.restorePurchases, () => openPro(context)),
                ],
              ),
            ),
          FigmaSection(
            title: s.careAndReminders,
            child: FigmaGroup(
              children: [
                row('care-types', s.careTypes, () => openCareTypes(context)),
                if (ReminderHost.maybeOf(context) != null)
                  row(
                    'reminders',
                    s.remindersTitle,
                    () => openReminders(context),
                  ),
              ],
            ),
          ),
          FigmaSection(
            title: s.yourData,
            child: FigmaGroup(
              children: [
                if (BackupHost.maybeOf(context) != null)
                  row(
                    'backup',
                    s.backupTitle,
                    () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BackupPage(),
                      ),
                    ),
                  ),
                row('privacy', s.privacyTitle, () => openPrivacy(context)),
              ],
            ),
          ),
          FigmaSection(
            title: s.supportSection,
            child: FigmaGroup(
              children: [
                row('help', s.helpTitle, () => openHelp(context)),
                row(
                  'licenses',
                  s.licensesTitle,
                  () => showLicensePage(
                    context: context,
                    applicationName: s.appTitle,
                  ),
                ),
                row(
                  'plants',
                  s.artworkCredits,
                  () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: AppPageBar(
                          context: context,
                          title: Text(s.artworkCredits),
                        ),
                        body: ListView(
                          padding: AppLayout.pagePadding,
                          children: [
                            AppScrollTitle(title: Text(s.artworkCredits)),
                            Text(s.artworkAttribution),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          FigmaSection(
            title: s.aboutPreview,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                s.developmentDetails,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
