import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
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
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Gestión de Convocatorias',
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCrearDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva'),
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
                final convocatorias = snapshot.data ?? [];
                if (convocatorias.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                          child: Text('No hay convocatorias creadas.')),
                    ),
                  );
                }
                return Column(
                  children: convocatorias
                      .map((c) => _AdminConvocatoriaCard(convocatoria: c))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCrearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _CrearConvocatoriaDialog(),
    );
  }
}

class _CrearConvocatoriaDialog extends StatefulWidget {
  const _CrearConvocatoriaDialog();

  @override
  State<_CrearConvocatoriaDialog> createState() =>
      _CrearConvocatoriaDialogState();
}

class _CrearConvocatoriaDialogState extends State<_CrearConvocatoriaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  String _tipo = 'general';
  DateTime _fechaEvento = DateTime.now().add(const Duration(days: 7));
  DateTime _fechaLimite = DateTime.now().add(const Duration(days: 5));
  final _opcionesController = TextEditingController(text: 'Sí, No');
  bool _isSaving = false;
  bool _uploading = false;
  final List<Map<String, String>> _adjuntos = [];

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _opcionesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Convocatoria'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _tituloController,
                  decoration: const InputDecoration(labelText: 'Título *'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descripcionController,
                  decoration:
                      const InputDecoration(labelText: 'Descripción *'),
                  maxLines: 3,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                        value: 'general', child: Text('General')),
                    DropdownMenuItem(
                        value: 'procesion', child: Text('Procesión')),
                    DropdownMenuItem(
                        value: 'evento', child: Text('Evento')),
                    DropdownMenuItem(
                        value: 'consulta', child: Text('Consulta')),
                  ],
                  onChanged: (v) => setState(() => _tipo = v ?? 'general'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(
                      'Evento: ${DateFormat('dd/MM/yyyy').format(_fechaEvento)}'),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _fechaEvento,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => _fechaEvento = date);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer),
                  title: Text(
                      'Límite: ${DateFormat('dd/MM/yyyy').format(_fechaLimite)}'),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _fechaLimite,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => _fechaLimite = date);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _opcionesController,
                  decoration: const InputDecoration(
                    labelText: 'Opciones (separadas por coma)',
                    hintText: 'Sí, No',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Al menos una opción' : null,
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Adjuntos (${_adjuntos.length})',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('Adjuntar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      onPressed: _uploading ? null : () async {
                        setState(() => _uploading = true);
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                            withData: true,
                            allowMultiple: false,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.first;
                            if (file.bytes != null) {
                              final storage = context.read<StorageService>();
                              final adj = await storage.uploadFile(
                                path: 'convocatorias/new/adjuntos',
                                bytes: file.bytes!,
                                fileName: file.name,
                              );
                              setState(() => _adjuntos.add(adj));
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          setState(() => _uploading = false);
                        }
                      },
                    ),
                  ],
                ),
                if (_uploading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                ..._adjuntos.asMap().entries.map((entry) {
                  final i = entry.key;
                  final adj = entry.value;
                  final esImagen = (adj['tipo'] ?? '').startsWith('image/');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      esImagen ? Icons.image : Icons.insert_drive_file,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(adj['nombre'] ?? 'Archivo',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      onPressed: () => setState(() => _adjuntos.removeAt(i)),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _crear,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final cofrade = context.read<AuthService>().cofrade;
      final opciones = _opcionesController.text
          .split(',')
          .map((o) => o.trim())
          .where((o) => o.isNotEmpty)
          .toList();

      final convocatoria = Convocatoria(
        id: '',
        titulo: _tituloController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        tipo: _tipo,
        fechaEvento: _fechaEvento,
        fechaLimite: _fechaLimite,
        opciones: opciones,
        creadaPor: cofrade?.nombreCompleto ?? 'Admin',
        fechaCreacion: DateTime.now(),
        adjuntos: _adjuntos,
      );

      await context
          .read<FirestoreService>()
          .createConvocatoria(convocatoria);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convocatoria creada.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _AdminConvocatoriaCard extends StatelessWidget {
  final Convocatoria convocatoria;

  const _AdminConvocatoriaCard({required this.convocatoria});

  @override
  Widget build(BuildContext context) {
    final c = convocatoria;
    final dateFormat = DateFormat('dd/MM/yyyy', 'es');
    final firestoreService = context.read<FirestoreService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(c.titulo,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (c.activa)
                  const Chip(
                    label: Text('Activa',
                        style: TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.zero,
                  )
                else
                  const Chip(
                    label: Text('Cerrada',
                        style: TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(c.descripcion),
            const SizedBox(height: 8),
            Text(
              'Evento: ${dateFormat.format(c.fechaEvento)} · '
              'Límite: ${dateFormat.format(c.fechaLimite)} · '
              'Respuestas: ${c.totalRespuestas}',
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<RespuestaConvocatoria>>(
              stream: firestoreService.getRespuestas(c.id),
              builder: (context, snapshot) {
                final respuestas = snapshot.data ?? [];
                if (respuestas.isEmpty) {
                  return const Text('Sin respuestas aún.',
                      style: TextStyle(color: Colors.grey));
                }
                final grouped = <String, List<RespuestaConvocatoria>>{};
                for (final r in respuestas) {
                  grouped.putIfAbsent(r.respuesta, () => []).add(r);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumen de respuestas:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...grouped.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('${entry.value.length}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Text('${entry.key}: '),
                              Flexible(
                                child: Text(
                                  entry.value
                                      .map((r) => r.cofradeNombre)
                                      .join(', '),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                );
              },
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Mostrar resultados', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Switch(
                      value: c.mostrarResultados,
                      activeColor: AppTheme.accentColor,
                      onChanged: (val) async {
                        await firestoreService.updateConvocatoria(
                            c.id, {'mostrar_resultados': val});
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                if (c.activa)
                  TextButton.icon(
                    onPressed: () async {
                      await firestoreService
                          .updateConvocatoria(c.id, {'activa': false});
                    },
                    icon: const Icon(Icons.lock, size: 18),
                    label: const Text('Cerrar'),
                  )
                else
                  TextButton.icon(
                    onPressed: () async {
                      await firestoreService
                          .updateConvocatoria(c.id, {'activa': true});
                    },
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Reabrir'),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar convocatoria'),
                        content: const Text(
                            '¿Seguro que quieres eliminar esta convocatoria?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await firestoreService.deleteConvocatoria(c.id);
                    }
                  },
                  icon:
                      const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('Eliminar',
                      style: TextStyle(color: Colors.red)),
                ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
