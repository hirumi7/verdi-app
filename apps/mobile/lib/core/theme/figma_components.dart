import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:verdi_core/verdi_core.dart';

import '../di/injection.dart';
import '../../features/collection/data/repositories/collection_repository.dart';
import '../../features/media/presentation/widgets/photo_preview.dart';
import 'app_layout.dart';

/// Original exported line icons; their enclosing control owns semantics/hit area.
class FigmaIcon extends StatelessWidget {
  const FigmaIcon(this.name, {super.key, this.size = 24, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(
      'assets/figma_icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ??
            IconTheme.of(context).color ??
            Theme.of(context).colorScheme.primary,
        BlendMode.srcIn,
      ),
    ),
  );
}

class FigmaIconTile extends StatelessWidget {
  const FigmaIconTile(this.name, {super.key, this.prominent = false});
  final String name;
  final bool prominent;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: prominent ? colors.primary : colors.primaryContainer,
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: FigmaIcon(
        name,
        size: 18,
        color: prominent ? colors.onPrimary : colors.primary,
      ),
    );
  }
}

class FigmaGroup extends StatelessWidget {
  const FigmaGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: .5,
                indent: 57,
                color: Theme.of(context).dividerColor,
              ),
            children[i],
          ],
        ],
      ),
    ),
  );
}

class FigmaSection extends StatelessWidget {
  const FigmaSection({super.key, this.title, required this.child, this.footer});
  final String? title, footer;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        child,
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
            child: Text(footer!, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    ),
  );
}

/// Catalog identities resolve only through the validated catalog manifest.
class CatalogArtwork extends StatefulWidget {
  const CatalogArtwork({
    super.key,
    this.speciesId,
    this.catalogState,
    this.fit = BoxFit.contain,
  });
  final CatalogState? catalogState;
  final String? speciesId;
  final BoxFit fit;
  @override
  State<CatalogArtwork> createState() => _CatalogArtworkState();
}

// Only in-flight reads are shared: later refreshes never reuse an old package.
final _artworkReads = Expando<Future<CatalogState>>();

Future<CatalogState> _readArtworkCatalog(CollectionRepository repository) {
  final pending = _artworkReads[repository];
  if (pending != null) return pending;
  final future = repository.catalog();
  _artworkReads[repository] = future;
  future.then(
    (_) {
      if (identical(_artworkReads[repository], future)) {
        _artworkReads[repository] = null;
      }
    },
    onError: (Object _, StackTrace _) {
      if (identical(_artworkReads[repository], future)) {
        _artworkReads[repository] = null;
      }
    },
  );
  return future;
}

class _CatalogArtworkState extends State<CatalogArtwork> {
  Future<CatalogState>? catalog;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    catalog = widget.speciesId == null || widget.catalogState != null
        ? null
        : _readArtworkCatalog(getIt<CollectionRepository>());
  }

  @override
  void didUpdateWidget(CatalogArtwork old) {
    super.didUpdateWidget(old);
    load();
  }

  Widget fallback() => widget.speciesId == null
      ? const Center(child: FigmaIcon('plants', size: 48))
      : Image.asset(
          'assets/illustrations/empty-plants.png',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const Center(child: FigmaIcon('plants', size: 48)),
        );
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FutureBuilder<CatalogState>(
      future: catalog,
      builder: (context, snapshot) {
        final state = widget.catalogState ?? snapshot.data;
        final manifest = state?.manifest;
        String? resource;
        if (state?.available == true &&
            state?.entry(widget.speciesId ?? '') != null) {
          for (final item in (manifest?['speciesArt'] as List? ?? const [])) {
            final mapping = item as Map;
            if (mapping['catalogId'] != widget.speciesId) continue;
            for (final item in (manifest?['assets'] as List? ?? const [])) {
              final asset = item as Map;
              if (asset['id'] == mapping['assetId']) {
                resource = asset['resourceName'] as String?;
              }
            }
          }
        }
        if (resource == null ||
            !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(resource)) {
          return fallback();
        }
        return Image.asset(
          'assets/catalog_art/$resource.png',
          fit: widget.fit,
          errorBuilder: (_, e, s) => fallback(),
        );
      },
    ),
  );
}

class PlantVisual extends StatelessWidget {
  const PlantVisual({
    super.key,
    this.speciesId,
    this.photoId,
    this.photoRevision = 1,
    this.height = 216,
    this.radius = 14,
  });
  final String? speciesId, photoId;
  final int photoRevision;
  final double height, radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Container(
      height: height,
      color: Theme.of(context).colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: photoId != null
          ? PhotoPreview(
              photoId: photoId!,
              revision: photoRevision,
              height: height,
            )
          : CatalogArtwork(speciesId: speciesId),
    ),
  );
}

/// Calendar context only: no invented history dots or implied day-filter action.
class FigmaWeek extends StatelessWidget {
  const FigmaWeek({super.key, required this.today});
  final LocalDate today;
  @override
  Widget build(BuildContext context) {
    final date = DateTime.utc(today.year, today.month, today.day);
    final start = date.subtract(Duration(days: date.weekday - 1));
    final colors = Theme.of(context).colorScheme;
    final width = AppLayout.largeText(context) ? 72.0 : 48.0;
    final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
    final items = [
      for (final day in days)
        Semantics(
          label: DateFormat.yMMMMEEEEd().format(day),
          selected: day == date,
          excludeSemantics: true,
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                Text(
                  DateFormat.E().format(day).substring(0, 1),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: day == date ? colors.onSurface : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: day == date ? colors.surface : colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: AppLayout.largeText(context)
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: items),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final item in items) Expanded(child: item)],
            ),
    );
  }
}

class FigmaSegments extends StatelessWidget {
  const FigmaSegments({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      for (var i = 0; i < labels.length; i++)
        Semantics(
          selected: i == selected,
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 44),
              foregroundColor: theme.colorScheme.onSurface,
              backgroundColor: i == selected
                  ? theme.colorScheme.surface
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            onPressed: () => onSelected(i),
            child: Text(labels[i], textAlign: TextAlign.center),
          ),
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppLayout.largeText(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items,
            )
          : Row(children: [for (final item in items) Expanded(child: item)]),
    );
  }
}
