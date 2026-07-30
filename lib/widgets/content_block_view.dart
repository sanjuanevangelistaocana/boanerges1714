import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/content_block.dart';

class ContentBlockView extends StatelessWidget {
  final ContentBlock block;

  const ContentBlockView({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case 'heading':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Text(
            block.text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: block.level == 1
                  ? 24
                  : block.level == 2
                      ? 20
                      : 17,
              height: 1.3,
            ),
          ),
        );
      case 'list':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: block.items
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Expanded(
                              child: Text(item,
                                  style: const TextStyle(
                                      fontSize: 15, height: 1.5))),
                        ],
                      ),
                    ))
                .toList(),
          ),
        );
      case 'quote':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: const Border(
                  left: BorderSide(color: AppTheme.primaryColor, width: 4)),
              color: Colors.grey.shade50,
            ),
            child: Text(block.text,
                style: const TextStyle(
                    fontStyle: FontStyle.italic, fontSize: 15, height: 1.6)),
          ),
        );
      case 'image':
        if ((block.imageUrl ?? '').isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: block.imageUrl!,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        );
      case 'divider':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(),
        );
      case 'highlight':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                  left: BorderSide(color: AppTheme.primaryColor, width: 4)),
            ),
            child: Text(block.text,
                style: const TextStyle(fontSize: 15, height: 1.6)),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(block.text,
              style: const TextStyle(fontSize: 15, height: 1.7)),
        );
    }
  }
}
