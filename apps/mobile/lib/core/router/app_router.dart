import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart' show Key;

import '../../features/collection/presentation/pages/root_shell_page.dart';
import '../../features/collection/presentation/pages/today_page.dart';
import '../../features/collection/presentation/pages/plants_page.dart';
import '../../features/collection/presentation/pages/plant_detail_page.dart';
import '../../features/collection/presentation/pages/plant_editor_page.dart';
import '../../features/collection/presentation/pages/settings_page.dart';
part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      page: RootShellRoute.page,
      initial: true,
      children: [
        AutoRoute(
          page: TodayTabRoute.page,
          initial: true,
          children: [
            AutoRoute(page: TodayRoute.page, initial: true),
            AutoRoute(page: PlantDetailRoute.page),
            AutoRoute(page: PlantEditorRoute.page),
          ],
        ),
        AutoRoute(
          page: PlantsTabRoute.page,
          children: [
            AutoRoute(page: PlantsRoute.page, initial: true),
            AutoRoute(page: PlantDetailRoute.page),
            AutoRoute(page: PlantEditorRoute.page),
          ],
        ),
        AutoRoute(page: SettingsRoute.page),
      ],
    ),
  ];
}
