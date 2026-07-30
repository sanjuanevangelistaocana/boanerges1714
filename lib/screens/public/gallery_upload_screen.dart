import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/gallery.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/gallery_service.dart';
import 'package:boanerges1714/utils/gallery_error.dart';

class GalleryUploadScreen extends StatefulWidget {
  const GalleryUploadScreen({super.key});

  @override
  State<GalleryUploadScreen> createState() => _GalleryUploadScreenState();
}

class _GalleryUploadScreenState extends State<GalleryUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _eventDate;
  PlatformFile? _zip;
  bool _working = false;
  String? _error;
  int? _detectedImages;
  String _progressLabel = '';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final zip = result.files.single;
    if (zip.size > GalleryService.maxZipSizeBytes) {
      setState(() {
        _error = 'El ZIP supera el límite de 50 MB.';
        _zip = null;
        _detectedImages = null;
      });
      return;
    }
    final bytes = zip.bytes!;
    setState(() {
      _working = true;
      _error = null;
      _progressLabel = 'Inspeccionando el contenido del ZIP...';
    });
    try {
      final validation =
          await context.read<GalleryService>().validateZip(bytes);
      if (!mounted) return;
      setState(() {
        _zip = zip;
        _detectedImages = validation.imageCount;
        _working = false;
        _progressLabel = '';
      });
    } catch (error) {
      debugPrint('[GalleryUploadScreen] ZIP validation error: $error');
      if (!mounted) return;
      setState(() {
        _zip = null;
        _detectedImages = null;
        _working = false;
        _progressLabel = '';
        _error = _messageForError(error);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final zip = _zip;
    final auth = context.read<AuthService>();
    if (zip?.bytes == null || auth.user == null) {
      setState(() => _error = 'Selecciona un ZIP válido antes de continuar.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
      _progressLabel = 'Subiendo el ZIP...';
    });
    try {
      final service = context.read<GalleryService>();
      final upload = await service.uploadZip(
        bytes: zip!.bytes!,
        fileName: zip.name,
      );
      final zipPath = upload['storage_path'];
      final zipUrl = upload['url'];
      if (zipPath == null ||
          zipPath.isEmpty ||
          zipUrl == null ||
          zipUrl.isEmpty) {
        throw StateError(
            'Storage no devolvió una referencia válida para el ZIP.');
      }
      await service.createUploadRequest(
        GalleryUploadRequest(
          id: '',
          titulo: _titleController.text.trim(),
          descripcion: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          fechaEvento: _eventDate,
          zipPath: zipPath,
          zipUrl: zipUrl,
          zipSizeBytes: zip.size,
          numFotosEstimadas: _detectedImages,
          createdBy: auth.user!.uid,
          createdByNombre:
              auth.cofrade?.nombreCompleto ?? auth.user!.displayName ?? '',
          createdByEmail: auth.user!.email ?? '',
          fechaCreacion: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _working = false;
        _progressLabel = '';
        _zip = null;
        _detectedImages = null;
      });
      _titleController.clear();
      _descriptionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Envío recibido. Queda pendiente de revisión.'),
      ));
    } catch (error) {
      debugPrint('[GalleryUploadScreen] ZIP submission error: $error');
      if (!mounted) return;
      setState(() {
        _working = false;
        _progressLabel = '';
        _error = _messageForError(error);
      });
    }
  }

  String _messageForError(Object error) {
    return galleryErrorMessage(error);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isLoggedIn) {
      return Center(
        child: FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text('Inicia sesión para enviar fotografías'),
        ),
      );
    }
    final service = context.read<GalleryService>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => context.go('/gallery'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver a la galería'),
              ),
              const SizedBox(height: 8),
              Text('Enviar fotografías',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Comparte un ZIP con fotografías de la Cofradía. '
                'La Junta lo revisará antes de publicarlo.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration:
                              const InputDecoration(labelText: 'Título *'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Indica un título para el envío.'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Descripción (opcional)'),
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_outlined),
                          title: Text(_eventDate == null
                              ? 'Fecha aproximada del evento (opcional)'
                              : DateFormat('d MMMM yyyy', 'es_ES')
                                  .format(_eventDate!)),
                          trailing: _eventDate == null
                              ? const Icon(Icons.calendar_today)
                              : IconButton(
                                  onPressed: () =>
                                      setState(() => _eventDate = null),
                                  icon: const Icon(Icons.clear),
                                ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                              initialDate: _eventDate ?? DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _eventDate = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withAlpha(10),
                            border: Border.all(
                              color: AppTheme.primaryColor.withAlpha(90),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: OutlinedButton.icon(
                            onPressed: _working ? null : _pickZip,
                            icon: const Icon(Icons.folder_zip_outlined),
                            label: Text(
                                _zip == null ? 'Seleccionar ZIP' : _zip!.name),
                          ),
                        ),
                        if (_detectedImages != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Se han detectado $_detectedImages imágenes válidas.',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ],
                        if (_working && _progressLabel.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_progressLabel,
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _working ? null : _submit,
                            icon: _working
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                            label: Text(_working
                                ? 'Validando y subiendo...'
                                : 'Enviar para revisión'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text('Mis envíos', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              StreamBuilder<List<GalleryUploadRequest>>(
                stream: service.watchMyRequests(auth.user!.uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('[GalleryUploadScreen] watchMyRequests error: '
                        '${snapshot.error}');
                    return _UploadStateMessage(
                      icon: Icons.error_outline,
                      message: galleryErrorMessage(snapshot.error!),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final requests = snapshot.data ?? const [];
                  if (requests.isEmpty) {
                    return const _UploadStateMessage(
                      icon: Icons.inbox_outlined,
                      message: 'Todavía no has enviado fotografías.',
                    );
                  }
                  return Column(
                    children: requests
                        .map((request) => _RequestCard(request: request))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadStateMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _UploadStateMessage({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 24),
          const SizedBox(width: 10),
          Flexible(
            child: Text(message, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final GalleryUploadRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final rejected = request.estado == GalleryUploadRequestStatus.rechazado;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          rejected ? Icons.cancel_outlined : Icons.folder_zip_outlined,
          color: rejected ? Colors.red : AppTheme.primaryColor,
        ),
        title: Text(request.titulo),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_statusLabel(request.estado)} · '
              '${request.numFotosEstimadas ?? 0} fotos · '
              '${DateFormat('d MMM yyyy', 'es_ES').format(request.fechaCreacion)}',
            ),
            if (rejected && request.motivoRechazo?.isNotEmpty == true)
              Text('Motivo: ${request.motivoRechazo}'),
          ],
        ),
        isThreeLine: rejected,
      ),
    );
  }

  String _statusLabel(GalleryUploadRequestStatus status) {
    switch (status) {
      case GalleryUploadRequestStatus.pendiente:
        return 'Pendiente de revisión';
      case GalleryUploadRequestStatus.aprobado:
        return 'Aprobado';
      case GalleryUploadRequestStatus.rechazado:
        return 'Rechazado';
      case GalleryUploadRequestStatus.procesado:
        return 'Procesado';
    }
  }
}
