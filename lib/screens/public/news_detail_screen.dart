import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/content_block.dart';
import 'package:boanerges1714/models/noticia.dart';
import 'package:boanerges1714/services/noticias_service.dart';
import 'package:boanerges1714/services/auth_service.dart';

// =============================================================================
// NEWS DETAIL SCREEN
// =============================================================================

class NewsDetailScreen extends StatefulWidget {
  final String? slug;
  final String? id;
  const NewsDetailScreen({super.key, this.slug, this.id});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  Noticia? _noticia;
  bool _loading = true;
  bool _readConfirmed = false;

  @override
  void initState() {
    super.initState();
    _loadNoticia();
  }

  Future<void> _loadNoticia() async {
    final service = context.read<NoticiasService>();
    Noticia? n;
    if (widget.slug != null && widget.slug!.isNotEmpty) {
      n = await service.getNoticiaBySlug(widget.slug!);
    }
    if (n == null && widget.id != null && widget.id!.isNotEmpty) {
      n = await service.getNoticia(widget.id!);
    }
    if (n != null) {
      service.incrementViews(n.id);
      // Check read confirmation status
      final auth = context.read<AuthService>();
      if (auth.cofrade != null && n.requireReadConfirmation) {
        _readConfirmed = await service.hasConfirmedRead(n.id, auth.cofrade!.id);
      }
    }
    if (mounted)
      setState(() {
        _noticia = n;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_noticia == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Noticia no encontrada'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go('/noticias'),
              child: const Text('Volver a noticias'),
            ),
          ],
        ),
      );
    }

    final n = _noticia!;
    final auth = context.watch<AuthService>();
    final cofrade = auth.cofrade;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ---- Cover image ----
          if ((n.coverImageUrl ?? '').isNotEmpty)
            CachedNetworkImage(
              imageUrl: n.coverImageUrl!,
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 300,
                color: Colors.grey.shade200,
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 200,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryDark, AppTheme.primaryColor],
                ),
              ),
              child: Center(
                child: Icon(Icons.article,
                    size: 64, color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),

          // ---- Content ----
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back
                    TextButton.icon(
                      onPressed: () => context.go('/noticias'),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Volver'),
                    ),
                    const SizedBox(height: 16),

                    // Category + date
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(n.category,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ),
                        if (n.isUrgent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('URGENTE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          DateFormat('dd MMMM yyyy', 'es').format(n.createdAt),
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      n.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(height: 1.2),
                    ),
                    if (n.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(n.subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppTheme.textSecondary)),
                    ],
                    const SizedBox(height: 24),

                    // Rich content
                    if (n.richContent.isNotEmpty)
                      ...n.richContent.map(_renderBlock)
                    else
                      Text(n.content,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.7)),

                    // ---- Gallery ----
                    if (n.gallery.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Text('Galería',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: n.gallery.length,
                          itemBuilder: (_, i) {
                            final img = n.gallery[i];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () =>
                                    _showImageViewer(context, n.gallery, i),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: img['url'] ?? '',
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // ---- Attachments ----
                    if (n.attachments.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Adjuntos',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: n.attachments.map((adj) {
                          final isPdf =
                              (adj['tipo'] ?? '').startsWith('application/pdf');
                          return OutlinedButton.icon(
                            onPressed: () {
                              final url = adj['url'];
                              if (url != null && url.isNotEmpty) {
                                launchUrl(Uri.parse(url),
                                    mode: LaunchMode.externalApplication);
                                context
                                    .read<NoticiasService>()
                                    .registerCtaClick(n.id, 'adjunto');
                              }
                            },
                            icon: Icon(isPdf
                                ? Icons.picture_as_pdf
                                : Icons.attach_file),
                            label: Text(adj['nombre'] ?? 'Archivo'),
                          );
                        }).toList(),
                      ),
                    ],

                    // ---- CTAs ----
                    if (n.ctas.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: n.ctas.map((cta) {
                          return ElevatedButton.icon(
                            onPressed: () {
                              context
                                  .read<NoticiasService>()
                                  .registerCtaClick(n.id, cta.label);
                              if (cta.route.startsWith('http')) {
                                launchUrl(Uri.parse(cta.route),
                                    mode: LaunchMode.externalApplication);
                              } else if (cta.route.isNotEmpty) {
                                context.go(cta.route);
                              }
                            },
                            icon: Icon(_ctaIcon(cta.type)),
                            label: Text(cta.label),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // ---- Read confirmation ----
                    if (n.requireReadConfirmation && cofrade != null) ...[
                      const SizedBox(height: 24),
                      Card(
                        color: _readConfirmed
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _readConfirmed
                                ? Colors.green.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                _readConfirmed
                                    ? Icons.check_circle
                                    : Icons.info_outline,
                                color: _readConfirmed
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _readConfirmed
                                      ? 'Has confirmado la lectura de esta comunicación.'
                                      : 'Esta comunicación requiere confirmación de lectura.',
                                  style: TextStyle(
                                    color: _readConfirmed
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                                  ),
                                ),
                              ),
                              if (!_readConfirmed)
                                ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await context
                                          .read<NoticiasService>()
                                          .confirmRead(n.id, cofrade.id);
                                      setState(() => _readConfirmed = true);
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'No se pudo confirmar la lectura. Vuelve a intentarlo.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('He leído'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // ---- Related news ----
                    const SizedBox(height: 32),
                    _RelatedNewsSection(noticia: n),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderBlock(ContentBlock block) {
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
              border: Border(
                left: BorderSide(color: AppTheme.primaryColor, width: 4),
              ),
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
              border: Border(
                left: BorderSide(color: AppTheme.primaryColor, width: 4),
              ),
            ),
            child: Text(block.text,
                style: const TextStyle(fontSize: 15, height: 1.6)),
          ),
        );

      default: // paragraph
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(block.text,
              style: const TextStyle(fontSize: 15, height: 1.7)),
        );
    }
  }

  IconData _ctaIcon(String type) {
    switch (type) {
      case 'encuesta':
        return Icons.how_to_vote;
      case 'evento':
        return Icons.event;
      case 'cuotas':
        return Icons.account_balance_wallet;
      case 'documentos':
        return Icons.folder;
      case 'custom':
        return Icons.open_in_new;
      default:
        return Icons.link;
    }
  }

  void _showImageViewer(
      BuildContext context, List<Map<String, String>> gallery, int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: index),
              itemCount: gallery.length,
              itemBuilder: (_, i) {
                return InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: gallery[i]['url'] ?? '',
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// RELATED NEWS SECTION
// =============================================================================

class _RelatedNewsSection extends StatelessWidget {
  final Noticia noticia;
  const _RelatedNewsSection({required this.noticia});

  @override
  Widget build(BuildContext context) {
    final service = context.read<NoticiasService>();

    return StreamBuilder<List<Noticia>>(
      stream: service.getRelatedNoticias(noticia, limit: 3),
      builder: (context, snapshot) {
        final related = snapshot.data ?? [];
        if (related.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 12),
            Text('También te puede interesar',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...related.map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: (r.coverImageUrl ?? '').isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: r.coverImageUrl!,
                            width: 56,
                            height: 42,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 56,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.article,
                              color: Colors.grey, size: 20),
                        ),
                  title: Text(r.title,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy').format(r.createdAt),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    final route = r.slug.isNotEmpty
                        ? '/noticias/${r.slug}'
                        : '/noticias/detalle?id=${r.id}';
                    context.go(route);
                  },
                )),
          ],
        );
      },
    );
  }
}

// =============================================================================
// HEMEROTECA SCREEN
// =============================================================================

class HemerotecaScreen extends StatefulWidget {
  const HemerotecaScreen({super.key});

  @override
  State<HemerotecaScreen> createState() => _HemerotecaScreenState();
}

class _HemerotecaScreenState extends State<HemerotecaScreen> {
  int? _selectedYear;

  @override
  Widget build(BuildContext context) {
    final service = context.read<NoticiasService>();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primaryColor],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Hemeroteca',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Archivo histórico de la Cofradía',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppTheme.accentColor),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back
                    TextButton.icon(
                      onPressed: () => context.go('/noticias'),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Volver a noticias'),
                    ),
                    const SizedBox(height: 16),

                    // Year selector
                    StreamBuilder<List<int>>(
                      stream: service.getAvailableYears(),
                      builder: (context, snap) {
                        final years = snap.data ?? [];
                        if (years.isEmpty) {
                          return const Text('No hay noticias archivadas.');
                        }
                        _selectedYear ??= years.first;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: years.map((y) {
                                final selected = y == _selectedYear;
                                return ChoiceChip(
                                  label: Text('$y'),
                                  selected: selected,
                                  onSelected: (_) =>
                                      setState(() => _selectedYear = y),
                                  selectedColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.15),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                            StreamBuilder<List<Noticia>>(
                              stream: service.getNoticiasByYear(_selectedYear!),
                              builder: (context, nSnap) {
                                final noticias = nSnap.data ?? [];
                                if (noticias.isEmpty) {
                                  return const Text(
                                      'No hay noticias para este año.');
                                }
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: noticias.length,
                                  itemBuilder: (_, i) {
                                    final n = noticias[i];
                                    return ListTile(
                                      leading: Text(
                                        DateFormat('dd/MM').format(n.createdAt),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary),
                                      ),
                                      title: Text(n.title),
                                      subtitle: Text(n.category,
                                          style: const TextStyle(fontSize: 12)),
                                      trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14),
                                      onTap: () {
                                        final route = n.slug.isNotEmpty
                                            ? '/noticias/${n.slug}'
                                            : '/noticias/detalle?id=${n.id}';
                                        context.go(route);
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
