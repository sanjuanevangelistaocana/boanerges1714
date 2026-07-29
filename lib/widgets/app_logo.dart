import 'package:flutter/material.dart';
import 'package:boanerges1714/config/theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool compact;
  final Color? fallbackColor;

  const AppLogo({
    super.key,
    this.size = 48,
    this.compact = false,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final dimension = compact ? size * .78 : size;
    return Semantics(
      image: true,
      label: 'Logotipo de la Cofradía de San Juan Evangelista',
      child: Image.asset(
        'assets/images/logo.png',
        width: dimension,
        height: dimension,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.church,
          size: dimension,
          color: fallbackColor ?? AppTheme.primaryColor,
        ),
      ),
    );
  }
}
