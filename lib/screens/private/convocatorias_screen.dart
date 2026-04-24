import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/convocatoria.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class ConvocatoriasScreen extends StatelessWidget {
  const ConvocatoriasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consultas y Encuestas',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Responde a las consultas activas de la cofradía.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Convocatoria>>(
              stream: firestoreService.getConvocatoriasActivas(),
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
                        child: Column(
                          children: [
                            Icon(Icons.inbox, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No hay consultas activas.',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: convocatorias
                      .map((c) => _ConvocatoriaCard(convocatoria: c))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConvocatoriaCard extends StatefulWidget {
  final Convocatoria convocatoria;

  const _ConvocatoriaCard({required this.convocatoria});

  @override
  State<_ConvocatoriaCard> createState() => _ConvocatoriaCardState();
}

class _ConvocatoriaCardState extends State<_ConvocatoriaCard> {
  String? _selectedOption;
  final _comentarioController = TextEditingController();
  bool _isSending = false;
  bool _alreadyResponded = false;
  String? _previousResponse;

  @override
  void initState() {
    super.initState();
    _loadMiRespuesta();
  }

  Future<void> _loadMiRespuesta() async {
    final cofrade = context.read<AuthService>().cofrade;
    if (cofrade == null) return;
    final respuesta = await context
        .read<FirestoreService>()
        .getMiRespuesta(widget.convocatoria.id, cofrade.id);
    if (respuesta != null && mounted) {
      setState(() {
        _alreadyResponded = true;
        _previousResponse = respuesta.respuesta;
        _selectedOption = respuesta.respuesta;
        _comentarioController.text = respuesta.comentario ?? '';
      });
    }
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.convocatoria;
    final dateFormat = DateFormat('dd/MM/yyyy', 'es');
    final isExpired = !c.isVigente;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tipoColor(c.tipo).withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    c.tipoLabel,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _tipoColor(c.tipo)),
                  ),
                ),
                const Spacer(),
                if (isExpired)
                  const Chip(
                    label: Text('Cerrada',
                        style: TextStyle(fontSize: 12, color: Colors.white)),
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(c.titulo,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(c.descripcion),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.event, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Evento: ${dateFormat.format(c.fechaEvento)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(width: 16),
                const Icon(Icons.timer, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Límite: ${dateFormat.format(c.fechaLimite)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
            if (_alreadyResponded) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text('Tu respuesta: $_previousResponse',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  ],
                ),
              ),
            ],
            if (!isExpired) ...[
              const Divider(height: 24),
              const Text('Tu respuesta:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: c.opciones.map((opcion) {
                  final isSelected = _selectedOption == opcion;
                  return ChoiceChip(
                    label: Text(opcion),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedOption = selected ? opcion : null);
                    },
                    selectedColor: AppTheme.primaryColor.withAlpha(50),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _comentarioController,
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional)',
                  hintText: 'Ej: Llego un poco tarde...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _selectedOption == null || _isSending
                      ? null
                      : _enviarRespuesta,
                  icon: _isSending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: Text(
                      _alreadyResponded ? 'Actualizar respuesta' : 'Responder'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _tipoColor(String tipo) {
    switch (tipo) {
      case 'procesion':
        return Colors.purple;
      case 'evento':
        return Colors.blue;
      case 'consulta':
        return Colors.orange;
      default:
        return AppTheme.primaryColor;
    }
  }

  Future<void> _enviarRespuesta() async {
    if (_selectedOption == null) return;
    setState(() => _isSending = true);

    try {
      final cofrade = context.read<AuthService>().cofrade;
      if (cofrade == null) return;

      await context.read<FirestoreService>().responderConvocatoria(
            convocatoriaId: widget.convocatoria.id,
            cofradeId: cofrade.id,
            cofradeNombre: cofrade.nombreCompleto,
            respuesta: _selectedOption!,
            comentario: _comentarioController.text.trim().isEmpty
                ? null
                : _comentarioController.text.trim(),
          );

      if (mounted) {
        setState(() {
          _alreadyResponded = true;
          _previousResponse = _selectedOption;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respuesta enviada correctamente.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
