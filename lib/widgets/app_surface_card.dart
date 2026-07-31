import 'package:flutter/material.dart';
import 'package:boanerges1714/config/theme.dart';

class AppSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool admin;

  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.onTap,
    this.admin = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);
    final decoration = BoxDecoration(
      gradient: color == null
          ? (admin ? AppTheme.adminCardGradient : AppTheme.publicCardGradient)
          : null,
      color: color,
      borderRadius: borderRadius,
      border: Border.all(
        color: admin
            ? AppTheme.adminBorderColor
            : AppTheme.primaryColor.withAlpha(18),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
    final content = Padding(padding: padding, child: child);
    if (onTap == null) {
      return DecoratedBox(
        decoration: decoration,
        child: content,
      );
    }
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: content,
          ),
        ),
      ),
    );
  }
}
