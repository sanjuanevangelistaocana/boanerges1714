import 'package:file_picker/file_picker.dart';
import 'package:boanerges1714/widgets/responsive_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/content_block.dart';
import 'package:boanerges1714/models/content_models.dart';
import 'package:boanerges1714/services/content_service.dart';
import 'package:boanerges1714/services/storage_service.dart';
import 'package:boanerges1714/widgets/content_block_editor.dart';

class ContentAdminScreen extends StatefulWidget {
  final String? initialSectionId;

  const ContentAdminScreen({
    super.key,
    this.initialSectionId,
  });

  @override
  State<ContentAdminScreen> createState() => _ContentAdminScreenState();
}

class _ContentAdminScreenState extends State<ContentAdminScreen> {
  late final ContentService _content;
  final _storage = StorageService();
  String? _selectedId;
  bool _seeding = false;
  bool _importingHistory = false;

  @override
  void initState() {
    super.initState();
    _content = context.read<ContentService>();
    _selectedId = widget.initialSectionId;
    _seed();
  }

  Future<void> _seed() async {
    setState(() => _seeding = true);
    try {
      await _content.ensureSystemSections();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _importHistory() async {
    setState(() => _importingHistory = true);
    try {
      await _content.importInitialHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Contenido inicial de Historia importado.')));
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _importingHistory = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final code = error is FirebaseException ? error.code : 'content-error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error [$code]: $error')),
    );
  }

  Future<void> _showSectionEditor({ContentSection? section}) async {
    final title = TextEditingController(text: section?.title ?? '');
    final slug = TextEditingController(text: section?.slug ?? '');
    final description =
        TextEditingController(text: section?.shortDescription ?? '');
    final order = TextEditingController(text: (section?.order ?? 0).toString());
    final icon = TextEditingController(text: section?.icon ?? '');
    var type = section?.type ?? ContentSectionType.articulos;
    var published = section?.published ?? true;
    String? parentId = section?.parentId;
    String? coverImageUrl = section?.coverImageUrl;
    final ownerId =
        section?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
    await showAppDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(section == null ? 'Nueva sección' : 'Editar sección'),
          content: ResponsiveDialogBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Título *'),
                  ),
                  TextField(
                    controller: slug,
                    decoration:
                        const InputDecoration(labelText: 'Slug único *'),
                  ),
                  TextField(
                    controller: description,
                    decoration:
                        const InputDecoration(labelText: 'Descripción corta'),
                    maxLines: 2,
                  ),
                  TextField(
                    controller: order,
                    decoration: const InputDecoration(labelText: 'Orden'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: icon,
                    decoration:
                        const InputDecoration(labelText: 'Icono opcional'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final uploaded =
                          await _upload('content/$ownerId/images', pdf: false);
                      if (uploaded != null) {
                        setDialogState(() => coverImageUrl = uploaded['url']);
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(coverImageUrl == null
                        ? 'Subir portada'
                        : 'Reemplazar portada'),
                  ),
                  DropdownButtonFormField<ContentSectionType>(
                    value: type,
                    decoration:
                        const InputDecoration(labelText: 'Tipo de contenido'),
                    items: ContentSectionType.values
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(_typeLabel(value)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => type = value);
                    },
                  ),
                  DropdownButtonFormField<String?>(
                    value: parentId,
                    decoration:
                        const InputDecoration(labelText: 'Sección padre'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Raíz')),
                      ...(_parentSections
                          .where((item) => item.id != section?.id)
                          .map((item) => DropdownMenuItem<String?>(
                                value: item.id,
                                child: Text(item.title),
                              ))),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => parentId = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publicada'),
                    value: published,
                    onChanged: (value) =>
                        setDialogState(() => published = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty || slug.text.trim().isEmpty) {
                  return;
                }
                final now = DateTime.now();
                final data = ContentSection(
                  id: section?.id ?? '',
                  slug: slug.text.trim(),
                  parentId: parentId,
                  title: title.text.trim(),
                  shortDescription: description.text.trim(),
                  type: type,
                  order: int.tryParse(order.text) ?? 0,
                  published: published,
                  coverImageUrl: coverImageUrl,
                  icon: icon.text.trim().isEmpty ? null : icon.text.trim(),
                  system: section?.system ?? false,
                  deleted: false,
                  createdAt: section?.createdAt ?? now,
                  updatedAt: now,
                  createdBy: section?.createdBy ?? '',
                  updatedBy: section?.updatedBy ?? '',
                );
                try {
                  if (section == null) {
                    await _content.createSection(data);
                  } else {
                    await _content.updateSection(
                        section.id, data.toFirestore());
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  _showError(error);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  List<ContentSection> _parentSections = [];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContentSection>>(
      stream: _content.watchSections(admin: true),
      builder: (context, snapshot) {
        final sections = snapshot.data ?? [];
        _parentSections = sections;
        final selected = sections
            .where((section) => section.id == _selectedId)
            .cast<ContentSection?>()
            .firstWhere((section) => section != null, orElse: () => null);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Contenido institucional',
                            style: Theme.of(context).textTheme.headlineMedium),
                      ),
                      OutlinedButton.icon(
                        onPressed: _seeding ? null : _seed,
                        icon: const Icon(Icons.account_tree_outlined),
                        label: Text(
                            _seeding ? 'Sembrando...' : 'Restaurar estructura'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _importingHistory ? null : _importHistory,
                        icon: const Icon(Icons.history_edu),
                        label: Text(_importingHistory
                            ? 'Importando...'
                            : 'Importar Historia inicial'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _showSectionEditor(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva sección'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Las secciones de sistema se pueden renombrar y reordenar, pero no eliminar.',
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.hasError)
                    _ErrorCard(error: snapshot.error!, onRetry: _seed),
                  if (sections.isEmpty && !snapshot.hasError)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No hay secciones todavía.')),
                      ),
                    ),
                  ...sections
                      .where((section) => section.parentId == null)
                      .map((root) => _buildSectionTree(root, sections)),
                  if (selected != null) _buildSectionContent(selected),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTree(
      ContentSection section, List<ContentSection> sections) {
    final children =
        sections.where((item) => item.parentId == section.id).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _sectionTile(section, root: true),
            if (children.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 8),
                child: Column(
                  children:
                      children.map((child) => _sectionTile(child)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTile(ContentSection section, {bool root = false}) {
    final selected = section.id == _selectedId;
    return ListTile(
      selected: selected,
      selectedTileColor: AppTheme.primaryColor.withAlpha(12),
      leading: Icon(root ? Icons.folder_special : _typeIcon(section.type),
          color:
              section.system ? AppTheme.primaryColor : AppTheme.textSecondary),
      title: Text(section.title,
          style:
              TextStyle(fontWeight: root ? FontWeight.bold : FontWeight.w600)),
      subtitle: Text(
          '${section.slug} · ${_typeLabel(section.type)} · orden ${section.order}'),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'Editar',
            onPressed: () => _showSectionEditor(section: section),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Gestionar contenido',
            onPressed: () =>
                context.go('/admin/contenido?section=${section.id}'),
            icon: const Icon(Icons.open_in_new),
          ),
          if (!section.system)
            IconButton(
              tooltip: 'Eliminar',
              onPressed: () async {
                try {
                  await _content.deleteSection(section);
                } catch (error) {
                  _showError(error);
                }
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      onTap: () => setState(() => _selectedId = section.id),
    );
  }

  Widget _buildSectionContent(ContentSection section) {
    final title = Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text('Contenido de ${section.title}',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          FilledButton.icon(
            onPressed: () => _showContentEditor(section),
            icon: const Icon(Icons.add),
            label: Text(_newLabel(section.type)),
          ),
        ],
      ),
    );
    switch (section.type) {
      case ContentSectionType.articulos:
        return StreamBuilder<List<ContentArticle>>(
          stream: _content.watchArticles(section.id, admin: true),
          builder: (context, snapshot) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (snapshot.hasError)
                _ErrorCard(
                    error: snapshot.error!, onRetry: () => setState(() {})),
              ...((snapshot.data ?? [])
                  .map((item) => _articleTile(section, item))),
            ],
          ),
        );
      case ContentSectionType.fichas:
        return StreamBuilder<List<PatrimonioFicha>>(
          stream: _content.watchPatrimonio(section.id, admin: true),
          builder: (context, snapshot) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (snapshot.hasError)
                _ErrorCard(
                    error: snapshot.error!, onRetry: () => setState(() {})),
              ...((snapshot.data ?? [])
                  .map((item) => _patrimonioTile(section, item))),
            ],
          ),
        );
      case ContentSectionType.junta:
        return StreamBuilder<List<JuntaMiembro>>(
          stream: _content.watchJunta(section.id, admin: true),
          builder: (context, snapshot) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (snapshot.hasError)
                _ErrorCard(
                    error: snapshot.error!, onRetry: () => setState(() {})),
              ...((snapshot.data ?? [])
                  .map((item) => _juntaTile(section, item))),
            ],
          ),
        );
      case ContentSectionType.grupos:
        return StreamBuilder<List<ContentGroup>>(
          stream: _content.watchGroups(section.id, admin: true),
          builder: (context, snapshot) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (snapshot.hasError)
                _ErrorCard(
                    error: snapshot.error!, onRetry: () => setState(() {})),
              ...((snapshot.data ?? [])
                  .map((item) => _groupTile(section, item))),
            ],
          ),
        );
    }
  }

  Widget _articleTile(ContentSection section, ContentArticle item) {
    return _ContentTile(
      title: item.title,
      subtitle: '${item.status} · orden ${item.order}',
      published: item.published,
      onEdit: () => _showContentEditor(section, item: item),
      onDelete: () => _delete(() => _content.deleteArticle(item.id)),
      onMove: (delta) =>
          _reorder('content_articles', item.id, item.order + delta),
    );
  }

  Widget _patrimonioTile(ContentSection section, PatrimonioFicha item) {
    return _ContentTile(
      title: item.name,
      subtitle: '${item.period} · orden ${item.order}',
      published: item.published,
      onEdit: () => _showContentEditor(section, item: item),
      onDelete: () => _delete(() => _content.deletePatrimonio(item.id)),
      onMove: (delta) =>
          _reorder('patrimonio_fichas', item.id, item.order + delta),
    );
  }

  Widget _juntaTile(ContentSection section, JuntaMiembro item) {
    return _ContentTile(
      title: item.name,
      subtitle: '${item.position} · orden ${item.order}',
      published: item.active,
      onEdit: () => _showContentEditor(section, item: item),
      onDelete: () => _delete(() => _content.deleteJunta(item.id)),
      onMove: (delta) =>
          _reorder('junta_miembros', item.id, item.order + delta),
    );
  }

  Widget _groupTile(ContentSection section, ContentGroup item) {
    return _ContentTile(
      title: item.name,
      subtitle: '${item.slug} · orden ${item.order}',
      published: item.published,
      onEdit: () => _showContentEditor(section, item: item),
      onDelete: () => _delete(() => _content.deleteGroup(item.id)),
      onMove: (delta) => _reorder('grupos', item.id, item.order + delta),
    );
  }

  Future<void> _reorder(String collection, String id, int order) async {
    try {
      await FirebaseFirestore.instance.collection(collection).doc(id).update({
        'orden': order < 0 ? 0 : order,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showContentEditor(ContentSection section,
      {Object? item}) async {
    switch (section.type) {
      case ContentSectionType.articulos:
        await _showArticleEditor(section, item as ContentArticle?);
      case ContentSectionType.fichas:
        await _showPatrimonioEditor(section, item as PatrimonioFicha?);
      case ContentSectionType.junta:
        await _showJuntaEditor(section, item as JuntaMiembro?);
      case ContentSectionType.grupos:
        await _showGroupEditor(section, item as ContentGroup?);
    }
  }

  Future<Map<String, String>?> _upload(String path, {required bool pdf}) async {
    final result = await FilePicker.platform.pickFiles(
      type: pdf ? FileType.custom : FileType.image,
      allowedExtensions: pdf ? ['pdf'] : ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.bytes == null) {
      return null;
    }
    final file = result.files.first;
    return _storage.uploadFile(
      path: path,
      bytes: file.bytes!,
      fileName: file.name,
      contentType: pdf ? 'application/pdf' : null,
      allowedExtensions: pdf ? {'pdf'} : {'jpg', 'jpeg', 'png', 'webp'},
      maxSizeBytes: pdf ? 20 * 1024 * 1024 : 8 * 1024 * 1024,
    );
  }

  Future<void> _showArticleEditor(
      ContentSection section, ContentArticle? article) async {
    final title = TextEditingController(text: article?.title ?? '');
    final subtitle = TextEditingController(text: article?.subtitle ?? '');
    final slug = TextEditingController(text: article?.slug ?? '');
    var blocks = List<ContentBlock>.from(article?.content ?? const []);
    var photos = List<Map<String, String>>.from(article?.photos ?? const []);
    var documents =
        List<Map<String, String>>.from(article?.documents ?? const []);
    var status = article?.status ?? 'draft';
    final order = TextEditingController(text: '${article?.order ?? 0}');
    final chronology = TextEditingController(
      text: (article?.chronology ?? const [])
          .map((entry) =>
              '${entry['date'] ?? entry['year'] ?? ''} | ${entry['title'] ?? ''} | ${entry['text'] ?? ''}')
          .join('\n'),
    );
    final ownerId =
        article?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
    await showAppDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => _editorDialog(
          context,
          title: article == null ? 'Nuevo artículo' : 'Editar artículo',
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Título *')),
                TextField(
                    controller: subtitle,
                    decoration: const InputDecoration(labelText: 'Subtítulo')),
                TextField(
                    controller: slug,
                    decoration: const InputDecoration(labelText: 'Slug')),
                TextField(
                    controller: order,
                    decoration: const InputDecoration(labelText: 'Orden')),
                TextField(
                  controller: chronology,
                  decoration: const InputDecoration(
                    labelText: 'Cronología',
                    hintText: 'fecha | título | texto (una por línea)',
                  ),
                  maxLines: 4,
                ),
                DropdownButtonFormField<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Borrador')),
                    DropdownMenuItem(
                        value: 'published', child: Text('Publicado')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
                const SizedBox(height: 12),
                ContentBlockEditor(
                  blocks: blocks,
                  onChanged: (value) => setDialogState(() => blocks = value),
                  onUploadImage: () async {
                    final uploaded = await _upload(
                        'content/${section.id}/articles/$ownerId/images',
                        pdf: false);
                    return uploaded?['url'];
                  },
                ),
                _assetList(
                  context,
                  title: 'Fotografías',
                  assets: photos,
                  onAdd: () async {
                    final uploaded = await _upload(
                        'content/${section.id}/articles/$ownerId/images',
                        pdf: false);
                    if (uploaded != null) {
                      setDialogState(() => photos = [...photos, uploaded]);
                    }
                  },
                  onRemove: (asset) async {
                    await _storage.deleteFile(asset['url'] ?? '');
                    setDialogState(() => photos =
                        photos.where((item) => item != asset).toList());
                  },
                ),
                _assetList(
                  context,
                  title: 'Documentos PDF',
                  assets: documents,
                  onAdd: () async {
                    final uploaded = await _upload(
                        'content/${section.id}/articles/$ownerId/documents',
                        pdf: true);
                    if (uploaded != null) {
                      setDialogState(
                          () => documents = [...documents, uploaded]);
                    }
                  },
                  onRemove: (asset) async {
                    await _storage.deleteFile(asset['url'] ?? '');
                    setDialogState(() => documents =
                        documents.where((item) => item != asset).toList());
                  },
                ),
              ],
            ),
          ),
          onSave: () async {
            if (title.text.trim().isEmpty) return;
            final now = DateTime.now();
            await _content.saveArticle(article?.id, {
              'section_id': section.id,
              'slug': slug.text.trim().isEmpty
                  ? _slug(title.text)
                  : slug.text.trim(),
              'title': title.text.trim(),
              'subtitle': subtitle.text.trim(),
              'content': '',
              'rich_content': blocks.map((block) => block.toMap()).toList(),
              'gallery': photos,
              'attachments': documents,
              'timeline_entries': _parseTimeline(chronology.text),
              'order': int.tryParse(order.text) ?? 0,
              'status': status,
              'published_at':
                  status == 'published' ? Timestamp.fromDate(now) : null,
            });
          },
        ),
      ),
    );
  }

  Future<void> _showPatrimonioEditor(
      ContentSection section, PatrimonioFicha? item) async {
    final name = TextEditingController(text: item?.name ?? '');
    final slug = TextEditingController(text: item?.slug ?? '');
    final author = TextEditingController(text: item?.author ?? '');
    final period = TextEditingController(text: item?.period ?? '');
    final materials = TextEditingController(text: item?.materials ?? '');
    final measurements = TextEditingController(text: item?.measurements ?? '');
    final order = TextEditingController(text: '${item?.order ?? 0}');
    final restorations = TextEditingController(
      text: (item?.restorations ?? const [])
          .map((entry) =>
              '${entry['date'] ?? ''} | ${entry['description'] ?? ''} | ${entry['author'] ?? ''}')
          .join('\n'),
    );
    var blocks = List<ContentBlock>.from(item?.description ?? const []);
    var photos = List<Map<String, String>>.from(item?.photos ?? const []);
    var documents = List<Map<String, String>>.from(item?.documents ?? const []);
    var published = item?.published ?? true;
    var featured = item?.featured ?? false;
    final ownerId = item?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
    await showAppDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => _editorDialog(
          context,
          title: item == null ? 'Nueva ficha patrimonial' : 'Editar ficha',
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(
                        labelText: 'Nombre / denominación *')),
                TextField(
                    controller: slug,
                    decoration: const InputDecoration(labelText: 'Slug')),
                TextField(
                    controller: author,
                    decoration: const InputDecoration(labelText: 'Autor')),
                TextField(
                    controller: period,
                    decoration:
                        const InputDecoration(labelText: 'Fecha o época')),
                TextField(
                    controller: materials,
                    decoration: const InputDecoration(labelText: 'Materiales')),
                TextField(
                    controller: measurements,
                    decoration: const InputDecoration(labelText: 'Medidas')),
                TextField(
                    controller: order,
                    decoration: const InputDecoration(labelText: 'Orden')),
                TextField(
                  controller: restorations,
                  decoration: const InputDecoration(
                    labelText: 'Restauraciones',
                    hintText:
                        'fecha | descripción | autor/taller (una por línea)',
                  ),
                  maxLines: 4,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publicada'),
                  value: published,
                  onChanged: (value) => setDialogState(() => published = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Destacada'),
                  value: featured,
                  onChanged: (value) => setDialogState(() => featured = value),
                ),
                ContentBlockEditor(
                  blocks: blocks,
                  onChanged: (value) => setDialogState(() => blocks = value),
                  onUploadImage: () async {
                    final uploaded =
                        await _upload('patrimonio/$ownerId/images', pdf: false);
                    return uploaded?['url'];
                  },
                ),
                _assetList(context, title: 'Fotografías', assets: photos,
                    onAdd: () async {
                  final uploaded =
                      await _upload('patrimonio/$ownerId/images', pdf: false);
                  if (uploaded != null) {
                    setDialogState(() => photos = [...photos, uploaded]);
                  }
                }, onRemove: (asset) async {
                  await _storage.deleteFile(asset['url'] ?? '');
                  setDialogState(() =>
                      photos = photos.where((item) => item != asset).toList());
                }),
                _assetList(context,
                    title: 'Documentación PDF',
                    assets: documents, onAdd: () async {
                  final uploaded =
                      await _upload('patrimonio/$ownerId/documents', pdf: true);
                  if (uploaded != null) {
                    setDialogState(() => documents = [...documents, uploaded]);
                  }
                }, onRemove: (asset) async {
                  await _storage.deleteFile(asset['url'] ?? '');
                  setDialogState(() => documents =
                      documents.where((item) => item != asset).toList());
                }),
              ],
            ),
          ),
          onSave: () async {
            if (name.text.trim().isEmpty) return;
            final now = DateTime.now();
            await _content.savePatrimonio(item?.id, {
              'section_id': section.id,
              'slug': slug.text.trim().isEmpty
                  ? _slug(name.text)
                  : slug.text.trim(),
              'name': name.text.trim(),
              'author': author.text.trim(),
              'date_or_period': period.text.trim(),
              'materials': materials.text.trim(),
              'measurements': measurements.text.trim(),
              'description': '',
              'rich_description': blocks.map((block) => block.toMap()).toList(),
              'restorations': _parseRestorations(restorations.text),
              'photos': photos,
              'related_documents': documents,
              'order': int.tryParse(order.text) ?? 0,
              'featured': featured,
              'published': published,
              'created_at': Timestamp.fromDate(item?.createdAt ?? now),
            });
          },
        ),
      ),
    );
  }

  Future<void> _showJuntaEditor(
      ContentSection section, JuntaMiembro? item) async {
    final position = TextEditingController(text: item?.position ?? '');
    final name = TextEditingController(text: item?.name ?? '');
    final description = TextEditingController(text: item?.description ?? '');
    final group = TextEditingController(text: item?.group ?? '');
    final order = TextEditingController(text: '${item?.order ?? 0}');
    var active = item?.active ?? true;
    String? photoUrl = item?.photoUrl;
    final ownerId = item?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
    await showAppDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => _editorDialog(
          context,
          title: item == null ? 'Nuevo miembro' : 'Editar miembro',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: position,
                  decoration: const InputDecoration(labelText: 'Cargo *')),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nombre *')),
              TextField(
                  controller: group,
                  decoration: const InputDecoration(labelText: 'Agrupación')),
              TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 3),
              TextField(
                  controller: order,
                  decoration: const InputDecoration(labelText: 'Orden')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activo'),
                value: active,
                onChanged: (value) => setDialogState(() => active = value),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final uploaded =
                      await _upload('junta/$ownerId/images', pdf: false);
                  if (uploaded != null) {
                    setDialogState(() => photoUrl = uploaded['url']);
                  }
                },
                icon: const Icon(Icons.upload),
                label: Text(photoUrl == null
                    ? 'Subir fotografía'
                    : 'Reemplazar fotografía'),
              ),
            ],
          ),
          onSave: () async {
            if (name.text.trim().isEmpty || position.text.trim().isEmpty)
              return;
            final now = DateTime.now();
            await _content.saveJunta(item?.id, {
              'section_id': section.id,
              'position': position.text.trim(),
              'name': name.text.trim(),
              'photo_url': photoUrl,
              'description': description.text.trim(),
              'order': int.tryParse(order.text) ?? 0,
              'active': active,
              'group': group.text.trim().isEmpty ? null : group.text.trim(),
              'created_at': Timestamp.fromDate(item?.createdAt ?? now),
            });
          },
        ),
      ),
    );
  }

  Future<void> _showGroupEditor(
      ContentSection section, ContentGroup? item) async {
    final name = TextEditingController(text: item?.name ?? '');
    final slug = TextEditingController(text: item?.slug ?? '');
    final shortDescription =
        TextEditingController(text: item?.shortDescription ?? '');
    final responsible = TextEditingController(text: item?.responsible ?? '');
    final order = TextEditingController(text: '${item?.order ?? 0}');
    var blocks = List<ContentBlock>.from(item?.content ?? const []);
    var photos = List<Map<String, String>>.from(item?.photos ?? const []);
    var published = item?.published ?? true;
    final ownerId = item?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
    await showAppDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => _editorDialog(
          context,
          title: item == null ? 'Nuevo grupo' : 'Editar grupo',
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre *')),
                TextField(
                    controller: slug,
                    decoration: const InputDecoration(labelText: 'Slug')),
                TextField(
                    controller: shortDescription,
                    decoration:
                        const InputDecoration(labelText: 'Descripción corta'),
                    maxLines: 2),
                TextField(
                    controller: responsible,
                    decoration:
                        const InputDecoration(labelText: 'Responsable')),
                TextField(
                    controller: order,
                    decoration: const InputDecoration(labelText: 'Orden')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publicado'),
                  value: published,
                  onChanged: (value) => setDialogState(() => published = value),
                ),
                ContentBlockEditor(
                  blocks: blocks,
                  onChanged: (value) => setDialogState(() => blocks = value),
                  onUploadImage: () async {
                    final uploaded =
                        await _upload('grupos/$ownerId/images', pdf: false);
                    return uploaded?['url'];
                  },
                ),
                _assetList(context, title: 'Fotografías', assets: photos,
                    onAdd: () async {
                  final uploaded =
                      await _upload('grupos/$ownerId/images', pdf: false);
                  if (uploaded != null) {
                    setDialogState(() => photos = [...photos, uploaded]);
                  }
                }, onRemove: (asset) async {
                  await _storage.deleteFile(asset['url'] ?? '');
                  setDialogState(() =>
                      photos = photos.where((item) => item != asset).toList());
                }),
              ],
            ),
          ),
          onSave: () async {
            if (name.text.trim().isEmpty) return;
            final now = DateTime.now();
            await _content.saveGroup(item?.id, {
              'section_id': section.id,
              'name': name.text.trim(),
              'slug': slug.text.trim().isEmpty
                  ? _slug(name.text)
                  : slug.text.trim(),
              'short_description': shortDescription.text.trim(),
              'responsible': responsible.text.trim().isEmpty
                  ? null
                  : responsible.text.trim(),
              'photos': photos,
              'content': '',
              'rich_content': blocks.map((block) => block.toMap()).toList(),
              'order': int.tryParse(order.text) ?? 0,
              'published': published,
              'created_at': Timestamp.fromDate(item?.createdAt ?? now),
            });
          },
        ),
      ),
    );
  }

  Widget _editorDialog(
    BuildContext context, {
    required String title,
    required Widget content,
    required Future<void> Function() onSave,
  }) {
    return AlertDialog(
      title: Text(title),
      content: ResponsiveDialogBox(width: 760, child: content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await onSave();
              if (context.mounted) Navigator.pop(context);
            } catch (error) {
              _showError(error);
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _assetList(
    BuildContext context, {
    required String title,
    required List<Map<String, String>> assets,
    required Future<void> Function() onAdd,
    required Future<void> Function(Map<String, String>) onRemove,
  }) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(
                  tooltip: 'Subir archivo',
                  onPressed: onAdd,
                  icon: const Icon(Icons.upload_file),
                ),
              ],
            ),
            ...assets.map((asset) => ListTile(
                  dense: true,
                  leading: Icon((asset['tipo'] ?? '').contains('pdf')
                      ? Icons.picture_as_pdf
                      : Icons.image),
                  title: Text(asset['nombre'] ?? asset['url'] ?? ''),
                  subtitle: Text('${asset['tamano_bytes'] ?? ''} bytes'),
                  trailing: IconButton(
                    tooltip: 'Eliminar archivo',
                    onPressed: () => onRemove(asset),
                    icon: const Icon(Icons.delete_outline),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _slug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-|-\$'), '');

  List<Map<String, dynamic>> _parseTimeline(String value) {
    return value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
      final parts = line.split('|').map((part) => part.trim()).toList();
      return {
        'date_or_year': parts.isNotEmpty ? parts[0] : '',
        'title': parts.length > 1 ? parts[1] : '',
        'text': parts.length > 2 ? parts[2] : '',
        'order': 0,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _parseRestorations(String value) {
    return value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
      final parts = line.split('|').map((part) => part.trim()).toList();
      return {
        'date': parts.isNotEmpty ? parts[0] : '',
        'description': parts.length > 1 ? parts[1] : '',
        'author_or_workshop': parts.length > 2 ? parts[2] : '',
      };
    }).toList();
  }

  String _newLabel(ContentSectionType type) {
    switch (type) {
      case ContentSectionType.articulos:
        return 'Nuevo artículo';
      case ContentSectionType.fichas:
        return 'Nueva ficha';
      case ContentSectionType.junta:
        return 'Nuevo miembro';
      case ContentSectionType.grupos:
        return 'Nuevo grupo';
    }
  }

  String _typeLabel(ContentSectionType type) {
    switch (type) {
      case ContentSectionType.articulos:
        return 'Artículos';
      case ContentSectionType.fichas:
        return 'Fichas';
      case ContentSectionType.junta:
        return 'Junta';
      case ContentSectionType.grupos:
        return 'Grupos';
    }
  }

  IconData _typeIcon(ContentSectionType type) {
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
}

class _ContentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool published;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<int> onMove;

  const _ContentTile({
    required this.title,
    required this.subtitle,
    required this.published,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(published ? Icons.visibility : Icons.visibility_off,
            color: published ? AppTheme.accentColor : AppTheme.textSecondary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'Subir',
              onPressed: () => onMove(-1),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: 'Bajar',
              onPressed: () => onMove(1),
              icon: const Icon(Icons.arrow_downward),
            ),
            IconButton(
              tooltip: 'Editar',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Eliminar',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final failure = error;
    final code = failure is FirebaseException ? failure.code : 'content-error';
    debugPrint('Content admin error [$code]: $failure');
    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: Text('Error [$code]'),
        subtitle: Text('$error'),
        trailing: IconButton(
          tooltip: 'Reintentar',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
