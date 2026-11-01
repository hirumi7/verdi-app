import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../core/router/app_router.dart';
import '../widgets/presentation_helpers.dart';

@RoutePage()
class TodayTabPage extends AutoRouter {
  const TodayTabPage({super.key});
}

@RoutePage()
class PlantsTabPage extends AutoRouter {
  const PlantsTabPage({super.key});
}

@RoutePage()
class RootShellPage extends StatelessWidget {
  const RootShellPage({super.key});
  @override
  Widget build(BuildContext context) => AutoTabsRouter(
    routes: const [TodayTabRoute(), PlantsTabRoute(), SettingsRoute()],
    builder: (context, child) {
      final s = strings(context);
      final tabs = AutoTabsRouter.of(context);
      return Scaffold(
        // Nested page scaffolds own keyboard avoidance. Resizing both layers
        // can leave no room for the preview banner at large text sizes.
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: child),
              Semantics(
                liveRegion: false,
                label: s.developmentNotice,
                excludeSemantics: true,
                child: Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 3,
                  ),
                  child: Text(
                    s.developmentShortNotice,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: 44 + MediaQuery.textScalerOf(context).scale(12),
          selectedIndex: tabs.activeIndex,
          onDestinationSelected: tabs.setActiveIndex,
          destinations: [
            NavigationDestination(
              icon: const FigmaIcon('today', size: 25),
              label: s.today,
            ),
            NavigationDestination(
              icon: const FigmaIcon('plants', size: 25),
              label: s.plants,
            ),
            NavigationDestination(
              icon: const FigmaIcon('settings', size: 25),
              label: s.settings,
            ),
          ],
        ),
      );
    },
  );
}
