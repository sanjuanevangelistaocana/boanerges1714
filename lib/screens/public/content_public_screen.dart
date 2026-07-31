import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/content_models.dart';
import 'package:boanerges1714/services/content_service.dart';
import 'package:boanerges1714/widgets/app_surface_card.dart';
import 'package:boanerges1714/widgets/content_block_view.dart';
import 'package:boanerges1714/screens/public/history_screen.dart';
import 'package:boanerges1714/widgets/responsive_layout.dart';

class ContentRootScreen extends StatelessWidget {
  final String rootSlug;
  final ContentService service;

  const ContentRootScreen({
    super.key,
    required this.rootSlug,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContentSection?>(
      future: service.getSectionBySlugPublic(rootSlug),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _PublicError(error: snapshot.error!);
        final root = snapshot.data;
        if (root == null) return const _NotFound();
        return _ContentRootBody(root: root, service: service);
      },
    );
  }
}

class _ContentRootBody extends StatelessWidget {
  final ContentSection root;
  final ContentService service;

  const _ContentRootBody({required this.root, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContentSection>>(
      stream: service.watchChildSections(root.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _PublicError(error: snapshot.error!);
        final children = snapshot.data ?? const <ContentSection>[];
        return _PublicPage(
          title: root.title,
          subtitle: root.shortDescription,
          child: children.isEmpty
              ? const _EmptyState(
                  icon: Icons.account_tree_outlined,
                  text:
                      'Esta sección todavía no tiene subsecciones publicadas.',
                )
              : _SectionGrid(
                  sections: children,
                  rootSlug: root.slug,
                ),
        );
      },
    );
  }
}

class ContentSectionScreen extends StatelessWidget {
  final String rootSlug;
  final String sectionSlug;
  final ContentService service;

  const ContentSectionScreen({
    super.key,
    required this.rootSlug,
    required this.sectionSlug,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContentSection?>(
      future: service.getSectionBySlugPublic(sectionSlug),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _PublicError(error: snapshot.error!);
        final section = snapshot.data;
        if (section == null || section.parentId == null) {
          return const _NotFound();
        }
        return _SectionBody(
          rootSlug: rootSlug,
          section: section,
          service: service,
        );
      },
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String rootSlug;
  final ContentSection section;
  final ContentService service;

  const _SectionBody({
    required this.rootSlug,
    required this.section,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    switch (section.type) {
      case ContentSectionType.articulos:
        return StreamBuilder<List<ContentArticle>>(
          stream: service.watchArticles(section.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _PublicError(error: snapshot.error!);
            }
            final articles = snapshot.data ?? const <ContentArticle>[];
            if (articles.isEmpty && section.slug == 'historia') {
              return const HistoryScreen();
            }
            return _PublicPage(
              title: section.title,
              subtitle: section.shortDescription,
              child: articles.isEmpty
                  ? const _EmptyState(
                      icon: Icons.article_outlined,
                      text: 'Todavía no hay artículos publicados.',
                    )
                  : _ArticleList(
                      rootSlug: rootSlug,
                      section: section,
                      articles: articles,
                    ),
            );
          },
        );
      case ContentSectionType.fichas:
        return StreamBuilder<List<PatrimonioFicha>>(
          stream: service.watchPatrimonio(section.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _PublicError(error: snapshot.error!);
            final fichas = snapshot.data ?? const <PatrimonioFicha>[];
            return _PublicPage(
              title: section.title,
              subtitle: section.shortDescription,
              child: fichas.isEmpty
                  ? const _EmptyState(
                      icon: Icons.museum_outlined,
                      text: 'Todavía no hay fichas publicadas.',
                    )
                  : _FichaGrid(
                      rootSlug: rootSlug,
                      section: section,
                      fichas: fichas,
                    ),
            );
          },
        );
      case ContentSectionType.junta:
        return StreamBuilder<List<JuntaMiembro>>(
          stream: service.watchJunta(section.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _PublicError(error: snapshot.error!);
            final members = snapshot.data ?? const <JuntaMiembro>[];
            return _PublicPage(
              title: section.title,
              subtitle: section.shortDescription,
              child: members.isEmpty
                  ? const _EmptyState(
                      icon: Icons.groups_outlined,
                      text:
                          'La información de la Junta se publicará próximamente.',
                    )
                  : _JuntaGrid(members: members),
            );
          },
        );
      case ContentSectionType.grupos:
        return StreamBuilder<List<ContentGroup>>(
          stream: service.watchGroups(section.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _PublicError(error: snapshot.error!);
            final groups = snapshot.data ?? const <ContentGroup>[];
            return _PublicPage(
              title: section.title,
              subtitle: section.shortDescription,
              child: groups.isEmpty
                  ? const _EmptyState(
                      icon: Icons.account_tree_outlined,
                      text: 'Todavía no hay grupos publicados.',
                    )
                  : _GroupGrid(
                      rootSlug: rootSlug,
                      section: section,
                      groups: groups,
                    ),
            );
          },
        );
    }
  }
}

class ContentArticleScreen extends StatelessWidget {
  final String rootSlug;
  final String sectionSlug;
  final String articleSlug;
  final ContentService service;

  const ContentArticleScreen({
    super.key,
    required this.rootSlug,
    required this.sectionSlug,
    required this.articleSlug,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContentSection?>(
      future: service.getSectionBySlugPublic(sectionSlug),
      builder: (context, sectionSnapshot) {
        if (sectionSnapshot.hasError) {
          return _PublicError(error: sectionSnapshot.error!);
        }
        final section = sectionSnapshot.data;
        if (section == null) return const _NotFound();
        return FutureBuilder<ContentArticle?>(
          future: service.getArticleBySlugPublic(section.id, articleSlug),
          builder: (context, articleSnapshot) {
            if (articleSnapshot.hasError) {
              return _PublicError(error: articleSnapshot.error!);
            }
            final article = articleSnapshot.data;
            if (article == null) return const _NotFound();
            return _ArticleDetail(article: article, section: section);
          },
        );
      },
    );
  }
}

class ContentFichaScreen extends StatelessWidget {
  final String sectionSlug;
  final String fichaSlug;
  final ContentService service;

  const ContentFichaScreen({
    super.key,
    required this.sectionSlug,
    required this.fichaSlug,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContentSection?>(
      future: service.getSectionBySlugPublic(sectionSlug),
      builder: (context, sectionSnapshot) {
        if (sectionSnapshot.hasError) {
          return _PublicError(error: sectionSnapshot.error!);
        }
        final section = sectionSnapshot.data;
        if (section == null) return const _NotFound();
        return FutureBuilder<PatrimonioFicha?>(
          future: service.getPatrimonioBySlugPublic(section.id, fichaSlug),
          builder: (context, fichaSnapshot) {
            if (fichaSnapshot.hasError) {
              return _PublicError(error: fichaSnapshot.error!);
            }
            final ficha = fichaSnapshot.data;
            if (ficha == null) return const _NotFound();
            return _FichaDetail(ficha: ficha, section: section);
          },
        );
      },
    );
  }
}

class ContentGroupScreen extends StatelessWidget {
  final String sectionSlug;
  final String groupSlug;
  final ContentService service;

  const ContentGroupScreen({
    super.key,
    required this.sectionSlug,
    required this.groupSlug,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContentSection?>(
      future: service.getSectionBySlugPublic(sectionSlug),
      builder: (context, sectionSnapshot) {
        if (sectionSnapshot.hasError) {
          return _PublicError(error: sectionSnapshot.error!);
        }
        final section = sectionSnapshot.data;
        if (section == null) return const _NotFound();
        return FutureBuilder<ContentGroup?>(
          future: service.getGroupBySlugPublic(section.id, groupSlug),
          builder: (context, groupSnapshot) {
            if (groupSnapshot.hasError) {
              return _PublicError(error: groupSnapshot.error!);
            }
            final group = groupSnapshot.data;
            if (group == null) return const _NotFound();
            return _GroupDetail(group: group, section: section);
          },
        );
      },
    );
  }
}

class _SectionGrid extends StatelessWidget {
  final List<ContentSection> sections;
  final String rootSlug;

  const _SectionGrid({required this.sections, required this.rootSlug});

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      smallColumns: 1,
      mediumColumns: 2,
      largeColumns: 3,
      wideColumns: 3,
      children: [
        for (final section in sections)
          AppSurfaceCard(
            onTap: () => context.go('/$rootSlug/${section.slug}'),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_sectionIcon(section.type),
                    color: AppTheme.primaryColor, size: 34),
                const SizedBox(height: 24),
                Text(section.title,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(section.shortDescription),
              ],
            ),
          ),
      ],
    );
  }
}

class _ArticleList extends StatelessWidget {
  final String rootSlug;
  final ContentSection section;
  final List<ContentArticle> articles;

  const _ArticleList({
    required this.rootSlug,
    required this.section,
    required this.articles,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: articles
          .map((article) => AppSurfaceCard(
                onTap: () => context
                    .go('/$rootSlug/${section.slug}/articulo/${article.slug}'),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.article_outlined,
                        color: AppTheme.primaryColor, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(article.title,
                              style: Theme.of(context).textTheme.titleLarge),
                          if (article.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(article.subtitle),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _ArticleDetail extends StatelessWidget {
  final ContentArticle article;
  final ContentSection section;

  const _ArticleDetail({required this.article, required this.section});

  @override
  Widget build(BuildContext context) {
    return _PublicPage(
      title: article.title,
      subtitle: article.subtitle.isEmpty ? section.title : article.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.content.isNotEmpty)
            ...article.content.map((block) => ContentBlockView(block: block)),
          if (article.content.isEmpty && article.plainContent.isNotEmpty)
            Text(article.plainContent,
                style: const TextStyle(fontSize: 15, height: 1.7)),
          if (article.chronology.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Cronología',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _Timeline(entries: article.chronology),
          ],
          if (article.photos.isNotEmpty) ...[
            const SizedBox(height: 20),
            _PhotoGrid(photos: article.photos),
          ],
          if (article.documents.isNotEmpty) ...[
            const SizedBox(height: 20),
            _DocumentList(documents: article.documents),
          ],
        ],
      ),
    );
  }
}

class _FichaGrid extends StatelessWidget {
  final String rootSlug;
  final ContentSection section;
  final List<PatrimonioFicha> fichas;

  const _FichaGrid({
    required this.rootSlug,
    required this.section,
    required this.fichas,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      smallColumns: 1,
      mediumColumns: 2,
      largeColumns: 3,
      wideColumns: 3,
      children: [
        for (final ficha in fichas) _buildFichaCard(context, ficha),
      ],
    );
  }

  Widget _buildFichaCard(BuildContext context, PatrimonioFicha ficha) {
    final image = ficha.photos.isEmpty ? null : ficha.photos.first['url'];
    return AppSurfaceCard(
      onTap: () =>
          context.go('/patrimonio/${section.slug}/ficha/${ficha.slug}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: CachedNetworkImage(
                imageUrl: image,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ficha.name, style: Theme.of(context).textTheme.titleLarge),
                if (ficha.period.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(ficha.period),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FichaDetail extends StatelessWidget {
  final PatrimonioFicha ficha;
  final ContentSection section;

  const _FichaDetail({required this.ficha, required this.section});

  @override
  Widget build(BuildContext context) {
    return _PublicPage(
      title: ficha.name,
      subtitle: section.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FactsCard(ficha: ficha),
          const SizedBox(height: 20),
          ...ficha.description.map((block) => ContentBlockView(block: block)),
          if (ficha.restorations.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Restauraciones',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            ...ficha.restorations.map((entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.build_outlined,
                      color: AppTheme.primaryColor),
                  title: Text('${entry['date'] ?? ''}'),
                  subtitle: Text(
                      '${entry['description'] ?? ''}${entry['author_or_workshop'] == null ? '' : '\n${entry['author_or_workshop']}'}'),
                )),
          ],
          if (ficha.photos.isNotEmpty) ...[
            const SizedBox(height: 20),
            _PhotoGrid(photos: ficha.photos),
          ],
          if (ficha.documents.isNotEmpty) ...[
            const SizedBox(height: 20),
            _DocumentList(documents: ficha.documents),
          ],
        ],
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  final PatrimonioFicha ficha;

  const _FactsCard({required this.ficha});

  @override
  Widget build(BuildContext context) {
    final facts = [
      ('Autor', ficha.author),
      ('Fecha o época', ficha.period),
      ('Materiales', ficha.materials),
      ('Medidas', ficha.measurements),
    ].where((fact) => fact.$2.isNotEmpty).toList();
    if (facts.isEmpty) return const SizedBox.shrink();
    return AppSurfaceCard(
      child: Column(
        children: facts
            .map((fact) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(fact.$1,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(fact.$2),
                ))
            .toList(),
      ),
    );
  }
}

class _JuntaGrid extends StatelessWidget {
  final List<JuntaMiembro> members;

  const _JuntaGrid({required this.members});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<JuntaMiembro>>{};
    for (final member in members) {
      groups.putIfAbsent(member.group ?? 'Junta', () => []).add(member);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries
          .map((group) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.key,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: group.value
                        .map((member) => SizedBox(
                              width: 250,
                              child: AppSurfaceCard(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 44,
                                      backgroundImage: member.photoUrl == null
                                          ? null
                                          : CachedNetworkImageProvider(
                                              member.photoUrl!),
                                      child: member.photoUrl == null
                                          ? const Icon(Icons.person, size: 42)
                                          : null,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(member.position,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(member.name,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    if (member.description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(member.description,
                                          textAlign: TextAlign.center),
                                    ],
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ))
          .toList(),
    );
  }
}

class _GroupGrid extends StatelessWidget {
  final String rootSlug;
  final ContentSection section;
  final List<ContentGroup> groups;

  const _GroupGrid({
    required this.rootSlug,
    required this.section,
    required this.groups,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: groups
          .map((group) => AppSurfaceCard(
                onTap: () => context
                    .go('/$rootSlug/${section.slug}/grupo/${group.slug}'),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.groups_outlined,
                      color: AppTheme.primaryColor, size: 32),
                  title: Text(group.name),
                  subtitle: Text(group.shortDescription),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ))
          .toList(),
    );
  }
}

class _GroupDetail extends StatelessWidget {
  final ContentGroup group;
  final ContentSection section;

  const _GroupDetail({required this.group, required this.section});

  @override
  Widget build(BuildContext context) {
    return _PublicPage(
      title: group.name,
      subtitle: group.shortDescription.isEmpty
          ? section.title
          : group.shortDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.responsible != null && group.responsible!.isNotEmpty)
            Text('Responsable: ${group.responsible}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...group.content.map((block) => ContentBlockView(block: block)),
          if (group.photos.isNotEmpty) _PhotoGrid(photos: group.photos),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<Map<String, String>> photos;

  const _PhotoGrid({required this.photos});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: photos
          .where((photo) => photo['url']?.isNotEmpty == true)
          .map((photo) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: photo['url']!,
                  width: 220,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ))
          .toList(),
    );
  }
}

class _DocumentList extends StatelessWidget {
  final List<Map<String, String>> documents;

  const _DocumentList({required this.documents});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Documentación', style: Theme.of(context).textTheme.headlineSmall),
        ...documents.map((document) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf,
                  color: AppTheme.primaryColor),
              title: Text(document['name'] ?? 'Documento PDF'),
              subtitle:
                  Text('${document['size'] ?? document['tamano_bytes'] ?? ''}'),
              onTap: () async {
                final url = document['url'];
                if (url != null) await launchUrl(Uri.parse(url));
              },
            )),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<Map<String, dynamic>> entries;

  const _Timeline({required this.entries});

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) =>
        ((a['order'] as num?)?.toInt() ?? 0)
            .compareTo((b['order'] as num?)?.toInt() ?? 0));
    return Column(
      children: sorted
          .map((entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle,
                    size: 14, color: AppTheme.primaryColor),
                title: Text(
                    '${entry['date_or_year'] ?? entry['date'] ?? ''} · ${entry['title'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${entry['text'] ?? ''}'),
              ))
          .toList(),
    );
  }
}

class _PublicPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _PublicPage({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ResponsiveContentBox(
          maxWidth: 1100,
          padding: EdgeInsets.fromLTRB(
            context.responsive.horizontalPadding,
            32,
            context.responsive.horizontalPadding,
            48,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
              ],
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(icon, size: 42, color: AppTheme.primaryColor),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.search_off,
      text: 'No se ha encontrado la sección solicitada.',
    );
  }
}

class _PublicError extends StatelessWidget {
  final Object error;

  const _PublicError({required this.error});

  @override
  Widget build(BuildContext context) {
    final failure = error;
    final code = failure is FirebaseException ? failure.code : 'content-error';
    debugPrint('Public content error [$code]: $failure');
    return _EmptyState(
      icon: Icons.error_outline,
      text: 'No se pudo cargar este contenido [$code].',
    );
  }
}

IconData _sectionIcon(ContentSectionType type) {
  switch (type) {
    case ContentSectionType.articulos:
      return Icons.article_outlined;
    case ContentSectionType.fichas:
      return Icons.museum_outlined;
    case ContentSectionType.junta:
      return Icons.groups_outlined;
    case ContentSectionType.grupos:
      return Icons.account_tree_outlined;
  }
}
