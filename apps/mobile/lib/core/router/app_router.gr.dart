// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [PlantDetailPage]
class PlantDetailRoute extends PageRouteInfo<PlantDetailRouteArgs> {
  PlantDetailRoute({
    Key? key,
    required String plantId,
    List<PageRouteInfo>? children,
  }) : super(
         PlantDetailRoute.name,
         args: PlantDetailRouteArgs(key: key, plantId: plantId),
         initialChildren: children,
       );

  static const String name = 'PlantDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PlantDetailRouteArgs>();
      return PlantDetailPage(key: args.key, plantId: args.plantId);
    },
  );
}

class PlantDetailRouteArgs {
  const PlantDetailRouteArgs({this.key, required this.plantId});

  final Key? key;

  final String plantId;

  @override
  String toString() {
    return 'PlantDetailRouteArgs{key: $key, plantId: $plantId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PlantDetailRouteArgs) return false;
    return key == other.key && plantId == other.plantId;
  }

  @override
  int get hashCode => key.hashCode ^ plantId.hashCode;
}

/// generated route for
/// [PlantEditorPage]
class PlantEditorRoute extends PageRouteInfo<PlantEditorRouteArgs> {
  PlantEditorRoute({Key? key, String? plantId, List<PageRouteInfo>? children})
    : super(
        PlantEditorRoute.name,
        args: PlantEditorRouteArgs(key: key, plantId: plantId),
        initialChildren: children,
      );

  static const String name = 'PlantEditorRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PlantEditorRouteArgs>(
        orElse: () => const PlantEditorRouteArgs(),
      );
      return PlantEditorPage(key: args.key, plantId: args.plantId);
    },
  );
}

class PlantEditorRouteArgs {
  const PlantEditorRouteArgs({this.key, this.plantId});

  final Key? key;

  final String? plantId;

  @override
  String toString() {
    return 'PlantEditorRouteArgs{key: $key, plantId: $plantId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PlantEditorRouteArgs) return false;
    return key == other.key && plantId == other.plantId;
  }

  @override
  int get hashCode => key.hashCode ^ plantId.hashCode;
}

/// generated route for
/// [PlantsPage]
class PlantsRoute extends PageRouteInfo<void> {
  const PlantsRoute({List<PageRouteInfo>? children})
    : super(PlantsRoute.name, initialChildren: children);

  static const String name = 'PlantsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PlantsPage();
    },
  );
}

/// generated route for
/// [PlantsTabPage]
class PlantsTabRoute extends PageRouteInfo<void> {
  const PlantsTabRoute({List<PageRouteInfo>? children})
    : super(PlantsTabRoute.name, initialChildren: children);

  static const String name = 'PlantsTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PlantsTabPage();
    },
  );
}

/// generated route for
/// [RootShellPage]
class RootShellRoute extends PageRouteInfo<void> {
  const RootShellRoute({List<PageRouteInfo>? children})
    : super(RootShellRoute.name, initialChildren: children);

  static const String name = 'RootShellRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const RootShellPage();
    },
  );
}

/// generated route for
/// [SettingsPage]
class SettingsRoute extends PageRouteInfo<void> {
  const SettingsRoute({List<PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SettingsPage();
    },
  );
}

/// generated route for
/// [TodayPage]
class TodayRoute extends PageRouteInfo<void> {
  const TodayRoute({List<PageRouteInfo>? children})
    : super(TodayRoute.name, initialChildren: children);

  static const String name = 'TodayRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TodayPage();
    },
  );
}

/// generated route for
/// [TodayTabPage]
class TodayTabRoute extends PageRouteInfo<void> {
  const TodayTabRoute({List<PageRouteInfo>? children})
    : super(TodayTabRoute.name, initialChildren: children);

  static const String name = 'TodayTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TodayTabPage();
    },
  );
}
