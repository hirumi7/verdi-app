import 'package:flutter/material.dart';

/// Shared metrics for page, card and action roles. Native chrome owns safe areas.
abstract final class AppLayout {
  static const gutter = 16.0;
  static const related = 8.0;
  static const cardGap = 12.0;
  static const section = 24.0;
  static const pagePadding = EdgeInsets.fromLTRB(gutter, 16, gutter, 24);
  static const formPadding = EdgeInsets.fromLTRB(gutter, 8, gutter, 24);
  static const cardPadding = EdgeInsets.all(16);
  static const actionPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 14,
  );
  static bool largeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(22) > 33;
}

/// Tab headings share their baseline and reflow instead of clipping the action.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.bottomGap = AppLayout.section,
    this.titleStyle,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  final double bottomGap;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subtitle != null) ...[
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 1),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            style: titleStyle ?? Theme.of(context).textTheme.headlineLarge,
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (action == null) return heading;
          if (constraints.maxWidth < 360 || AppLayout.largeText(context)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 12), action!],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 16),
              action!,
            ],
          );
        },
      ),
    );
  }
}

/// At accessibility sizes the matching AppScrollTitle owns the full heading.
/// Back/close/actions stay reachable without consuming the viewport with a title.
class AppPageBar extends AppBar {
  AppPageBar({
    super.key,
    required BuildContext context,
    required Widget title,
    super.leading,
    super.actions,
    super.automaticallyImplyLeading,
  }) : super(
         title: AppLayout.largeText(context) ? null : title,
         toolbarHeight: AppLayout.largeText(context)
             ? kToolbarHeight
             : kToolbarHeight *
                   (MediaQuery.textScalerOf(context).scale(22) / 22).clamp(
                     1.0,
                     1.5,
                   ),
       );
}

class AppScrollTitle extends StatelessWidget {
  const AppScrollTitle({super.key, required this.title});
  final Widget title;
  @override
  Widget build(BuildContext context) => !AppLayout.largeText(context)
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: AppLayout.section),
          child: Semantics(
            header: true,
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.titleLarge!,
              child: title,
            ),
          ),
        );
}

/// One stable scrollable hierarchy keeps message, inputs and actions reachable
/// as keyboard insets and text scaling change, without remounting form fields.
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.scrollable = true,
  });
  final Widget? title, content;
  final List<Widget>? actions;
  final bool scrollable;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: scrollable,
    title: title,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?content,
        if (actions != null) ...[
          const SizedBox(height: 24),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            children: actions!,
          ),
        ],
      ],
    ),
  );
}
