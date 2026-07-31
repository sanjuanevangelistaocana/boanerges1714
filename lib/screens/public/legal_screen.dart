import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/content_models.dart';
import 'package:boanerges1714/services/content_service.dart';
import 'package:boanerges1714/widgets/content_block_view.dart';

class LegalScreen extends StatelessWidget {
  final String pageId;
  final String title;
  final String summary;

  const LegalScreen({
    super.key,
    required this.pageId,
    required this.title,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LegalPage>>(
      stream: context.read<ContentService>().watchLegalPages(),
      builder: (context, snapshot) {
        final matches = (snapshot.data ?? const <LegalPage>[])
            .where((item) => item.id == pageId)
            .toList();
        final page = matches.isEmpty ? null : matches.first;
        if (page == null || page.content.isEmpty) {
          return _placeholder(context);
        }
        return _publishedPage(context, page);
      },
    );
  }

  Widget _publishedPage(BuildContext context, LegalPage page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(page.title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 20),
                  ...page.content
                      .map((block) => ContentBlockView(block: block)),
                  const Divider(),
                  const SizedBox(height: 20),
                  Text(
                    'Última actualización: ${page.updatedContentAt?.year ?? page.updatedAt.year}',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Text(
                    'Página pendiente de revisión legal.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Text(summary, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),
                  Text(
                    'La Junta deberá completar esta página con la identidad del responsable, '
                    'los datos legales aplicables, finalidades, bases jurídicas, plazos '
                    'y demás información que corresponda antes de su publicación definitiva.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
