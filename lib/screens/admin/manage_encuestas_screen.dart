import 'dart:convert';
import 'package:boanerges1714/widgets/responsive_dialog.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/encuesta.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/tag_config.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/encuesta_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/storage_service.dart';
import 'package:boanerges1714/widgets/responsive_data_table.dart';

class ManageEncuestasScreen extends StatelessWidget {
  const ManageEncuestasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final encuestaService = context.read<EncuestaService>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gestión de Encuestas',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      const Text(
                        'Crea encuestas avanzadas segmentadas por tags, anónimas, multi-respuesta y más.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const _EncuestasDashboardPage()),
                  ),
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Dashboard'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva encuesta'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Encuesta>>(
              stream: encuestaService.getAllEncuestas(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final encuestas = (snapshot.data ?? [])
                    .where((e) => e.estado != EncuestaEstado.eliminada)
                    .toList();
                if (encuestas.isEmpty) {
                  return _EmptyState(
                    message: 'No hay encuestas creadas todavía.',
                    action: () => _showEditor(context),
                  );
                }
                return Column(
                  children: encuestas
                      .map((e) => _AdminEncuestaCard(encuesta: e))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditor(BuildContext context, {Encuesta? encuesta}) {
    showDialog(
      context: context,
      builder: (_) => _EncuestaEditorDialog(encuesta: encuesta),
    );
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================

class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback action;
  const _EmptyState({required this.message, required this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.poll_outlined,
                  size: 54, color: AppTheme.textSecondary),
              const SizedBox(height: 12),
              Text(message,
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.add),
                label: const Text('Nueva encuesta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ADMIN SURVEY CARD
// =============================================================================

class _AdminEncuestaCard extends StatelessWidget {
  final Encuesta encuesta;
  const _AdminEncuestaCard({required this.encuesta});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EncuestaService>();
    final fmt = DateFormat('dd/MM/yyyy');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(
                          label: encuesta.estadoLabel, estado: encuesta.estado),
                      _Chip(
                        label: encuesta.tipoRespuestaLabel,
                        estado: EncuestaEstado.activa,
                      ),
                      if (encuesta.esAnonima)
                        const _Chip(
                          label: 'Anónima',
                          estado: EncuestaEstado.programada,
                        ),
                      if (!encuesta.targeting.allCofrades)
                        _Chip(
                          label: 'Tags: ${encuesta.targeting.tags.join(", ")}',
                          estado: EncuestaEstado.programada,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) =>
                      _handleAction(context, action, encuesta),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(
                        value: 'results', child: Text('Ver resultados')),
                    const PopupMenuItem(
                        value: 'export', child: Text('Exportar CSV')),
                    const PopupMenuItem(
                        value: 'audit', child: Text('Auditoría')),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(encuesta.titulo,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              encuesta.descripcion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text('${encuesta.totalRespuestas} respuestas',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                if (encuesta.fechaLimite != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.timer_outlined,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('Límite: ${fmt.format(encuesta.fechaLimite!)}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ],
                const SizedBox(width: 16),
                Text('Creada por ${encuesta.creadaPor}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<RespuestaEncuesta>>(
              stream: service.getRespuestas(encuesta.id),
              builder: (context, snap) {
                final responses = snap.data ?? [];
                return _MiniResultsBar(
                    encuesta: encuesta, responses: responses);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action, Encuesta encuesta) {
    final service = context.read<EncuestaService>();
    switch (action) {
      case 'edit':
        showDialog(
          context: context,
          builder: (_) => _EncuestaEditorDialog(encuesta: encuesta),
        );
        break;
      case 'results':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _ResultsPage(encuesta: encuesta)),
        );
        break;
      case 'export':
        _exportCsv(context, encuesta);
        break;
      case 'audit':
        _showAudit(context, encuesta);
        break;
      case 'delete':
        _confirmDelete(context, encuesta);
        break;
    }
  }

  Future<void> _exportCsv(BuildContext context, Encuesta encuesta) async {
    final service = context.read<EncuestaService>();
    final csv = await service.exportCsv(encuesta);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'encuesta_${encuesta.id}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV exportado correctamente.')),
      );
    }
  }

  void _showAudit(BuildContext context, Encuesta encuesta) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Historial de auditoría'),
        content: ResponsiveDialogBox(
          width: 500,
          child: encuesta.auditLog.isEmpty
              ? const Text('Sin registros de auditoría.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: encuesta.auditLog.reversed.map((entry) {
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(entry.action),
                        subtitle: Text(
                            '${entry.userName} — ${fmt.format(entry.timestamp)}'),
                      );
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Encuesta encuesta) {
    final service = context.read<EncuestaService>();
    final actor = context.read<AuthService>().cofrade;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar encuesta'),
        content: Text(
            '¿Seguro que quieres eliminar "${encuesta.titulo}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await service.deleteEncuesta(
                  encuesta.id,
                  deletedBy: actor?.id ?? 'admin',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Encuesta eliminada correctamente.')),
                  );
                }
              } catch (e) {
                debugPrint('[ManageEncuestas] delete error: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'No se pudo eliminar la encuesta. Revisa los permisos o vuelve a intentarlo.'),
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
// MINI RESULTS BAR (inline in admin card)
// =============================================================================

class _MiniResultsBar extends StatelessWidget {
  final Encuesta encuesta;
  final List<RespuestaEncuesta> responses;
  const _MiniResultsBar({required this.encuesta, required this.responses});

  @override
  Widget build(BuildContext context) {
    if (encuesta.tipoRespuesta == EncuestaTipoRespuesta.abierta) {
      return Text('${responses.length} respuestas de texto',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13));
    }
    final counts = <String, int>{};
    for (final r in responses) {
      if (encuesta.tipoRespuesta == EncuestaTipoRespuesta.multiple) {
        for (final id in r.selectedOptionIds) {
          counts[id] = (counts[id] ?? 0) + 1;
        }
      } else if (encuesta.tipoRespuesta == EncuestaTipoRespuesta.reaccion) {
        final key = r.reaccion ?? '';
        if (key.isNotEmpty) counts[key] = (counts[key] ?? 0) + 1;
      } else {
        final key = r.selectedOptionId ?? '';
        if (key.isNotEmpty) counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const Text('Sin respuestas aún',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13));
    }

    final items = encuesta.tipoRespuesta == EncuestaTipoRespuesta.reaccion
        ? encuesta.reactionEmojis.map((e) => MapEntry(e, e))
        : encuesta.opciones.map((o) => MapEntry(o.id, o.text));

    return Column(
      children: items.map((entry) {
        final count = counts[entry.key] ?? 0;
        final pct = total > 0 ? count / total : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(entry.value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.primaryColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$count (${(pct * 100).toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// =============================================================================
// STATUS CHIP
// =============================================================================

class _Chip extends StatelessWidget {
  final String label;
  final EncuestaEstado estado;
  const _Chip({required this.label, required this.estado});

  Color get _color {
    switch (estado) {
      case EncuestaEstado.activa:
        return Colors.green.shade700;
      case EncuestaEstado.borrador:
        return Colors.grey.shade600;
      case EncuestaEstado.programada:
        return Colors.blue.shade700;
      case EncuestaEstado.cerrada:
        return Colors.orange.shade700;
      case EncuestaEstado.archivada:
        return Colors.brown.shade400;
      case EncuestaEstado.eliminada:
        return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(
              color: _color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// =============================================================================
// EDITOR DIALOG
// =============================================================================

class _EncuestaEditorDialog extends StatefulWidget {
  final Encuesta? encuesta;
  const _EncuestaEditorDialog({this.encuesta});

  @override
  State<_EncuestaEditorDialog> createState() => _EncuestaEditorDialogState();
}

class _EncuestaEditorDialogState extends State<_EncuestaEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late DateTime? _deadline;
  late DateTime? _publishDate;
  late String _type;
  late EncuestaEstado _estado;
  late EncuestaTipoRespuesta _tipoRespuesta;
  late bool _esAnonima;
  late bool _mostrarResultados;
  late bool _publicacionInmediata;
  late bool _allCofrades;
  late List<String> _selectedTags;
  late List<EncuestaOpcion> _opciones;
  late List<String> _reactionEmojis;
  late List<Map<String, String>> _attachments;
  late final String _encuestaId;
  String? _coverUrl;
  String? _coverPath;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.encuesta;
    _encuestaId = e?.id ??
        FirebaseFirestore.instance.collection('convocatorias').doc().id;
    _title = TextEditingController(text: e?.titulo ?? '');
    _description = TextEditingController(text: e?.descripcion ?? '');
    _deadline = e?.fechaLimite ?? DateTime.now().add(const Duration(days: 7));
    _publishDate = e?.fechaPublicacion;
    _type = e?.tipo ?? 'opinion';
    _estado = e?.estado ?? EncuestaEstado.activa;
    _tipoRespuesta = e?.tipoRespuesta ?? EncuestaTipoRespuesta.unica;
    _esAnonima = e?.esAnonima ?? false;
    _mostrarResultados = e?.mostrarResultados ?? false;
    _publicacionInmediata = e?.publicacionInmediata ?? true;
    _allCofrades = e?.targeting.allCofrades ?? true;
    _selectedTags = List.from(e?.targeting.tags ?? []);
    _opciones = e?.opciones
            .map((o) => EncuestaOpcion(
                  id: o.id,
                  text: o.text,
                  order: o.order,
                  imageUrl: o.imageUrl,
                  imagePath: o.imagePath,
                ))
            .toList() ??
        [
          const EncuestaOpcion(id: 'option_1', text: 'Sí', order: 1),
          const EncuestaOpcion(id: 'option_2', text: 'No', order: 2),
        ];
    _reactionEmojis = List.from(e?.reactionEmojis ?? ['👍', '👎', '❤️']);
    _attachments = List.from(e?.adjuntos ?? []);
    _coverUrl = e?.coverImageUrl;
    _coverPath = e?.coverImagePath;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.encuesta == null ? 'Nueva encuesta' : 'Editar encuesta'),
      content: ResponsiveDialogBox(
        width: 780,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Basic data ---
                const _SectionTitle(title: 'Datos básicos'),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Título *'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Descripción *'),
                  maxLines: 3,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _type,
                        decoration:
                            const InputDecoration(labelText: 'Categoría'),
                        items: const [
                          DropdownMenuItem(
                              value: 'opinion', child: Text('Opinión')),
                          DropdownMenuItem(
                              value: 'preferencias',
                              child: Text('Preferencias')),
                          DropdownMenuItem(
                              value: 'valoracion', child: Text('Valoración')),
                          DropdownMenuItem(
                              value: 'consulta', child: Text('Consulta')),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? _type),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<EncuestaEstado>(
                        value: _estado,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: EncuestaEstado.values
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e.name[0].toUpperCase() +
                                      e.name.substring(1)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _estado = v ?? _estado),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),

                // --- Response type ---
                const _SectionTitle(title: 'Tipo de respuesta'),
                DropdownButtonFormField<EncuestaTipoRespuesta>(
                  value: _tipoRespuesta,
                  decoration:
                      const InputDecoration(labelText: 'Modo de respuesta'),
                  items: EncuestaTipoRespuesta.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(_tipoRespuestaLabel(t)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _tipoRespuesta = v ?? _tipoRespuesta),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Encuesta anónima'),
                  subtitle: const Text(
                      'Las respuestas no mostrarán la identidad del cofrade.'),
                  value: _esAnonima,
                  onChanged: (v) => setState(() => _esAnonima = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar resultados a cofrades'),
                  value: _mostrarResultados,
                  onChanged: (v) => setState(() => _mostrarResultados = v),
                ),
                const Divider(height: 28),

                // --- Options (for single/multi/reaction) ---
                if (_tipoRespuesta == EncuestaTipoRespuesta.unica ||
                    _tipoRespuesta == EncuestaTipoRespuesta.multiple ||
                    _tipoRespuesta == EncuestaTipoRespuesta.votacionImagen) ...[
                  _SectionTitle(
                    title:
                        _tipoRespuesta == EncuestaTipoRespuesta.votacionImagen
                            ? 'Opciones con imagen'
                            : 'Opciones de respuesta',
                  ),
                  _OptionsEditor(
                    opciones: _opciones,
                    showImageUpload:
                        _tipoRespuesta == EncuestaTipoRespuesta.votacionImagen,
                    encuestaId: _encuestaId,
                    onChanged: (opts) => setState(() => _opciones = opts),
                  ),
                  const Divider(height: 28),
                ],

                if (_tipoRespuesta == EncuestaTipoRespuesta.reaccion) ...[
                  const _SectionTitle(title: 'Emojis de reacción'),
                  Wrap(
                    spacing: 8,
                    children: _reactionEmojis
                        .map((emoji) => Chip(
                              label: Text(emoji,
                                  style: const TextStyle(fontSize: 20)),
                              onDeleted: () =>
                                  setState(() => _reactionEmojis.remove(emoji)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Añadir emoji',
                              hintText: 'Pega un emoji aquí'),
                          onFieldSubmitted: (v) {
                            if (v.trim().isNotEmpty) {
                              setState(() => _reactionEmojis.add(v.trim()));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                ],

                // --- Targeting ---
                const _SectionTitle(title: 'Destinatarios de la encuesta'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Todos los cofrades'),
                  subtitle: const Text('Desactiva para segmentar por tags.'),
                  value: _allCofrades,
                  onChanged: (v) => setState(() => _allCofrades = v),
                ),
                if (!_allCofrades) ...[
                  const SizedBox(height: 8),
                  const Text('Selecciona tags (combinación OR):',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  StreamBuilder<List<TagConfig>>(
                    stream: context.read<EncuestaService>().getAvailableTags(),
                    builder: (context, snap) {
                      final tags = snap.data ?? [];
                      if (tags.isEmpty) {
                        return const Text('No hay tags disponibles.',
                            style: TextStyle(color: AppTheme.textSecondary));
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags.map((tag) {
                          final selected = _selectedTags.contains(tag.nombre);
                          return FilterChip(
                            label: Text(tag.nombre),
                            selected: selected,
                            selectedColor: AppTheme.primaryColor.withAlpha(38),
                            onSelected: (sel) {
                              setState(() {
                                if (sel) {
                                  _selectedTags.add(tag.nombre);
                                } else {
                                  _selectedTags.remove(tag.nombre);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
                const Divider(height: 28),

                // --- Scheduling ---
                const _SectionTitle(title: 'Programación'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publicación inmediata'),
                  subtitle: const Text(
                      'Si se desactiva, se publicará en la fecha indicada.'),
                  value: _publicacionInmediata,
                  onChanged: (v) => setState(() => _publicacionInmediata = v),
                ),
                if (!_publicacionInmediata)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(_publishDate == null
                        ? 'Seleccionar fecha de publicación'
                        : 'Publicación: ${DateFormat('dd/MM/yyyy').format(_publishDate!)}'),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _publishDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (d != null) setState(() => _publishDate = d);
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(_deadline == null
                      ? 'Sin fecha límite'
                      : 'Fecha límite: ${DateFormat('dd/MM/yyyy').format(_deadline!)}'),
                  subtitle: const Text(
                      'Después de esta fecha se cierra automáticamente.'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _deadline ??
                          DateTime.now().add(const Duration(days: 7)),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d != null) setState(() => _deadline = d);
                  },
                ),
                const Divider(height: 28),

                // --- Cover & attachments ---
                const _SectionTitle(title: 'Portada y adjuntos'),
                if ((_coverUrl ?? '').isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(_coverUrl!,
                        height: 150, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _coverUrl = null;
                        _coverPath = null;
                      }),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Quitar portada'),
                    ),
                  ),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _uploadCover,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Subir portada'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _uploadAttachment,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Adjuntar PDF'),
                    ),
                  ],
                ),
                if (_uploading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                for (var i = 0; i < _attachments.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf,
                        color: AppTheme.primaryColor),
                    title: Text(_attachments[i]['nombre'] ?? 'PDF adjunto'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _attachments.removeAt(i)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(widget.encuesta == null ? 'Crear encuesta' : 'Guardar'),
        ),
      ],
    );
  }

  String _tipoRespuestaLabel(EncuestaTipoRespuesta t) {
    switch (t) {
      case EncuestaTipoRespuesta.unica:
        return 'Respuesta única';
      case EncuestaTipoRespuesta.multiple:
        return 'Respuesta múltiple';
      case EncuestaTipoRespuesta.abierta:
        return 'Pregunta abierta (texto libre)';
      case EncuestaTipoRespuesta.reaccion:
        return 'Reacción rápida (emojis)';
      case EncuestaTipoRespuesta.votacionImagen:
        return 'Votación por imagen';
    }
  }

  Future<void> _uploadCover() async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.first.bytes == null) return;
      final file = result.files.first;
      final uploaded = await context.read<StorageService>().uploadFile(
            path: 'surveys/$_encuestaId/cover',
            bytes: file.bytes!,
            fileName: file.name,
            allowedExtensions: {'jpg', 'jpeg', 'png', 'webp'},
            maxSizeBytes: 8 * 1024 * 1024,
          );
      setState(() {
        _coverUrl = uploaded['url'];
        _coverPath = uploaded['storage_path'];
      });
    } catch (e) {
      _showError('No se pudo subir la portada: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadAttachment() async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
      if (result == null || result.files.first.bytes == null) return;
      final file = result.files.first;
      final uploaded = await context.read<StorageService>().uploadFile(
            path: 'surveys/$_encuestaId/attachments',
            bytes: file.bytes!,
            fileName: file.name,
            allowedExtensions: {'pdf'},
            maxSizeBytes: 20 * 1024 * 1024 - 1,
          );
      setState(() => _attachments.add(uploaded));
    } catch (e) {
      _showError('No se pudo adjuntar el PDF: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoRespuesta == EncuestaTipoRespuesta.unica ||
        _tipoRespuesta == EncuestaTipoRespuesta.multiple ||
        _tipoRespuesta == EncuestaTipoRespuesta.votacionImagen) {
      final cleaned = _normalizedOpciones();
      if (cleaned.length < 2) {
        _showError('Añade al menos 2 opciones de respuesta.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final actor = context.read<AuthService>().cofrade;
      final estado = !_publicacionInmediata &&
              _publishDate != null &&
              _publishDate!.isAfter(DateTime.now())
          ? EncuestaEstado.programada
          : _estado;

      final auditEntries =
          List<EncuestaAuditEntry>.from(widget.encuesta?.auditLog ?? []);
      auditEntries.add(EncuestaAuditEntry(
        action: widget.encuesta == null ? 'created' : 'edited',
        userId: actor?.id ?? 'admin',
        userName: actor?.nombreCompleto ?? 'Admin',
        timestamp: DateTime.now(),
        details: widget.encuesta == null
            ? {'titulo': _title.text.trim()}
            : {'fields_changed': 'manual_edit'},
      ));

      final encuesta = Encuesta(
        id: _encuestaId,
        titulo: _title.text.trim(),
        descripcion: _description.text.trim(),
        tipo: _type,
        tipoRespuesta: _tipoRespuesta,
        estado: estado,
        esAnonima: _esAnonima,
        targeting: EncuestaTargeting(
          allCofrades: _allCofrades,
          tags: _selectedTags,
          combineMode: 'or',
        ),
        opciones: _normalizedOpciones(),
        reactionEmojis: _reactionEmojis,
        fechaCreacion: widget.encuesta?.fechaCreacion ?? DateTime.now(),
        fechaPublicacion: _publicacionInmediata ? null : _publishDate,
        fechaLimite: _deadline,
        publicacionInmediata: _publicacionInmediata,
        creadaPor:
            widget.encuesta?.creadaPor ?? actor?.nombreCompleto ?? 'Admin',
        creadaPorId: widget.encuesta?.creadaPorId ?? actor?.id ?? '',
        mostrarResultados: _mostrarResultados,
        totalRespuestas: widget.encuesta?.totalRespuestas ?? 0,
        adjuntos: _attachments,
        coverImageUrl: _coverUrl,
        coverImagePath: _coverPath,
        auditLog: auditEntries,
      );

      final service = context.read<EncuestaService>();
      if (widget.encuesta == null) {
        await service.createEncuesta(encuesta);
      } else {
        await service.updateEncuesta(encuesta.id, encuesta.toFirestore());
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.encuesta == null
                  ? 'Encuesta creada correctamente.'
                  : 'Encuesta actualizada.')),
        );
      }
    } catch (e) {
      _showError('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<EncuestaOpcion> _normalizedOpciones() => _opciones
      .asMap()
      .entries
      .map((entry) => EncuestaOpcion(
            id: entry.value.id.isEmpty
                ? 'option_${DateTime.now().millisecondsSinceEpoch}_${entry.key}'
                : entry.value.id,
            text: entry.value.text.trim(),
            order: entry.key + 1,
            imageUrl: entry.value.imageUrl,
            imagePath: entry.value.imagePath,
          ))
      .where((o) => o.text.isNotEmpty)
      .toList();

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
}

// =============================================================================
// SECTION TITLE
// =============================================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor)),
    );
  }
}

// =============================================================================
// OPTIONS EDITOR
// =============================================================================

class _OptionsEditor extends StatelessWidget {
  final List<EncuestaOpcion> opciones;
  final ValueChanged<List<EncuestaOpcion>> onChanged;
  final bool showImageUpload;
  final String encuestaId;
  const _OptionsEditor({
    required this.opciones,
    required this.onChanged,
    this.showImageUpload = false,
    this.encuestaId = '',
  });

  Future<void> _uploadOptionImage(BuildContext context, int index) async {
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.first.bytes == null) return;
      final file = result.files.first;
      final optId = opciones[index].id;
      final uploaded = await context.read<StorageService>().uploadFile(
            path: 'surveys/$encuestaId/options/$optId',
            bytes: file.bytes!,
            fileName: file.name,
            allowedExtensions: {'jpg', 'jpeg', 'png', 'webp'},
            maxSizeBytes: 8 * 1024 * 1024,
          );
      final copy = [...opciones];
      copy[index] = EncuestaOpcion(
        id: copy[index].id,
        text: copy[index].text,
        order: copy[index].order,
        imageUrl: uploaded['url'],
        imagePath: uploaded['storage_path'],
      );
      onChanged(copy);
    } catch (e) {
      debugPrint('[OptionsEditor] upload error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No se pudo subir la imagen. Comprueba el formato y vuelve a intentarlo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < opciones.length; i++)
          Card(
            key: ValueKey(opciones[i].id),
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Subir',
                        onPressed: i == 0
                            ? null
                            : () {
                                final copy = [...opciones];
                                final c = copy.removeAt(i);
                                copy.insert(i - 1, c);
                                onChanged(copy);
                              },
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: 'Bajar',
                        onPressed: i == opciones.length - 1
                            ? null
                            : () {
                                final copy = [...opciones];
                                final c = copy.removeAt(i);
                                copy.insert(i + 1, c);
                                onChanged(copy);
                              },
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('text_${opciones[i].id}'),
                          initialValue: opciones[i].text,
                          decoration:
                              InputDecoration(labelText: 'Opción ${i + 1}'),
                          onChanged: (value) {
                            final copy = [...opciones];
                            copy[i] = EncuestaOpcion(
                              id: opciones[i].id,
                              text: value,
                              order: i + 1,
                              imageUrl: opciones[i].imageUrl,
                              imagePath: opciones[i].imagePath,
                            );
                            onChanged(copy);
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        onPressed: opciones.length <= 2
                            ? null
                            : () {
                                final copy = [...opciones]..removeAt(i);
                                onChanged(copy);
                              },
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
                  if (showImageUpload) ...[
                    const SizedBox(height: 8),
                    if ((opciones[i].imageUrl ?? '').isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          opciones[i].imageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 80,
                            color: Colors.grey.shade200,
                            child:
                                const Center(child: Icon(Icons.broken_image)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _uploadOptionImage(context, i),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reemplazar'),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              final copy = [...opciones];
                              copy[i] = EncuestaOpcion(
                                id: copy[i].id,
                                text: copy[i].text,
                                order: copy[i].order,
                                imageUrl: null,
                                imagePath: null,
                              );
                              onChanged(copy);
                            },
                            icon: const Icon(Icons.close,
                                size: 16, color: Colors.red),
                            label: const Text('Quitar imagen',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ] else
                      OutlinedButton.icon(
                        onPressed: () => _uploadOptionImage(context, i),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Subir imagen'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => onChanged([
              ...opciones,
              EncuestaOpcion(
                id: 'option_${DateTime.now().millisecondsSinceEpoch}',
                text: '',
                order: opciones.length + 1,
              ),
            ]),
            icon: const Icon(Icons.add),
            label: const Text('Añadir opción'),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// RESULTS PAGE (full screen)
// =============================================================================

class _ResultsPage extends StatelessWidget {
  final Encuesta encuesta;
  const _ResultsPage({required this.encuesta});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EncuestaService>();
    final firestoreService = context.read<FirestoreService>();
    return Scaffold(
      appBar: AppBar(title: Text('Resultados: ${encuesta.titulo}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Participation stats
              StreamBuilder<List<Cofrade>>(
                stream: firestoreService.getCofrades(),
                builder: (context, cofSnap) {
                  final cofrades = (cofSnap.data ?? [])
                      .where((c) => c.isActivo && !c.esCuentaServicio)
                      .toList();
                  final targeted =
                      service.countTargetedCofrades(encuesta, cofrades);
                  final responded = encuesta.totalRespuestas;
                  final pending = targeted - responded;
                  final pct = targeted > 0
                      ? (responded / targeted * 100).toStringAsFixed(1)
                      : '0';
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(label: 'Destinatarios', value: '$targeted'),
                          _StatItem(label: 'Respuestas', value: '$responded'),
                          _StatItem(label: 'Pendientes', value: '$pending'),
                          _StatItem(label: 'Participación', value: '$pct%'),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Visual results
              if (encuesta.tipoRespuesta == EncuestaTipoRespuesta.abierta)
                _OpenTextResults(encuestaId: encuesta.id)
              else
                _VisualResults(encuesta: encuesta),

              const SizedBox(height: 24),

              // Non-anonymous: individual responses table
              if (!encuesta.esAnonima &&
                  encuesta.tipoRespuesta != EncuestaTipoRespuesta.abierta)
                _ResponsesTable(encuesta: encuesta),

              const SizedBox(height: 16),
              // Export buttons
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _export(context),
                    icon: const Icon(Icons.download),
                    label: const Text('Exportar CSV'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final service = context.read<EncuestaService>();
    final csv = await service.exportCsv(encuesta);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'encuesta_${encuesta.id}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

// Visual results with animated bars
class _VisualResults extends StatelessWidget {
  final Encuesta encuesta;
  const _VisualResults({required this.encuesta});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EncuestaService>();
    return FutureBuilder<Map<String, int>>(
      future: service.getResultCounts(encuesta.id),
      builder: (context, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        final counts = snap.data!;
        final total = counts.values.fold<int>(0, (a, b) => a + b);

        List<MapEntry<String, String>> items;
        if (encuesta.tipoRespuesta == EncuestaTipoRespuesta.reaccion) {
          items = encuesta.reactionEmojis.map((e) => MapEntry(e, e)).toList();
        } else {
          items = encuesta.opciones.map((o) => MapEntry(o.id, o.text)).toList();
        }

        // Find winner
        String? winnerId;
        int maxCount = 0;
        for (final entry in counts.entries) {
          if (entry.value > maxCount) {
            maxCount = entry.value;
            winnerId = entry.key;
          }
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resultados',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Total votos: $total',
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                ...items.map((entry) {
                  final count = counts[entry.key] ?? 0;
                  final pct = total > 0 ? count / total : 0.0;
                  final isWinner = entry.key == winnerId && total > 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontWeight: isWinner
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  fontSize: isWinner ? 16 : 14,
                                  color: isWinner
                                      ? AppTheme.primaryColor
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (isWinner)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('Ganadora',
                                    style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ),
                            const SizedBox(width: 8),
                            Text('$count (${(pct * 100).toStringAsFixed(1)}%)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isWinner
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: pct),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (_, val, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: val,
                              minHeight: 14,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation(
                                isWinner
                                    ? AppTheme.primaryColor
                                    : AppTheme.accentColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OpenTextResults extends StatelessWidget {
  final String encuestaId;
  const _OpenTextResults({required this.encuestaId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EncuestaService>();
    return FutureBuilder<List<String>>(
      future: service.getOpenTextResponses(encuestaId),
      builder: (context, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        final texts = snap.data!;
        if (texts.isEmpty) {
          return const Text('Sin respuestas de texto aún.');
        }
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${texts.length} respuestas de texto',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                ...texts.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(t),
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResponsesTable extends StatelessWidget {
  final Encuesta encuesta;
  const _ResponsesTable({required this.encuesta});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EncuestaService>();
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return StreamBuilder<List<RespuestaEncuesta>>(
      stream: service.getRespuestas(encuesta.id),
      builder: (context, snap) {
        final responses = snap.data ?? [];
        if (responses.isEmpty) return const SizedBox.shrink();
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detalle de respuestas',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ResponsiveDataTable(
                  columns: const [
                    ResponsiveTableColumn(label: 'Cofrade', mobilePriority: 0),
                    ResponsiveTableColumn(
                        label: 'Respuesta', mobilePriority: 1),
                    ResponsiveTableColumn(label: 'Fecha', mobilePriority: 2),
                  ],
                  rows: [
                    for (final r in responses)
                      ResponsiveTableRow(
                        cells: [
                          Text(r.cofradeNombre),
                          Text(
                            encuesta.tipoRespuesta ==
                                    EncuestaTipoRespuesta.multiple
                                ? r.selectedOptionTexts.join(', ')
                                : encuesta.tipoRespuesta ==
                                        EncuestaTipoRespuesta.reaccion
                                    ? r.reaccion ?? ''
                                    : r.selectedOptionText ?? '',
                          ),
                          Text(fmt.format(r.fechaRespuesta)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
      ],
    );
  }
}

// =============================================================================
// DASHBOARD PAGE
// =============================================================================

class _EncuestasDashboardPage extends StatelessWidget {
  const _EncuestasDashboardPage();

  @override
  Widget build(BuildContext context) {
    final service = context.read<EncuestaService>();
    final firestoreService = context.read<FirestoreService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard de Encuestas')),
      body: StreamBuilder<List<Cofrade>>(
        stream: firestoreService.getCofrades(),
        builder: (context, cofSnap) {
          final cofrades = (cofSnap.data ?? [])
              .where((c) => c.isActivo && !c.esCuentaServicio)
              .toList();
          return FutureBuilder<Map<String, dynamic>>(
            future: service.getDashboardMetrics(cofrades),
            builder: (context, metSnap) {
              if (!metSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final m = metSnap.data!;
              final totalEnc = m['totalEncuestas'] as int;
              final avgRate = m['participacionMedia'] as double;
              final top = m['masParticipacion'] as Map<String, dynamic>?;
              final bottom = m['menosParticipacion'] as Map<String, dynamic>?;
              final byTag = m['porTag'] as Map<String, double>;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview cards
                      Row(
                        children: [
                          _DashCard(
                              title: 'Total encuestas',
                              value: '$totalEnc',
                              icon: Icons.poll),
                          const SizedBox(width: 16),
                          _DashCard(
                              title: 'Participación media',
                              value: '${(avgRate * 100).toStringAsFixed(1)}%',
                              icon: Icons.trending_up),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (top != null) ...[
                        Text('Mayor participación',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.emoji_events,
                                color: Colors.amber),
                            title: Text(top['titulo'] ?? ''),
                            trailing: Text(
                                '${((top['rate'] as double) * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                      if (bottom != null) ...[
                        const SizedBox(height: 16),
                        Text('Menor participación',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber,
                                color: Colors.orange),
                            title: Text(bottom['titulo'] ?? ''),
                            trailing: Text(
                                '${((bottom['rate'] as double) * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],

                      if (byTag.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Participación por colectivo (tag)',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        ...byTag.entries.map((entry) {
                          final pct = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: Text(entry.key,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: pct),
                                    duration: const Duration(milliseconds: 800),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, val, __) => ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: val,
                                        minHeight: 12,
                                        backgroundColor: Colors.grey.shade100,
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                                AppTheme.accentColor),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('${(pct * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 32),
                      // All surveys summary
                      Text('Todas las encuestas',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      StreamBuilder<List<Encuesta>>(
                        stream: service.getAllEncuestas(),
                        builder: (context, snap) {
                          final enc = snap.data ?? [];
                          if (enc.isEmpty) {
                            return const Text('Sin encuestas.');
                          }
                          return ResponsiveDataTable(
                            columns: const [
                              ResponsiveTableColumn(
                                  label: 'Título', mobilePriority: 0),
                              ResponsiveTableColumn(
                                  label: 'Estado', mobilePriority: 1),
                              ResponsiveTableColumn(
                                  label: 'Respuestas', mobilePriority: 2),
                              ResponsiveTableColumn(
                                  label: 'Destinatarios', mobilePriority: 3),
                              ResponsiveTableColumn(
                                  label: 'Participación', mobilePriority: 2),
                            ],
                            rows: [
                              for (final e in enc)
                                ResponsiveTableRow(
                                  cells: [
                                    Text(e.titulo,
                                        overflow: TextOverflow.ellipsis),
                                    Text(e.estadoLabel),
                                    Text('${e.totalRespuestas}'),
                                    Text(
                                        '${service.countTargetedCofrades(e, cofrades)}'),
                                    Text(
                                      '${service.countTargetedCofrades(e, cofrades) > 0 ? (e.totalRespuestas / service.countTargetedCofrades(e, cofrades) * 100).toStringAsFixed(1) : '-'}%',
                                    ),
                                  ],
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _DashCard(
      {required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 36, color: AppTheme.primaryColor),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor)),
                  Text(title,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
