import 'package:flutter/material.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/widgets/app_surface_card.dart';

class AztecofradeSupport extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const AztecofradeSupport({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: AppSurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            color: AppTheme.primaryDark,
            child: Row(
              children: [
                const Icon(Icons.handshake_outlined,
                    color: Colors.white70, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Con el apoyo de Aztecofrade',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(
                  'Colaboración',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
