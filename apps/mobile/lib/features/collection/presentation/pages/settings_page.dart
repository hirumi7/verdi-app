import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../widgets/presentation_helpers.dart';
import '../../../backup/presentation/backup_page.dart';

@RoutePage()
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.settings, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 24),
          if (BackupHost.maybeOf(context) != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text(s.backupTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(builder: (_) => const BackupPage()),
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
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
