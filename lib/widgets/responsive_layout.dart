import 'package:flutter/material.dart';
import 'package:boanerges1714/config/responsive.dart';

class ResponsivePage extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final bool scrollable;

  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = ResponsiveContentBox(
      maxWidth: maxWidth,
      child: child,
    );
    return SafeArea(
      child: scrollable ? SingleChildScrollView(child: content) : content,
    );
  }
}

class ResponsiveContentBox extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContentBox({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final width = maxWidth ?? responsive.contentMaxWidth;
    return Padding(
      padding: padding ??
          EdgeInsets.symmetric(horizontal: responsive.horizontalPadding),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: responsive.isMobile ? double.infinity : width,
          ),
          child: child,
        ),
      ),
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? smallColumns;
  final int? mediumColumns;
  final int? largeColumns;
  final int? wideColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.smallColumns,
    this.mediumColumns,
    this.largeColumns,
    this.wideColumns,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final columns = Responsive.gridColumns(
          availableWidth,
          small: smallColumns ?? 1,
          medium: mediumColumns ?? 2,
          large: largeColumns ?? 3,
          wide: wideColumns ?? 4,
        );
        final itemWidth = (availableWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class ResponsiveFormRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const ResponsiveFormRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (context.responsive.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _withVerticalSpacing(children, runSpacing),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _withHorizontalSpacing(
        children.map((child) => Expanded(child: child)).toList(),
        spacing,
      ),
    );
  }
}

List<Widget> _withHorizontalSpacing(List<Widget> children, double spacing) {
  final result = <Widget>[];
  for (var index = 0; index < children.length; index++) {
    if (index > 0) result.add(SizedBox(width: spacing));
    result.add(children[index]);
  }
  return result;
}

List<Widget> _withVerticalSpacing(List<Widget> children, double spacing) {
  final result = <Widget>[];
  for (var index = 0; index < children.length; index++) {
    if (index > 0) result.add(SizedBox(height: spacing));
    result.add(children[index]);
  }
  return result;
}
