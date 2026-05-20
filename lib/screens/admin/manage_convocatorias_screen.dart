import 'dart:convert';
// CSV export for Flutter Web. The project already targets web for admin tools.
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/convocatoria.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/storage_service.dart';

class ManageConvocatoriasScreen extends StatelessWidget {
  const ManageConvocatoriasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
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
                        'Crea encuestas para recoger opiniones, preferencias y propuestas de los cofrades.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showSurveyDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva encuesta'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Convocatoria>>(
              stream: firestoreService.getConvocatorias(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final encuestas = snapshot.data ?? [];
                if (encuestas.isEmpty) {
                  return _EmptySurveyState(
                    message: 'No hay encuestas creadas todavía.',
                    action: () => _showSurveyDialog(context),
                  );
                }
                return Column(
                  children: encuestas
                      .map((survey) => _AdminSurveyCard(survey: survey))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSurveyDialog(BuildContext context, {Convocatoria? survey}) {
    showDialog(
      context: context,
      builder: (ctx) => _SurveyEditorDialog(survey: survey),
    );
  }
}

class _EmptySurveyState extends StatelessWidget {
  final String message;
  final VoidCallback action;

  const _EmptySurveyState({required this.message, required this.action});

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

class _SurveyEditorDialog extends StatefulWidget {
  final Convocatoria? survey;

  const _SurveyEditorDialog({this.survey});

  @override
  State<_SurveyEditorDialog> createState() => _SurveyEditorDialogState();
}

class _SurveyEditorDialogState extends State<_SurveyEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late DateTime _deadline;
  late String _type;
  late String _status;
  late bool _showResults;
  late List<SurveyOption> _options;
  late List<Map<String, String>> _attachments;
  late final String _surveyId;
  String? _coverUrl;
  String? _coverPath;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final survey = widget.survey;
    _surveyId = survey?.id ??
        FirebaseFirestore.instance.collection('convocatorias').doc().id;
    _title = TextEditingController(text: survey?.titulo ?? '');
    _description = TextEditingController(text: survey?.descripcion ?? '');
    _deadline =
        survey?.fechaLimite ?? DateTime.now().add(const Duration(days: 7));
    _type = survey?.tipo ?? 'opinion';
    _status = survey?.status ?? 'active';
    _showResults = survey?.mostrarResultados ?? false;
    _options = survey?.surveyOptions
            .map((o) => SurveyOption(id: o.id, text: o.text, order: o.order))
            .toList() ??
        const [
          SurveyOption(id: 'option_1', text: 'Sí', order: 1),
          SurveyOption(id: 'option_2', text: 'No', order: 2),
        ];
    _attachments = List<Map<String, String>>.from(survey?.adjuntos ?? const []);
    _coverUrl = survey?.coverImageUrl;
    _coverPath = survey?.coverImagePath;
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
      title: Text(widget.survey == null ? 'Nueva encuesta' : 'Editar encuesta'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                    title: 'Datos básicos',
                    help:
                        'Define la pregunta, el contexto y hasta cuándo se puede responder.'),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Título *'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Campo obligatorio'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Descripción *'),
                  maxLines: 4,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Campo obligatorio'
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                            labelText: 'Tipo de encuesta'),
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
                        onChanged: (value) =>
                            setState(() => _type = value ?? _type),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: const [
                          DropdownMenuItem(
                              value: 'draft', child: Text('Borrador')),
                          DropdownMenuItem(
                              value: 'active', child: Text('Activa')),
                          DropdownMenuItem(
                              value: 'closed', child: Text('Cerrada')),
                          DropdownMenuItem(
                              value: 'archived', child: Text('Archivada')),
                        ],
                        onChanged: (value) =>
                            setState(() => _status = value ?? _status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(
                      'Fecha límite: ${DateFormat('dd/MM/yyyy').format(_deadline)}'),
                  subtitle:
                      const Text('Solo se podrá responder hasta esta fecha.'),
                  onTap: _pickDeadline,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar resultados a los cofrades'),
                  subtitle: const Text(
                      'Si está desactivado, solo administración verá los resultados.'),
                  value: _showResults,
                  onChanged: (value) => setState(() => _showResults = value),
                ),
                const Divider(height: 28),
                const _SectionTitle(
                    title: 'Opciones de respuesta',
                    help:
                        'Cada opción se guarda de forma estructurada y se puede votar con un clic.'),
                _OptionsEditor(
                  options: _options,
                  onChanged: (options) => setState(() => _options = options),
                ),
                const Divider(height: 28),
                const _SectionTitle(
                    title: 'Portada y adjuntos',
                    help:
                        'La portada aparece en las cards. El PDF queda visible para cofrades autenticados.'),
                if ((_coverUrl ?? '').isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _coverUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
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
                    subtitle: Text(_attachments[i]['tipo'] ?? ''),
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
          label: Text(widget.survey == null ? 'Crear encuesta' : 'Guardar'),
        ),
      ],
    );
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) setState(() => _deadline = date);
  }

  Future<void> _uploadCover() async {
    setState(() => _uploading = true);
    final storageService = context.read<StorageService>();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.first.bytes == null) return;
      final file = result.files.first;
      final uploaded = await storageService.uploadFile(
        path: 'surveys/$_surveyId/cover',
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
    final storageService = context.read<StorageService>();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.first.bytes == null) return;
      final file = result.files.first;
      final uploaded = await storageService.uploadFile(
        path: 'surveys/$_surveyId/attachments',
        bytes: file.bytes!,
        fileName: file.name,
        allowedExtensions: {'pdf'},
        maxSizeBytes: 20 * 1024 * 1024,
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
    final cleaned = _normalizedOptions();
    if (cleaned.length < 2) {
      _showError('Añade al menos 2 opciones de respuesta.');
      return;
    }
    final duplicates = <String>{};
    for (final option in cleaned) {
      final key = option.text.trim().toLowerCase();
      if (!duplicates.add(key)) {
        _showError('Hay opciones duplicadas.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final actor = context.read<AuthService>().cofrade;
      final survey = Convocatoria(
        id: _surveyId,
        titulo: _title.text.trim(),
        descripcion: _description.text.trim(),
        tipo: _type,
        fechaEvento: _deadline,
        fechaLimite: _deadline,
        opciones: cleaned.map((option) => option.text).toList(),
        surveyOptions: cleaned,
        activa: _status == 'active',
        status: _status,
        creadaPor: widget.survey?.creadaPor ??
            actor?.nombreCompleto ??
            actor?.id ??
            'Admin',
        fechaCreacion: widget.survey?.fechaCreacion ?? DateTime.now(),
        totalRespuestas: widget.survey?.totalRespuestas ?? 0,
        adjuntos: _attachments,
        coverImageUrl: _coverUrl,
        coverImagePath: _coverPath,
        mostrarResultados: _showResults,
      );
      final service = context.read<FirestoreService>();
      if (widget.survey == null) {
        await service.createConvocatoria(survey);
      } else {
        await service.updateConvocatoria(survey.id, survey.toFirestore());
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.survey == null
                ? 'Encuesta creada correctamente.'
                : 'Encuesta actualizada.'),
          ),
        );
      }
    } catch (e) {
      _showError('No se pudo guardar la encuesta: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<SurveyOption> _normalizedOptions() => _options
      .asMap()
      .entries
      .map((entry) => SurveyOption(
            id: entry.value.id.isEmpty
                ? 'option_${DateTime.now().millisecondsSinceEpoch}_${entry.key}'
                : entry.value.id,
            text: entry.value.text.trim(),
            order: entry.key + 1,
          ))
      .where((option) => option.text.isNotEmpty)
      .toList();

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

class _OptionsEditor extends StatelessWidget {
  final List<SurveyOption> options;
  final ValueChanged<List<SurveyOption>> onChanged;

  const _OptionsEditor({required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Subir',
                  onPressed: i == 0
                      ? null
                      : () {
                          final copy = [...options];
                          final current = copy.removeAt(i);
                          copy.insert(i - 1, current);
                          onChanged(copy);
                        },
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Bajar',
                  onPressed: i == options.length - 1
                      ? null
                      : () {
                          final copy = [...options];
                          final current = copy.removeAt(i);
                          copy.insert(i + 1, current);
                          onChanged(copy);
                        },
                  icon: const Icon(Icons.arrow_downward),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: options[i].text,
                    decoration: InputDecoration(labelText: 'Opción ${i + 1}'),
                    onChanged: (value) {
                      final copy = [...options];
                      copy[i] = SurveyOption(
                        id: options[i].id,
                        text: value,
                        order: i + 1,
                      );
                      onChanged(copy);
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar opción',
                  onPressed: options.length <= 2
                      ? null
                      : () {
                          final copy = [...options]..removeAt(i);
                          onChanged(copy);
                        },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => onChanged([
              ...options,
              SurveyOption(
                id: 'option_${DateTime.now().millisecondsSinceEpoch}',
                text: '',
                order: options.length + 1,
              )
            ]),
            icon: const Icon(Icons.add),
            label: const Text('Añadir opción'),
          ),
        ),
      ],
    );
  }
}

class _AdminSurveyCard extends StatelessWidget {
  final Convocatoria survey;

  const _AdminSurveyCard({required this.survey});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SurveyCover(url: survey.coverImageUrl, size: 112),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusChip(
                          label: survey.statusLabel, status: survey.status),
                      if (survey.mostrarResultados)
                        const _StatusChip(
                            label: 'Resultados visibles', status: 'active'),
                      if (survey.adjuntos.isNotEmpty)
                        _StatusChip(
                            label: '${survey.adjuntos.length} adjunto(s)',
                            status: 'draft'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(survey.titulo,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(survey.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  StreamBuilder<List<RespuestaConvocatoria>>(
                    stream: service.getRespuestas(survey.id),
                    builder: (context, snap) {
                      final responses = snap.data ?? const [];
                      return _SurveyResultsSummary(
                        survey: survey,
                        responses: responses,
                        compact: true,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text('Fecha límite: ${fmt.format(survey.fechaLimite)}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDetail(context),
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Ver detalle'),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _SurveyEditorDialog(survey: survey),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                const SizedBox(height: 6),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleAction(context, value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'active', child: Text('Activar')),
                    PopupMenuItem(value: 'closed', child: Text('Cerrar')),
                    PopupMenuItem(value: 'archived', child: Text('Archivar')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Más opciones'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _SurveyDetailDialog(survey: survey),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final service = context.read<FirestoreService>();
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Eliminar encuesta'),
          content: const Text(
              'Se eliminará la encuesta y sus respuestas. Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar')),
          ],
        ),
      );
      if (ok == true) await service.deleteConvocatoria(survey.id);
      return;
    }
    await service.updateConvocatoria(survey.id, {'status': action});
  }
}

class _SurveyDetailDialog extends StatelessWidget {
  final Convocatoria survey;

  const _SurveyDetailDialog({required this.survey});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();
    return AlertDialog(
      title: Text('Detalle · ${survey.titulo}'),
      content: SizedBox(
        width: 780,
        child: StreamBuilder<List<RespuestaConvocatoria>>(
          stream: service.getRespuestas(survey.id),
          builder: (context, snap) {
            final responses = snap.data ?? const [];
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((survey.coverImageUrl ?? '').isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        survey.coverImageUrl!,
                        height: 170,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 14),
                  _SurveyResultsSummary(
                    survey: survey,
                    responses: responses,
                    compact: false,
                  ),
                  if (survey.adjuntos.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('Adjuntos',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    for (final adj in survey.adjuntos)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.picture_as_pdf),
                        title: Text(adj['nombre'] ?? 'PDF adjunto'),
                        trailing: TextButton(
                          onPressed: () {
                            final url = adj['url'];
                            if (url != null && url.isNotEmpty) {
                              launchUrl(Uri.parse(url),
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          child: const Text('Abrir PDF'),
                        ),
                      ),
                  ],
                  const Divider(height: 28),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Cofrades que han respondido',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _exportCsv(responses),
                        icon: const Icon(Icons.download),
                        label: const Text('Exportar CSV'),
                      ),
                    ],
                  ),
                  if (responses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Todavía no hay respuestas registradas.'),
                    )
                  else
                    DataTable(
                      columns: const [
                        DataColumn(label: Text('Cofrade')),
                        DataColumn(label: Text('Respuesta')),
                        DataColumn(label: Text('Fecha')),
                      ],
                      rows: [
                        for (final response in responses)
                          DataRow(cells: [
                            DataCell(Text(response.cofradeNombre)),
                            DataCell(Text(response.selectedOptionText)),
                            DataCell(Text(DateFormat('dd/MM/yyyy HH:mm').format(
                                response.updatedAt ??
                                    response.fechaRespuesta))),
                          ]),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar')),
      ],
    );
  }

  void _exportCsv(List<RespuestaConvocatoria> responses) {
    final rows = <List<String>>[
      ['Cofrade', 'Respuesta', 'Fecha'],
      for (final r in responses)
        [
          r.cofradeNombre,
          r.selectedOptionText,
          DateFormat('dd/MM/yyyy HH:mm')
              .format(r.updatedAt ?? r.fechaRespuesta),
        ],
    ];
    final csv = rows
        .map((row) =>
            row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','))
        .join('\n');
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'encuesta_${survey.id}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

class _SurveyResultsSummary extends StatelessWidget {
  final Convocatoria survey;
  final List<RespuestaConvocatoria> responses;
  final bool compact;

  const _SurveyResultsSummary({
    required this.survey,
    required this.responses,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final response in responses) {
      final key = response.selectedOptionId.isNotEmpty
          ? response.selectedOptionId
          : response.selectedOptionText;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final total = responses.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricChip(label: 'Respuestas', value: '$total'),
            _MetricChip(
              label: 'Opciones',
              value: '${survey.surveyOptions.length}',
            ),
            _MetricChip(
              label: 'Resultados',
              value: survey.mostrarResultados ? 'Visibles' : 'Ocultos',
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final option in survey.surveyOptions)
          _ResultBar(
            label: option.text,
            count: counts[option.id] ?? counts[option.text] ?? 0,
            total: total,
            compact: compact,
          ),
      ],
    );
  }
}

class _ResultBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final bool compact;

  const _ResultBar({
    required this.label,
    required this.count,
    required this.total,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 5 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text('$count · ${(pct * 100).toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: pct,
            minHeight: compact ? 5 : 8,
            backgroundColor: Colors.grey.shade200,
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}

class _SurveyCover extends StatelessWidget {
  final String? url;
  final double size;

  const _SurveyCover({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if ((url ?? '').isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child:
            Image.network(url!, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withAlpha(14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.poll_outlined,
          color: AppTheme.primaryColor, size: 36),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String status;

  const _StatusChip({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => Colors.green.shade700,
      'closed' => Colors.orange.shade700,
      'archived' => Colors.grey.shade700,
      _ => AppTheme.primaryColor,
    };
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value',
          style: const TextStyle(
              color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String help;

  const _SectionTitle({required this.title, required this.help});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(help, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
