import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/sugerencia.dart';

class SugerenciasScreen extends StatefulWidget {
  const SugerenciasScreen({super.key});

  @override
  State<SugerenciasScreen> createState() => _SugerenciasScreenState();
}

class _SugerenciasScreenState extends State<SugerenciasScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _mensajeController = TextEditingController();
  String _tipo = 'sugerencia';
  bool _enviando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    try {
      final auth = context.read<AuthService>();
      final fs = context.read<FirestoreService>();
      final cofrade = auth.cofrade;

      await fs.createSugerencia(Sugerencia(
        id: '',
        cofradeId: cofrade?.id ?? '',
        cofradeNombre: cofrade?.nombreCompleto ?? 'Cofrade',
        tipo: _tipo,
        titulo: _tituloController.text.trim(),
        mensaje: _mensajeController.text.trim(),
        fecha: DateTime.now(),
      ));

      _tituloController.clear();
      _mensajeController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tipo == 'sugerencia' ? 'Sugerencia enviada' : 'Petici\u00f3n enviada'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final fs = context.read<FirestoreService>();
    final cofrade = auth.cofrade;

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primaryColor]),
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Sugerencias y Peticiones',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
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
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Enviar nueva',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'sugerencia', label: Text('Sugerencia'), icon: Icon(Icons.lightbulb_outline)),
                                  ButtonSegment(value: 'peticion', label: Text('Petición'), icon: Icon(Icons.request_page)),
                                ],
                                selected: {_tipo},
                                onSelectionChanged: (v) => setState(() => _tipo = v.first),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _tituloController,
                                decoration: const InputDecoration(labelText: 'Título', prefixIcon: Icon(Icons.title)),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Introduce un título' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _mensajeController,
                                decoration: const InputDecoration(labelText: 'Mensaje', prefixIcon: Icon(Icons.message), alignLabelWithHint: true),
                                maxLines: 4,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Escribe tu mensaje' : null,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _enviando ? null : _enviar,
                                  icon: _enviando
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.send),
                                  label: const Text('Enviar'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Container(width: 4, height: 24, decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 10),
                        Text('Mis envíos', style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (cofrade != null)
                      StreamBuilder<List<Sugerencia>>(
                        stream: fs.getSugerencias(cofradeId: cofrade.id),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Card(
                              elevation: 0,
                              color: Colors.red.shade50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 36),
                                    const SizedBox(height: 8),
                                    Text('Error al cargar env\u00edos: ${snapshot.error}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    const Text('Es posible que se est\u00e9 creando un \u00edndice en Firestore. Int\u00e9ntalo de nuevo en unos minutos.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            );
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final items = snapshot.data ?? [];
                          if (items.isEmpty) {
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                              child: const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No has enviado sugerencias ni peticiones.'),
                              ),
                            );
                          }
                          return Column(
                            children: items.map((s) => _SugerenciaCard(
                              sugerencia: s,
                              cofradeNombre: cofrade.nombreCompleto,
                            )).toList(),
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

class _SugerenciaCard extends StatefulWidget {
  final Sugerencia sugerencia;
  final String cofradeNombre;
  const _SugerenciaCard({required this.sugerencia, required this.cofradeNombre});

  @override
  State<_SugerenciaCard> createState() => _SugerenciaCardState();
}

class _SugerenciaCardState extends State<_SugerenciaCard> {
  bool _expanded = false;
  final _replyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sugerencia;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final esPeticion = s.tipo == 'peticion';
    final color = esPeticion ? Colors.orange.shade700 : AppTheme.accentColor;

    Color estadoColor;
    String estadoLabel;
    switch (s.estado) {
      case 'respondida':
        estadoColor = AppTheme.accentColor;
        estadoLabel = 'Respondida';
        break;
      case 'leida':
        estadoColor = Colors.blue.shade600;
        estadoLabel = 'Le\u00edda';
        break;
      case 'cerrada':
        estadoColor = Colors.grey.shade600;
        estadoLabel = 'Cerrada';
        break;
      default:
        estadoColor = Colors.orange.shade700;
        estadoLabel = 'Pendiente';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: s.estado == 'respondida' ? AppTheme.accentColor.withAlpha(60) : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                        child: Text(esPeticion ? 'Petici\u00f3n' : 'Sugerencia',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: estadoColor.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                        child: Text(estadoLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: estadoColor)),
                      ),
                      const SizedBox(width: 8),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: AppTheme.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(s.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(s.mensaje, style: const TextStyle(color: AppTheme.textSecondary, height: 1.4)),
                  const SizedBox(height: 6),
                  Text(fmt.format(s.fecha), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            _buildConversation(context, s),
          ],
        ],
      ),
    );
  }

  Widget _buildConversation(BuildContext context, Sugerencia s) {
    final fs = context.read<FirestoreService>();
    final fmtShort = DateFormat('dd/MM HH:mm');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              const Text('Conversaci\u00f3n', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
              const Spacer(),
              if (!s.isCerrada)
                TextButton.icon(
                  onPressed: _cerrarTicket,
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Cerrar ticket', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<MensajeSugerencia>>(
            stream: fs.getMensajesSugerencia(s.id),
            builder: (context, snapshot) {
              final mensajes = snapshot.data ?? [];
              if (mensajes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    s.isCerrada ? 'No hubo mensajes en esta conversaci\u00f3n.' : 'A\u00fan no hay mensajes. Escribe el primero o espera la respuesta de la Junta.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                );
              }
              return Column(
                children: mensajes.map((m) {
                  final isAdmin = m.autor == 'admin';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isAdmin ? AppTheme.primaryColor.withAlpha(10) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isAdmin ? AppTheme.primaryColor.withAlpha(30) : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, size: 14,
                                color: isAdmin ? AppTheme.primaryColor : AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(isAdmin ? 'Junta Directiva' : m.autorNombre,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                    color: isAdmin ? AppTheme.primaryColor : AppTheme.textSecondary)),
                            const Spacer(),
                            Text(fmtShort.format(m.fecha), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(m.mensaje, style: const TextStyle(height: 1.4)),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (!s.isCerrada) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _enviarMensaje,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 14, color: AppTheme.textSecondary),
                  SizedBox(width: 6),
                  Text('Este ticket est\u00e1 cerrado', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _enviarMensaje() async {
    if (_replyController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final auth = context.read<AuthService>();
      final fs = context.read<FirestoreService>();
      await fs.enviarMensajeSugerencia(
        sugerenciaId: widget.sugerencia.id,
        autor: 'cofrade',
        autorNombre: auth.cofrade?.nombreCompleto ?? 'Cofrade',
        mensaje: _replyController.text.trim(),
      );
      _replyController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cerrarTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar ticket'),
        content: const Text('\u00bfEst\u00e1s seguro de que quieres cerrar este ticket? No podr\u00e1s enviar m\u00e1s mensajes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar')),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<FirestoreService>().cerrarSugerencia(widget.sugerencia.id, 'cofrade');
    }
  }
}
