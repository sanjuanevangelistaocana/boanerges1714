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
    final card = DecoratedBox(
      decoration: BoxDecoration(
        gradient: color == null
            ? (admin ? AppTheme.adminCardGradient : AppTheme.publicCardGradient)
            : null,
        color: color,
        borderRadius: BorderRadius.circular(14),
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
      ),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null
        ? card
        : Semantics(
            button: true,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: card,
              ),
            ),
          );
  }
}
