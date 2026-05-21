import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/noticia.dart';
import 'package:boanerges1714/services/noticias_service.dart';
import 'package:boanerges1714/services/storage_service.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';

// =============================================================================
// MANAGE NEWS SCREEN (CMS Dashboard)
// =============================================================================

class ManageNewsScreen extends StatefulWidget {
  const ManageNewsScreen({super.key});

  @override
  State<ManageNewsScreen> createState() => _ManageNewsScreenState();
}

class _ManageNewsScreenState extends State<ManageNewsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _filterStatus = 'all';
  String _filterCategory = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('CMS de Noticias',
                    style: Theme.of(context).textTheme.headlineMedium),
                ElevatedButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva Noticia'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(text: 'Noticias', icon: Icon(Icons.article)),
                Tab(text: 'Analítica', icon: Icon(Icons.analytics)),
                Tab(text: 'Categorías', icon: Icon(Icons.category)),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _NoticiasListTab(
                    filterStatus: _filterStatus,
                    filterCategory: _filterCategory,
                    searchQuery: _searchQuery,
                    onFilterStatusChanged: (v) =>
                        setState(() => _filterStatus = v),
                    onFilterCategoryChanged: (v) =>
                        setState(() => _filterCategory = v),
                    onSearchChanged: (v) =>
                        setState(() => _searchQuery = v),
                    onEdit: (n) => _openEditor(context, noticia: n),
                  ),
                  const _AnalyticsTab(),
                  const _CategoriesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, {Noticia? noticia}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _NoticiaEditorScreen(noticia: noticia),
    ));
  }
}

// =============================================================================
// NOTICIAS LIST TAB
// =============================================================================

class _NoticiasListTab extends StatelessWidget {
  final String filterStatus;
  final String filterCategory;
  final String searchQuery;
  final ValueChanged<String> onFilterStatusChanged;
  final ValueChanged<String> onFilterCategoryChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Noticia> onEdit;

  const _NoticiasListTab({
    required this.filterStatus,
    required this.filterCategory,
    required this.searchQuery,
    required this.onFilterStatusChanged,
    required this.onFilterCategoryChanged,
    required this.onSearchChanged,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<NoticiasService>();

    return Column(
      children: [
        // Filters row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar noticias...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onChanged: onSearchChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: filterStatus,
                decoration: InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Todos')),
                  DropdownMenuItem(
                      value: 'published', child: Text('Publicados')),
                  DropdownMenuItem(value: 'draft', child: Text('Borradores')),
                  DropdownMenuItem(
                      value: 'scheduled', child: Text('Programados')),
                  DropdownMenuItem(
                      value: 'archived', child: Text('Archivados')),
                ],
                onChanged: (v) => onFilterStatusChanged(v ?? 'all'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: filterCategory,
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('Todas')),
                  ...Noticia.defaultCategories.map((c) =>
                      DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => onFilterCategoryChanged(v ?? 'all'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // List
        Expanded(
          child: StreamBuilder<List<Noticia>>(
            stream: service.getAllNoticias(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var noticias = snapshot.data ?? [];

              // Apply filters
              if (filterStatus != 'all') {
                noticias = noticias
                    .where((n) => n.status.name == filterStatus)
                    .toList();
              }
              if (filterCategory != 'all') {
                noticias = noticias
                    .where((n) => n.category == filterCategory)
                    .toList();
              }
              if (searchQuery.isNotEmpty) {
                final q = searchQuery.toLowerCase();
                noticias = noticias
                    .where((n) =>
                        n.title.toLowerCase().contains(q) ||
                        n.shortDescription.toLowerCase().contains(q))
                    .toList();
              }

              if (noticias.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article_outlined,
                          size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No hay noticias.',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: noticias.length,
                itemBuilder: (context, index) {
                  final n = noticias[index];
                  return _NoticiaListItem(
                    noticia: n,
                    onEdit: () => onEdit(n),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// NOTICIA LIST ITEM
// =============================================================================

class _NoticiaListItem extends StatelessWidget {
  final Noticia noticia;
  final VoidCallback onEdit;

  const _NoticiaListItem({required this.noticia, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Cover thumbnail
              if ((noticia.coverImageUrl ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    noticia.coverImageUrl!,
                    width: 64,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 48),
                  ),
                )
              else
                Container(
                  width: 64,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.article, color: Colors.grey),
                ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            noticia.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _StatusChip(status: noticia.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _VisibilityChip(visibility: noticia.visibility),
                        const SizedBox(width: 8),
                        Text(noticia.category,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy').format(noticia.createdAt),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                        if (noticia.isPinned) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.push_pin,
                              size: 14, color: Colors.orange.shade700),
                        ],
                        if (noticia.isFeatured) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star,
                              size: 14, color: Colors.amber.shade700),
                        ],
                        if (noticia.isUrgent) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.warning_amber,
                              size: 14, color: Colors.red),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.visibility_outlined,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('${noticia.views}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ]),
                  const SizedBox(height: 2),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.done_all,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('${noticia.readCount}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ]),
                ],
              ),
              const SizedBox(width: 8),

              // Actions
              PopupMenuButton<String>(
                onSelected: (action) =>
                    _handleAction(context, action, noticia),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit', child: Text('Editar')),
                  if (noticia.status != NoticiaStatus.published)
                    const PopupMenuItem(
                        value: 'publish', child: Text('Publicar')),
                  if (noticia.status != NoticiaStatus.archived)
                    const PopupMenuItem(
                        value: 'archive', child: Text('Archivar')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar',
                          style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(
      BuildContext context, String action, Noticia noticia) async {
    final service = context.read<NoticiasService>();
    final auth = context.read<AuthService>();
    final userId = auth.cofrade?.nombre ?? auth.userId ?? 'admin';

    switch (action) {
      case 'edit':
        onEdit();
        break;
      case 'publish':
        try {
          await service.publishNoticia(noticia.id, userId);
        } catch (e) {
          debugPrint('[ManageNews] Error publicando: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo publicar la noticia. Vuelve a intentarlo.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        break;
      case 'archive':
        try {
          await service.archiveNoticia(noticia.id, userId);
        } catch (e) {
          debugPrint('[ManageNews] Error archivando: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo archivar la noticia. Vuelve a intentarlo.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        break;
      case 'delete':
        _confirmDelete(context, noticia);
        break;
    }
  }

  void _confirmDelete(BuildContext context, Noticia noticia) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar noticia'),
        content:
            Text('¿Estás seguro de eliminar "${noticia.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await context.read<NoticiasService>().deleteNoticia(noticia.id);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                debugPrint('[ManageNews] Error eliminando: $e');
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo eliminar la noticia. Vuelve a intentarlo.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STATUS & VISIBILITY CHIPS
// =============================================================================

class _StatusChip extends StatelessWidget {
  final NoticiaStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String label;
    switch (status) {
      case NoticiaStatus.published:
        bg = Colors.green;
        label = 'Publicada';
        break;
      case NoticiaStatus.draft:
        bg = Colors.grey;
        label = 'Borrador';
        break;
      case NoticiaStatus.scheduled:
        bg = Colors.blue;
        label = 'Programada';
        break;
      case NoticiaStatus.archived:
        bg = Colors.brown;
        label = 'Archivada';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: bg)),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  final NoticiaVisibility visibility;
  const _VisibilityChip({required this.visibility});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;
    switch (visibility) {
      case NoticiaVisibility.publica:
        icon = Icons.public;
        label = 'Pública';
        break;
      case NoticiaVisibility.privada:
        icon = Icons.lock;
        label = 'Privada';
        break;
      case NoticiaVisibility.segmentada:
        icon = Icons.people;
        label = 'Segmentada';
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}

// =============================================================================
// ANALYTICS TAB
// =============================================================================

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context) {
    final service = context.read<NoticiasService>();

    return StreamBuilder<Map<String, dynamic>>(
      stream: service.getGlobalAnalytics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Summary cards
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _MetricCard(
                    icon: Icons.article,
                    label: 'Publicadas',
                    value: '${data['totalPublished'] ?? 0}',
                    color: Colors.green,
                  ),
                  _MetricCard(
                    icon: Icons.edit_note,
                    label: 'Borradores',
                    value: '${data['totalDraft'] ?? 0}',
                    color: Colors.grey,
                  ),
                  _MetricCard(
                    icon: Icons.visibility,
                    label: 'Vistas totales',
                    value: '${data['totalViews'] ?? 0}',
                    color: Colors.blue,
                  ),
                  _MetricCard(
                    icon: Icons.done_all,
                    label: 'Confirmaciones',
                    value: '${data['totalReads'] ?? 0}',
                    color: AppTheme.primaryColor,
                  ),
                  _MetricCard(
                    icon: Icons.touch_app,
                    label: 'Clics CTA',
                    value: '${data['totalClicks'] ?? 0}',
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // By category
              Text('Noticias por categoría',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ..._buildCategoryBars(data['byCategory'] as Map<String, int>?),

              const SizedBox(height: 24),

              // Most viewed
              Text('Más vistas',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...((data['mostViewed'] as List<Noticia>?) ?? []).map((n) =>
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.trending_up),
                    title: Text(n.title),
                    trailing: Text('${n.views} vistas'),
                  )),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildCategoryBars(Map<String, int>? byCategory) {
    if (byCategory == null || byCategory.isEmpty) {
      return [const Text('Sin datos', style: TextStyle(color: Colors.grey))];
    }
    final maxVal =
        byCategory.values.fold<int>(0, (a, b) => a > b ? a : b).toDouble();
    return byCategory.entries.map((entry) {
      final pct = maxVal > 0 ? entry.value / maxVal : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
                width: 110,
                child: Text(entry.key, style: const TextStyle(fontSize: 13))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${entry.value}', style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
    }).toList();
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: SizedBox(
        width: 160,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CATEGORIES TAB
// =============================================================================

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Categorías disponibles',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Las categorías permiten organizar las noticias por temática.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Noticia.defaultCategories.map((cat) {
              return Chip(
                avatar: Icon(_categoryIcon(cat), size: 18),
                label: Text(cat),
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Institucional':
        return Icons.account_balance;
      case 'Cultos':
        return Icons.church;
      case 'Procesiones':
        return Icons.directions_walk;
      case 'Juventud':
        return Icons.people;
      case 'Tesorería':
        return Icons.account_balance_wallet;
      case 'Caridad':
        return Icons.favorite;
      case 'Eventos':
        return Icons.event;
      case 'Patrimonio':
        return Icons.museum;
      case 'Avisos':
        return Icons.campaign;
      case 'Formación':
        return Icons.school;
      default:
        return Icons.label;
    }
  }
}

// =============================================================================
// NOTICIA EDITOR SCREEN (Full page CMS editor)
// =============================================================================

class _NoticiaEditorScreen extends StatefulWidget {
  final Noticia? noticia;
  const _NoticiaEditorScreen({this.noticia});

  @override
  State<_NoticiaEditorScreen> createState() => _NoticiaEditorScreenState();
}

class _NoticiaEditorScreenState extends State<_NoticiaEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _subtitleCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _shortDescCtrl;
  late final TextEditingController _contentCtrl;

  String _category = 'Institucional';
  NoticiaVisibility _visibility = NoticiaVisibility.publica;
  NoticiaStatus _status = NoticiaStatus.draft;
  List<String> _targetTags = [];
  List<String> _tags = [];
  bool _isFeatured = false;
  bool _isPinned = false;
  bool _isUrgent = false;
  bool _showOnHomepage = true;
  bool _requireReadConfirmation = false;
  String? _coverImageUrl;
  List<Map<String, String>> _gallery = [];
  List<Map<String, String>> _attachments = [];
  List<NoticiaCta> _ctas = [];
  DateTime? _publishAt;
  DateTime? _expireAt;
  List<ContentBlock> _richContent = [];
  bool _uploading = false;
  bool _saving = false;
  bool _slugManuallyEdited = false;

  // Available tags — loaded from Firestore
  List<String> _availableTags = [];
  // Tag name cache: id → readable name
  Map<String, String> _tagNameCache = {};

  @override
  void initState() {
    super.initState();
    final n = widget.noticia;
    _titleCtrl = TextEditingController(text: n?.title ?? '');
    _subtitleCtrl = TextEditingController(text: n?.subtitle ?? '');
    _slugCtrl = TextEditingController(text: n?.slug ?? '');
    _shortDescCtrl = TextEditingController(text: n?.shortDescription ?? '');
    _contentCtrl = TextEditingController(text: n?.content ?? '');

    if (n != null) {
      _category = n.category;
      _visibility = n.visibility;
      _status = n.status;
      _targetTags = List.from(n.targetTags);
      _tags = List.from(n.tags);
      _isFeatured = n.isFeatured;
      _isPinned = n.isPinned;
      _isUrgent = n.isUrgent;
      _showOnHomepage = n.showOnHomepage;
      _requireReadConfirmation = n.requireReadConfirmation;
      _coverImageUrl = n.coverImageUrl;
      _gallery = List.from(n.gallery);
      _attachments = List.from(n.attachments);
      _ctas = List.from(n.ctas);
      _publishAt = n.publishAt;
      _expireAt = n.expireAt;
      _richContent = List.from(n.richContent);
      _slugManuallyEdited = n.slug.isNotEmpty;
    }

    _titleCtrl.addListener(_onTitleChanged);
    _loadAvailableTags();
  }

  void _onTitleChanged() {
    if (!_slugManuallyEdited) {
      _slugCtrl.text = Noticia.generateSlug(_titleCtrl.text);
    }
  }

  Future<void> _loadAvailableTags() async {
    try {
      // Load tags collection for readable names
      final db = FirebaseFirestore.instance;
      final tagsSnap = await db.collection('tags').get();
      final nameCache = <String, String>{};
      for (final doc in tagsSnap.docs) {
        final data = doc.data();
        final name = data['name'] ?? data['title'] ?? data['label'] ?? doc.id;
        nameCache[doc.id] = name;
      }

      // Also load from cofrades for completeness
      final firestoreService = context.read<FirestoreService>();
      final cofrades = await firestoreService.getAllCofradesStream().first;
      final tags = <String>{};
      for (final c in cofrades) {
        tags.addAll(c.tagsManual);
        tags.addAll(c.tagsAuto);
      }
      // Add tags from tags collection
      for (final id in nameCache.keys) {
        tags.add(id);
      }
      if (mounted) {
        setState(() {
          _availableTags = tags.toList()..sort();
          _tagNameCache = nameCache;
        });
      }
    } catch (_) {}
  }

  /// Get readable name for a tag (uses cache, falls back to tag id)
  String _tagDisplayName(String tagId) {
    return _tagNameCache[tagId] ?? tagId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _slugCtrl.dispose();
    _shortDescCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.noticia != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Noticia' : 'Nueva Noticia'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (isEditing)
            TextButton.icon(
              onPressed: () => _showAuditLog(context),
              icon: const Icon(Icons.history, color: Colors.white70),
              label: const Text('Historial',
                  style: TextStyle(color: Colors.white70)),
            ),
          if (isEditing)
            TextButton.icon(
              onPressed: () => _showAnalytics(context),
              icon: const Icon(Icons.analytics, color: Colors.white70),
              label: const Text('Analítica',
                  style: TextStyle(color: Colors.white70)),
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Guardando...' : 'Guardar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Basic info ----
                _SectionHeader(title: 'Información básica'),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título *',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subtitleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subtítulo (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _slugCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Slug (URL amigable)',
                          border: OutlineInputBorder(),
                          prefixText: '/noticias/',
                        ),
                        onChanged: (_) => _slugManuallyEdited = true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _shortDescCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción corta',
                    border: OutlineInputBorder(),
                    helperText: 'Se usa en listados y previews',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // ---- Content ----
                _SectionHeader(title: 'Contenido'),
                const SizedBox(height: 12),
                _RichContentEditor(
                  blocks: _richContent,
                  onChanged: (blocks) =>
                      setState(() => _richContent = blocks),
                  onUploadImage: _uploadContentImage,
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  title: const Text('Contenido de texto plano (fallback)'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        controller: _contentCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Contenido',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ---- Category ----
                _SectionHeader(title: 'Categoría'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categoría principal',
                          border: OutlineInputBorder(),
                        ),
                        items: Noticia.defaultCategories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _category = v ?? 'Institucional'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ---- Content Tags ----
                _SectionHeader(title: 'Tags de contenido'),
                const SizedBox(height: 4),
                const Text(
                  'Sirven para clasificar la noticia y mostrar contenidos relacionados.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ..._tags.map((t) => Chip(
                          label: Text(_tagDisplayName(t), style: const TextStyle(fontSize: 12)),
                          onDeleted: () =>
                              setState(() => _tags.remove(t)),
                        )),
                    ActionChip(
                      label: const Text('+ Añadir tag'),
                      onPressed: () => _showTagPicker(
                        'Tags de contenido',
                        _tags,
                        (selected) => setState(() => _tags = selected),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ---- Visibility ----
                _SectionHeader(title: 'Visibilidad y Destinatarios'),
                const SizedBox(height: 12),
                DropdownButtonFormField<NoticiaVisibility>(
                  value: _visibility,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de visibilidad',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: NoticiaVisibility.publica,
                        child: Text('Pública (visible sin login)')),
                    DropdownMenuItem(
                        value: NoticiaVisibility.privada,
                        child: Text('Privada (solo cofrades)')),
                    DropdownMenuItem(
                        value: NoticiaVisibility.segmentada,
                        child: Text('Segmentada por tags')),
                  ],
                  onChanged: (v) => setState(
                      () => _visibility = v ?? NoticiaVisibility.publica),
                ),
                if (_visibility == NoticiaVisibility.segmentada) ...[
                  const SizedBox(height: 16),
                  _SectionHeader(title: 'Destinatarios por tags'),
                  const SizedBox(height: 4),
                  const Text(
                    'Solo los cofrades con alguna de estas tags podrán ver esta noticia.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ..._targetTags.map((t) => Chip(
                            label:
                                Text(_tagDisplayName(t), style: const TextStyle(fontSize: 12)),
                            onDeleted: () =>
                                setState(() => _targetTags.remove(t)),
                          )),
                      ActionChip(
                        label: const Text('+ Añadir tag'),
                        onPressed: () => _showTagPicker(
                          'Destinatarios por tags',
                          _targetTags,
                          (selected) =>
                              setState(() => _targetTags = selected),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),

                // ---- Flags ----
                _SectionHeader(title: 'Opciones de visualización'),
                const SizedBox(height: 8),
                _FlagSwitch(
                  label: 'Destacada',
                  subtitle: 'Aparece resaltada en portada',
                  icon: Icons.star,
                  value: _isFeatured,
                  onChanged: (v) => setState(() => _isFeatured = v),
                ),
                _FlagSwitch(
                  label: 'Fijada arriba',
                  subtitle: 'Permanece al inicio del listado',
                  icon: Icons.push_pin,
                  value: _isPinned,
                  onChanged: (v) => setState(() => _isPinned = v),
                ),
                _FlagSwitch(
                  label: 'Urgente',
                  subtitle: 'Aparece como banner prioritario',
                  icon: Icons.warning_amber,
                  value: _isUrgent,
                  onChanged: (v) => setState(() => _isUrgent = v),
                ),
                _FlagSwitch(
                  label: 'Mostrar en portada',
                  subtitle: 'Visible en la portada pública',
                  icon: Icons.home,
                  value: _showOnHomepage,
                  onChanged: (v) => setState(() => _showOnHomepage = v),
                ),
                _FlagSwitch(
                  label: 'Confirmación de lectura obligatoria',
                  subtitle: 'Los cofrades deben confirmar que han leído',
                  icon: Icons.done_all,
                  value: _requireReadConfirmation,
                  onChanged: (v) =>
                      setState(() => _requireReadConfirmation = v),
                ),
                const SizedBox(height: 24),

                // ---- Scheduling ----
                _SectionHeader(title: 'Programación'),
                const SizedBox(height: 12),
                DropdownButtonFormField<NoticiaStatus>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: NoticiaStatus.draft,
                        child: Text('Borrador')),
                    DropdownMenuItem(
                        value: NoticiaStatus.scheduled,
                        child: Text('Programada')),
                    DropdownMenuItem(
                        value: NoticiaStatus.published,
                        child: Text('Publicada')),
                    DropdownMenuItem(
                        value: NoticiaStatus.archived,
                        child: Text('Archivada')),
                  ],
                  onChanged: (v) =>
                      setState(() => _status = v ?? NoticiaStatus.draft),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Fecha de publicación',
                        value: _publishAt,
                        onChanged: (d) =>
                            setState(() => _publishAt = d),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePickerField(
                        label: 'Fecha de expiración',
                        value: _expireAt,
                        onChanged: (d) =>
                            setState(() => _expireAt = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ---- Cover ----
                _SectionHeader(title: 'Imagen de portada'),
                const SizedBox(height: 12),
                if ((_coverImageUrl ?? '').isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _coverImageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _coverImageUrl = null),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Quitar portada'),
                    ),
                  ),
                ],
                OutlinedButton.icon(
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Subir imagen de portada'),
                  onPressed: _uploading ? null : _uploadCover,
                ),
                const SizedBox(height: 24),

                // ---- Gallery ----
                _SectionHeader(title: 'Galería de imágenes'),
                const SizedBox(height: 4),
                const Text(
                  'Añade varias imágenes para actos, cultos, procesiones, patrimonio o eventos. Formatos: jpg, png, webp.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                if (_gallery.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _gallery.length,
                      itemBuilder: (_, i) {
                        final img = _gallery[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  img['url'] ?? '',
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _gallery.removeAt(i)),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Subir imágenes a galería'),
                  onPressed: _uploading ? null : _uploadGalleryImage,
                ),
                const SizedBox(height: 24),

                // ---- Attachments ----
                _SectionHeader(title: 'Adjuntos'),
                const SizedBox(height: 12),
                ..._attachments.asMap().entries.map((entry) {
                  final i = entry.key;
                  final adj = entry.value;
                  final isPdf =
                      (adj['tipo'] ?? '').startsWith('application/pdf');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.attach_file,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(adj['nombre'] ?? 'Archivo',
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(adj['tipo'] ?? '',
                        style: const TextStyle(fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: Colors.red),
                      onPressed: () =>
                          setState(() => _attachments.removeAt(i)),
                    ),
                  );
                }),
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Adjuntar archivo'),
                  onPressed: _uploading ? null : _uploadAttachment,
                ),
                if (_uploading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 24),

                // ---- CTAs ----
                _SectionHeader(title: 'Botones de acción (CTA)'),
                const SizedBox(height: 12),
                ..._ctas.asMap().entries.map((entry) {
                  final i = entry.key;
                  final cta = entry.value;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.touch_app),
                    title: Text(cta.label),
                    subtitle: Text('${cta.type} → ${cta.route}',
                        style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: Colors.red),
                      onPressed: () =>
                          setState(() => _ctas.removeAt(i)),
                    ),
                  );
                }),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir CTA'),
                  onPressed: _addCta,
                ),
                const SizedBox(height: 32),

                // ---- Save ----
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_saving ? 'Guardando...' : 'Guardar noticia'),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Save logic ----
  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final service = context.read<NoticiasService>();
      final auth = context.read<AuthService>();
      final userId = auth.cofrade?.nombre ?? auth.userId ?? 'admin';

      final slug = _slugCtrl.text.isNotEmpty
          ? _slugCtrl.text
          : Noticia.generateSlug(_titleCtrl.text);

      final noticia = Noticia(
        id: widget.noticia?.id ?? '',
        title: _titleCtrl.text,
        subtitle: _subtitleCtrl.text,
        slug: slug,
        shortDescription: _shortDescCtrl.text,
        content: _contentCtrl.text,
        richContent: _richContent,
        category: _category,
        tags: _tags,
        visibility: _visibility,
        targetTags: _targetTags,
        isFeatured: _isFeatured,
        isPinned: _isPinned,
        isUrgent: _isUrgent,
        showOnHomepage: _showOnHomepage,
        requireReadConfirmation: _requireReadConfirmation,
        coverImageUrl: _coverImageUrl,
        gallery: _gallery,
        attachments: _attachments,
        ctas: _ctas,
        publishAt: _publishAt,
        expireAt: _expireAt,
        status: _status,
        createdAt: widget.noticia?.createdAt ?? DateTime.now(),
        createdBy: widget.noticia?.createdBy ?? userId,
        updatedBy: userId,
      );

      if (widget.noticia == null) {
        await service.createNoticia(noticia);
      } else {
        await service.updateNoticia(
          widget.noticia!.id,
          noticia,
          userId,
          previousVersion: widget.noticia,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.noticia == null
                ? 'Noticia guardada correctamente'
                : 'Noticia actualizada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ManageNews] Error guardando noticia: $e');
      if (mounted) {
        String userMessage;
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('permission') || errorStr.contains('denied') || errorStr.contains('unauthorized')) {
          userMessage = 'No se pudo guardar la noticia. Revisa los permisos o vuelve a intentarlo.';
        } else if (errorStr.contains('network') || errorStr.contains('unavailable')) {
          userMessage = 'Error de conexi\u00f3n. Comprueba tu conexi\u00f3n a internet y vuelve a intentarlo.';
        } else {
          userMessage = 'No se pudo guardar la noticia. Vuelve a intentarlo.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---- Upload helpers ----
  Future<void> _uploadCover() async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final storage = context.read<StorageService>();
          final newsId = widget.noticia?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
          final uploaded = await storage.uploadFile(
            path: 'news/$newsId/cover',
            bytes: file.bytes!,
            fileName: file.name,
            allowedExtensions: {'jpg', 'jpeg', 'png', 'webp'},
            maxSizeBytes: 8 * 1024 * 1024,
          );
          setState(() => _coverImageUrl = uploaded['url']);
        }
      }
    } catch (e) {
      debugPrint('[ManageNews] Error subiendo portada: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo subir la imagen de portada. Comprueba el formato y vuelve a intentarlo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _uploadGalleryImage() async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );
      if (result != null) {
        final storage = context.read<StorageService>();
        final newsId = widget.noticia?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
        int successCount = 0;
        int failCount = 0;
        for (final file in result.files) {
          if (file.bytes != null) {
            try {
              final uploaded = await storage.uploadFile(
                path: 'news/$newsId/gallery',
                bytes: file.bytes!,
                fileName: file.name,
                allowedExtensions: {'jpg', 'jpeg', 'png', 'webp'},
                maxSizeBytes: 8 * 1024 * 1024,
              );
              setState(() => _gallery.add(uploaded));
              successCount++;
            } catch (e) {
              debugPrint('[ManageNews] Error subiendo imagen de galería ${file.name}: $e');
              failCount++;
            }
          }
        }
        if (failCount > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                successCount > 0
                    ? 'Se subieron $successCount imágenes, pero $failCount fallaron. Vuelve a intentarlo.'
                    : 'No se pudieron subir las imágenes. Comprueba el formato (jpg, png, webp) y vuelve a intentarlo.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ManageNews] Error subiendo galería: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron subir las imágenes. Comprueba el formato y vuelve a intentarlo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _uploadAttachment() async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final storage = context.read<StorageService>();
          final newsId = widget.noticia?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
          final uploaded = await storage.uploadFile(
            path: 'news/$newsId/attachments',
            bytes: file.bytes!,
            fileName: file.name,
          );
          setState(() => _attachments.add(uploaded));
        }
      }
    } catch (e) {
      debugPrint('[ManageNews] Error subiendo adjunto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo subir el archivo. Vuelve a intentarlo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  // ---- Content image upload ----
  Future<String?> _uploadContentImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final ext = file.name.split('.').last.toLowerCase();
          if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Formato no permitido. Usa jpg, png o webp.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return null;
          }
          final storage = context.read<StorageService>();
          final newsId = widget.noticia?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
          final uploaded = await storage.uploadFile(
            path: 'news/$newsId/content',
            bytes: file.bytes!,
            fileName: file.name,
            allowedExtensions: {'jpg', 'jpeg', 'png', 'webp'},
            maxSizeBytes: 8 * 1024 * 1024,
          );
          return uploaded['url'];
        }
      }
    } catch (e) {
      debugPrint('[ManageNews] Error subiendo imagen de contenido: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo subir la imagen. Comprueba el formato y vuelve a intentarlo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return null;
  }

  // ---- Tag picker ----
  void _showTagPicker(
      String title, List<String> current, ValueChanged<List<String>> onDone) {
    final selected = Set<String>.from(current);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _availableTags.map((tag) {
                  final isSelected = selected.contains(tag);
                  return FilterChip(
                    label: Text(_tagDisplayName(tag)),
                    selected: isSelected,
                    onSelected: (v) {
                      setD(() {
                        if (v) {
                          selected.add(tag);
                        } else {
                          selected.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                onDone(selected.toList());
                Navigator.pop(ctx);
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- CTA dialog ----
  void _addCta() {
    final labelCtrl = TextEditingController();
    final routeCtrl = TextEditingController();
    String type = 'link';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Nuevo CTA'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                    labelText: 'Texto del botón *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration:
                    const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'link', child: Text('Enlace')),
                  DropdownMenuItem(
                      value: 'encuesta', child: Text('Ver encuesta')),
                  DropdownMenuItem(
                      value: 'evento', child: Text('Ver evento')),
                  DropdownMenuItem(
                      value: 'cuotas', child: Text('Ir a cuotas')),
                  DropdownMenuItem(
                      value: 'documentos', child: Text('Documentos')),
                  DropdownMenuItem(
                      value: 'custom', child: Text('Personalizado')),
                ],
                onChanged: (v) => setD(() => type = v ?? 'link'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: routeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ruta / URL',
                  hintText: '/encuestas, /eventos, https://...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (labelCtrl.text.isEmpty) return;
                setState(() {
                  _ctas.add(NoticiaCta(
                    label: labelCtrl.text,
                    route: routeCtrl.text,
                    type: type,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Audit log ----
  void _showAuditLog(BuildContext context) {
    final service = context.read<NoticiasService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Historial de cambios'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: service.getAuditLog(widget.noticia!.id),
            builder: (ctx, snap) {
              final entries = snap.data ?? [];
              if (entries.isEmpty) {
                return const Center(child: Text('Sin historial'));
              }
              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final e = entries[i];
                  final ts = (e['timestamp'] as Timestamp?)?.toDate();
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      e['action'] == 'created'
                          ? Icons.add_circle
                          : e['action'] == 'published'
                              ? Icons.publish
                              : e['action'] == 'archived'
                                  ? Icons.archive
                                  : Icons.edit,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    title: Text('${e['action']} por ${e['userId']}'),
                    subtitle: ts != null
                        ? Text(DateFormat('dd/MM/yyyy HH:mm').format(ts))
                        : null,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  // ---- Analytics dialog ----
  void _showAnalytics(BuildContext context) {
    final service = context.read<NoticiasService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Analítica'),
        content: SizedBox(
          width: 400,
          child: FutureBuilder<Map<String, dynamic>>(
            future: service.getAnalytics(widget.noticia!.id),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AnalyticRow(
                      icon: Icons.visibility,
                      label: 'Vistas',
                      value: '${data['views'] ?? 0}'),
                  _AnalyticRow(
                      icon: Icons.done_all,
                      label: 'Confirmaciones lectura',
                      value: '${data['readCount'] ?? 0}'),
                  _AnalyticRow(
                      icon: Icons.touch_app,
                      label: 'Clics CTA',
                      value: '${data['clickCount'] ?? 0}'),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }
}

class _AnalyticRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _AnalyticRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

// =============================================================================
// RICH CONTENT EDITOR (block-based)
// =============================================================================

class _RichContentEditor extends StatelessWidget {
  final List<ContentBlock> blocks;
  final ValueChanged<List<ContentBlock>> onChanged;
  final Future<String?> Function() onUploadImage;

  const _RichContentEditor({
    required this.blocks,
    required this.onChanged,
    required this.onUploadImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Wrap(
              spacing: 4,
              children: [
                _ToolbarBtn(
                    icon: Icons.text_fields,
                    tooltip: 'Párrafo',
                    onTap: () => _addBlock('paragraph')),
                _ToolbarBtn(
                    icon: Icons.title,
                    tooltip: 'Título',
                    onTap: () => _addBlock('heading')),
                _ToolbarBtn(
                    icon: Icons.format_list_bulleted,
                    tooltip: 'Lista',
                    onTap: () => _addBlock('list')),
                _ToolbarBtn(
                    icon: Icons.format_quote,
                    tooltip: 'Cita',
                    onTap: () => _addBlock('quote')),
                _ToolbarBtn(
                    icon: Icons.image,
                    tooltip: 'Subir imagen al contenido',
                    onTap: () => _addImageBlock()),
                _ToolbarBtn(
                    icon: Icons.horizontal_rule,
                    tooltip: 'Separador',
                    onTap: () => _addBlock('divider')),
                _ToolbarBtn(
                    icon: Icons.highlight,
                    tooltip: 'Bloque destacado',
                    onTap: () => _addBlock('highlight')),
              ],
            ),
          ),

          // Blocks
          if (blocks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Usa la barra de herramientas para añadir bloques de contenido.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: blocks.length,
            onReorder: (oldIndex, newIndex) {
              final updated = List<ContentBlock>.from(blocks);
              if (oldIndex < newIndex) newIndex--;
              final item = updated.removeAt(oldIndex);
              updated.insert(newIndex, item);
              onChanged(updated);
            },
            itemBuilder: (context, index) {
              final block = blocks[index];
              return _ContentBlockEditor(
                key: ValueKey('block_$index'),
                block: block,
                index: index,
                onChanged: (updated) {
                  final list = List<ContentBlock>.from(blocks);
                  list[index] = updated;
                  onChanged(list);
                },
                onDelete: () {
                  final list = List<ContentBlock>.from(blocks);
                  list.removeAt(index);
                  onChanged(list);
                },
                onUploadImage: onUploadImage,
              );
            },
          ),
        ],
      ),
    );
  }

  void _addBlock(String type) {
    final updated = List<ContentBlock>.from(blocks);
    updated.add(ContentBlock(type: type));
    onChanged(updated);
  }

  Future<void> _addImageBlock() async {
    final url = await onUploadImage();
    if (url != null && url.isNotEmpty) {
      final updated = List<ContentBlock>.from(blocks);
      updated.add(ContentBlock(type: 'image', imageUrl: url));
      onChanged(updated);
    }
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ToolbarBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _ContentBlockEditor extends StatelessWidget {
  final ContentBlock block;
  final int index;
  final ValueChanged<ContentBlock> onChanged;
  final VoidCallback onDelete;
  final Future<String?> Function() onUploadImage;

  const _ContentBlockEditor({
    super.key,
    required this.block,
    required this.index,
    required this.onChanged,
    required this.onDelete,
    required this.onUploadImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(top: 8, right: 4),
              child: Icon(Icons.drag_handle, size: 18, color: Colors.grey),
            ),
          ),
          Expanded(child: _buildEditor()),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    switch (block.type) {
      case 'heading':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Título',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const Spacer(),
                DropdownButton<int>(
                  value: block.level,
                  underline: const SizedBox(),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('H1')),
                    DropdownMenuItem(value: 2, child: Text('H2')),
                    DropdownMenuItem(value: 3, child: Text('H3')),
                  ],
                  onChanged: (v) =>
                      onChanged(ContentBlock(
                          type: 'heading', text: block.text, level: v ?? 1)),
                ),
              ],
            ),
            TextField(
              controller: TextEditingController(text: block.text),
              decoration:
                  const InputDecoration(hintText: 'Texto del título...'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: block.level == 1
                    ? 22
                    : block.level == 2
                        ? 18
                        : 15,
              ),
              onChanged: (v) => onChanged(ContentBlock(
                  type: 'heading', text: v, level: block.level)),
            ),
          ],
        );

      case 'list':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lista',
                style:
                    TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            TextField(
              controller: TextEditingController(
                  text: block.items.join('\n')),
              decoration: const InputDecoration(
                hintText: 'Un elemento por línea...',
              ),
              maxLines: 5,
              onChanged: (v) => onChanged(ContentBlock(
                type: 'list',
                items: v.split('\n').where((l) => l.isNotEmpty).toList(),
              )),
            ),
          ],
        );

      case 'quote':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cita',
                style:
                    TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            TextField(
              controller: TextEditingController(text: block.text),
              decoration: const InputDecoration(
                hintText: 'Texto de la cita...',
              ),
              maxLines: 3,
              style: const TextStyle(fontStyle: FontStyle.italic),
              onChanged: (v) =>
                  onChanged(ContentBlock(type: 'quote', text: v)),
            ),
          ],
        );

      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Imagen del contenido',
                style:
                    TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            if ((block.imageUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  block.imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Text('Error cargando imagen',
                          style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Reemplazar', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final url = await onUploadImage();
                      if (url != null && url.isNotEmpty) {
                        onChanged(ContentBlock(type: 'image', imageUrl: url));
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text('Quitar', style: TextStyle(fontSize: 12, color: Colors.red)),
                    onPressed: () => onChanged(ContentBlock(type: 'image', imageUrl: '')),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Subir imagen al contenido'),
                onPressed: () async {
                  final url = await onUploadImage();
                  if (url != null && url.isNotEmpty) {
                    onChanged(ContentBlock(type: 'image', imageUrl: url));
                  }
                },
              ),
            ],
          ],
        );

      case 'divider':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(),
        );

      case 'highlight':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bloque destacado',
                style:
                    TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(
                      color: AppTheme.primaryColor, width: 3),
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: TextEditingController(text: block.text),
                decoration: const InputDecoration(
                  hintText: 'Texto destacado...',
                  border: InputBorder.none,
                ),
                maxLines: 3,
                onChanged: (v) =>
                    onChanged(ContentBlock(type: 'highlight', text: v)),
              ),
            ),
          ],
        );

      default: // paragraph
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Párrafo',
                style:
                    TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            TextField(
              controller: TextEditingController(text: block.text),
              decoration: const InputDecoration(
                hintText: 'Escribe aquí...',
              ),
              maxLines: 4,
              onChanged: (v) =>
                  onChanged(ContentBlock(type: 'paragraph', text: v)),
            ),
          ],
        );
    }
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 4),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor)),
      ],
    );
  }
}

class _FlagSwitch extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FlagSwitch({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: AppTheme.primaryColor),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
        );
        if (picked != null) {
          final time = await showTimePicker(
            context: context,
            initialTime:
                TimeOfDay.fromDateTime(value ?? DateTime.now()),
          );
          if (time != null) {
            onChanged(DateTime(
              picked.year,
              picked.month,
              picked.day,
              time.hour,
              time.minute,
            ));
          } else {
            onChanged(picked);
          }
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(value!)
              : 'Sin fecha',
          style: TextStyle(
            color: value != null ? null : Colors.grey,
          ),
        ),
      ),
    );
  }
}
