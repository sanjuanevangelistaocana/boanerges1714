import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/utils/madrid_date.dart';

class ManageEvangelioScreen extends StatefulWidget {
  const ManageEvangelioScreen({super.key});

  @override
  State<ManageEvangelioScreen> createState() => _ManageEvangelioScreenState();
}

class _ManageEvangelioScreenState extends State<ManageEvangelioScreen> {
  final _title = TextEditingController();
  final _reference = TextEditingController();
  final _text = TextEditingController();
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _title.dispose();
    _reference.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final result =
        await context.read<FirestoreService>().refreshEvangelioDelDia();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = result == null
          ? 'No se pudo descargar el Evangelio desde la fuente.'
          : 'Evangelio actualizado desde la fuente.';
    });
    if (result != null) _fill(result);
  }

  void _fill(Map<String, dynamic> data) {
    _title.text = '${data['titulo'] ?? ''}';
    _reference.text = '${data['referencia'] ?? ''}';
    _text.text = '${data['texto'] ?? ''}';
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await context.read<FirestoreService>().saveEvangelioDelDia(
            titulo: _title.text,
            referencia: _reference.text,
            texto: _text.text,
          );
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'Cambios guardados para ${MadridDate.key()}.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'No se pudo guardar: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Evangelio del día',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('Fecha de referencia: ${MadridDate.display()}',
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 20),
              StreamBuilder<Map<String, dynamic>?>(
                stream: context.read<FirestoreService>().getEvangelioDelDia(),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data != null &&
                      _title.text.isEmpty &&
                      _reference.text.isEmpty &&
                      _text.text.isEmpty) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _fill(data));
                  }
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _title,
                            decoration:
                                const InputDecoration(labelText: 'Título'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _reference,
                            decoration:
                                const InputDecoration(labelText: 'Referencia'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _text,
                            minLines: 10,
                            maxLines: 20,
                            decoration:
                                const InputDecoration(labelText: 'Texto'),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: _loading ? null : _save,
                                icon: const Icon(Icons.save),
                                label: const Text('Guardar edición manual'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _loading ? null : _reload,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Recargar desde la fuente'),
                              ),
                            ],
                          ),
                          if (_loading) ...[
                            const SizedBox(height: 16),
                            const LinearProgressIndicator(),
                          ],
                          if (_message != null) ...[
                            const SizedBox(height: 16),
                            Text(_message!),
                          ],
                        ],
                      ),
                    ),
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
