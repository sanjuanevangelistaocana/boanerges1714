import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/widgets/responsive_dialog.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/content_block.dart';
import 'package:boanerges1714/models/content_models.dart';
import 'package:boanerges1714/services/content_service.dart';
import 'package:boanerges1714/widgets/content_block_editor.dart';
import 'package:boanerges1714/widgets/app_surface_card.dart';

class SiteContentAdminScreen extends StatefulWidget {
  const SiteContentAdminScreen({super.key});

  @override
  State<SiteContentAdminScreen> createState() => _SiteContentAdminScreenState();
}

class _SiteContentAdminScreenState extends State<SiteContentAdminScreen> {
  late final ContentService _content;
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    _content = context.read<ContentService>();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await _content.ensureLegalPages();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    final failure = error;
    final code = failure is FirebaseException ? failure.code : 'content-error';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error [$code]: $error')),
    );
  }

  Future<void> _seedPatrimonio() async {
    setState(() => _seeding = true);
    try {
      await _content.seedPatrimonioCatalog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Catálogo patrimonial preparado sin duplicados.'),
        ));
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contenido del sitio',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                  'Enlaces, páginas legales y celebraciones administrables.'),
              const SizedBox(height: 24),
              _buildLinks(),
              const SizedBox(height: 24),
              _buildLegalPages(),
              const SizedBox(height: 24),
              _buildCelebrations(),
              const SizedBox(height: 24),
              AppSurfaceCard(
                admin: true,
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.museum_outlined,
                      color: AppTheme.primaryColor),
                  title: const Text('Catálogo de Patrimonio Artístico'),
                  subtitle: const Text(
                      'Prepara las piezas iniciales para completar sus fichas.'),
                  trailing: FilledButton.icon(
                    onPressed: _seeding ? null : _seedPatrimonio,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(_seeding ? 'Preparando...' : 'Preparar'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinks() {
    return _AdminSection(
      title: 'Enlaces de interés',
      icon: Icons.link,
      action: FilledButton.icon(
        onPressed: () => _editLink(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo enlace'),
      ),
      child: StreamBuilder<List<InterestLink>>(
        stream: _content.watchInterestLinks(admin: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _error(snapshot.error!);
          final links = snapshot.data ?? [];
          if (links.isEmpty) return const Text('No hay enlaces todavía.');
          return Column(
            children: links
                .map((link) => _LinkTile(
                      link: link,
                      onEdit: () => _editLink(link),
                      onDelete: () => _deleteLink(link.id),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildLegalPages() {
    return _AdminSection(
      title: 'Páginas legales',
      icon: Icons.gavel_outlined,
      child: StreamBuilder<List<LegalPage>>(
        stream: _content.watchLegalPages(admin: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _error(snapshot.error!);
          final pages = snapshot.data ?? [];
          return Column(
            children: pages
                .map((page) => ListTile(
                      leading: Icon(
                        page.published
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: page.published
                            ? AppTheme.accentColor
                            : AppTheme.textSecondary,
                      ),
                      title: Text(page.title),
                      subtitle: Text(page.updatedContentAt == null
                          ? 'Pendiente de revisión legal'
                          : 'Última actualización: ${_dateLabel(page.updatedContentAt!)}'),
                      trailing: IconButton(
                        tooltip: 'Editar',
                        onPressed: () => _editLegal(page),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildCelebrations() {
    return _AdminSection(
      title: 'Calendario litúrgico ampliable',
      icon: Icons.calendar_month_outlined,
      action: FilledButton.icon(
        onPressed: () => _editCelebration(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva celebración'),
      ),
      child: StreamBuilder<List<ManagedCelebration>>(
        stream: _content.watchCelebrations(admin: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _error(snapshot.error!);
          final celebrations = snapshot.data ?? [];
          if (celebrations.isEmpty) {
            return const Text('No hay celebraciones administradas todavía.');
          }
          return Column(
            children: celebrations
                .map((item) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _typeColor(item.type),
                        child: const Icon(Icons.event, color: Colors.white),
                      ),
                      title: Text(item.title),
                      subtitle: Text(
                          '${item.type} · ${item.annual ? 'Cada año, ${item.day}/${item.month}' : _dateLabel(item.date)}'),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: () => _editCelebration(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () => _deleteCelebration(item.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _error(Object error) {
    final failure = error;
    final code = failure is FirebaseException ? failure.code : 'content-error';
    return Text('Error [$code]: $error');
  }

  Future<void> _editLink([InterestLink? link]) async {
    final title = TextEditingController(text: link?.title ?? '');
    final url = TextEditingController(text: link?.url ?? '');
    final description = TextEditingController(text: link?.description ?? '');
    final icon = TextEditingController(text: link?.icon ?? '');
    final image = TextEditingController(text: link?.imageUrl ?? '');
    final order = TextEditingController(text: '${link?.order ?? 0}');
    var active = link?.active ?? true;
    await _dialog(
      title: link == null ? 'Nuevo enlace' : 'Editar enlace',
      content: [
        TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Título *')),
        TextField(
            controller: url,
            decoration: const InputDecoration(labelText: 'URL https:// *')),
        TextField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Descripción')),
        TextField(
            controller: icon,
            decoration:
                const InputDecoration(labelText: 'Icono Material opcional')),
        TextField(
            controller: image,
            decoration:
                const InputDecoration(labelText: 'URL de imagen opcional')),
        TextField(
            controller: order,
            decoration: const InputDecoration(labelText: 'Orden'),
            keyboardType: TextInputType.number),
        StatefulBuilder(
          builder: (context, setState) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activo'),
            value: active,
            onChanged: (value) => setState(() => active = value),
          ),
        ),
      ],
      onSave: () async {
        final parsed = Uri.tryParse(url.text.trim());
        if (title.text.trim().isEmpty ||
            parsed == null ||
            !parsed.hasScheme ||
            !{'http', 'https'}.contains(parsed.scheme)) {
          throw const FormatException('Introduce una URL HTTP o HTTPS válida.');
        }
        await _content.saveInterestLink(link?.id, {
          'title': title.text.trim(),
          'url': url.text.trim(),
          'description': description.text.trim(),
          'icon': icon.text.trim().isEmpty ? null : icon.text.trim(),
          'image_url': image.text.trim().isEmpty ? null : image.text.trim(),
          'active': active,
          'order': int.tryParse(order.text) ?? 0,
        });
      },
    );
  }

  Future<void> _editLegal(LegalPage page) async {
    var blocks = List<ContentBlock>.from(page.content);
    var published = page.published;
    await _dialog(
      title: 'Editar ${page.title}',
      content: [
        StatefulBuilder(
          builder: (context, setState) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Publicada'),
            subtitle: const Text(
                'Publica sólo cuando la Junta haya revisado el texto.'),
            value: published,
            onChanged: (value) => setState(() => published = value),
          ),
        ),
        ContentBlockEditor(
          blocks: blocks,
          onChanged: (value) => blocks = value,
          onUploadImage: () async => null,
        ),
      ],
      onSave: () => _content.saveLegalPage(page.id, {
        'title': page.title,
        'rich_content': blocks.map((block) => block.toMap()).toList(),
        'published': published,
        'content_updated_at': Timestamp.fromDate(DateTime.now()),
      }),
    );
  }

  Future<void> _editCelebration([ManagedCelebration? item]) async {
    final title = TextEditingController(text: item?.title ?? '');
    final type = TextEditingController(text: item?.type ?? 'Cofradía');
    final description = TextEditingController(text: item?.description ?? '');
    final date = TextEditingController(
        text: item?.date == null ? '' : _dateLabel(item!.date));
    final month = TextEditingController(text: '${item?.month ?? ''}');
    final day = TextEditingController(text: '${item?.day ?? ''}');
    var annual = item?.annual ?? false;
    var published = item?.published ?? true;
    await _dialog(
      title: item == null ? 'Nueva celebración' : 'Editar celebración',
      content: [
        TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Título *')),
        TextField(
            controller: type,
            decoration: const InputDecoration(labelText: 'Tipo/procedencia')),
        TextField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Descripción')),
        StatefulBuilder(
          builder: (context, setState) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recurrente anual'),
            value: annual,
            onChanged: (value) => setState(() => annual = value),
          ),
        ),
        if (annual) ...[
          TextField(
              controller: day,
              decoration: const InputDecoration(labelText: 'Día'),
              keyboardType: TextInputType.number),
          TextField(
              controller: month,
              decoration: const InputDecoration(labelText: 'Mes'),
              keyboardType: TextInputType.number),
        ] else
          TextField(
              controller: date,
              decoration:
                  const InputDecoration(labelText: 'Fecha (AAAA-MM-DD)')),
        StatefulBuilder(
          builder: (context, setState) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Publicada'),
            value: published,
            onChanged: (value) => setState(() => published = value),
          ),
        ),
      ],
      onSave: () async {
        if (title.text.trim().isEmpty)
          throw const FormatException('El título es obligatorio.');
        final data = <String, dynamic>{
          'title': title.text.trim(),
          'type': type.text.trim().isEmpty ? 'Cofradía' : type.text.trim(),
          'description': description.text.trim(),
          'annual': annual,
          'published': published,
        };
        if (annual) {
          final parsedDay = int.tryParse(day.text);
          final parsedMonth = int.tryParse(month.text);
          if (parsedDay == null ||
              parsedMonth == null ||
              parsedDay < 1 ||
              parsedDay > 31 ||
              parsedMonth < 1 ||
              parsedMonth > 12) {
            throw const FormatException('Día y mes no válidos.');
          }
          data['day'] = parsedDay;
          data['month'] = parsedMonth;
          data['date'] = null;
        } else {
          final parsed = DateTime.tryParse(date.text.trim());
          if (parsed == null) throw const FormatException('Fecha no válida.');
          data['date'] = Timestamp.fromDate(parsed);
          data['day'] = null;
          data['month'] = null;
        }
        await _content.saveCelebration(item?.id, data);
      },
    );
  }

  Future<void> _deleteLink(String id) async {
    try {
      await _content.deleteInterestLink(id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteCelebration(String id) async {
    try {
      await _content.deleteCelebration(id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _dialog({
    required String title,
    required List<Widget> content,
    required Future<void> Function() onSave,
  }) async {
    await showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: ResponsiveDialogBox(
          width: 720,
          child: SingleChildScrollView(child: Column(children: content)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              try {
                await onSave();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                _showError(error);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Iglesia Católica':
        return const Color(0xFF6A4C93);
      case 'Hermandades invitadas':
        return const Color(0xFF496A72);
      case 'Festividades especiales':
        return AppTheme.accentColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _AdminSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  const _AdminSection({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      admin: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge)),
              if (action != null) action!,
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final InterestLink link;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LinkTile({
    required this.link,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(link.active ? Icons.link : Icons.link_off,
          color: link.active ? AppTheme.accentColor : AppTheme.textSecondary),
      title: Text(link.title),
      subtitle: Text('${link.url} · orden ${link.order}'),
      trailing: Wrap(
        children: [
          IconButton(
              tooltip: 'Editar',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined)),
          IconButton(
              tooltip: 'Eliminar',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}
