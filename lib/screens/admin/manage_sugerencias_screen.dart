import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/sugerencia.dart';

class ManageSugerenciasScreen extends StatelessWidget {
  const ManageSugerenciasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primaryColor]),
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Gestionar Sugerencias y Peticiones',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: StreamBuilder<List<Sugerencia>>(
                  stream: fs.getSugerencias(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        child: const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay sugerencias ni peticiones.')),
                        ),
                      );
                    }
                    final pendientes = items.where((s) => s.estado == 'pendiente').toList();
                    final respondidas = items.where((s) => s.estado != 'pendiente').toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pendientes.isNotEmpty) ...[
                          _SectionTitle(title: 'Pendientes (${pendientes.length})', color: Colors.orange.shade700),
                          const SizedBox(height: 8),
                          ...pendientes.map((s) => _AdminSugerenciaCard(sugerencia: s, fs: fs)),
                          const SizedBox(height: 24),
                        ],
                        if (respondidas.isNotEmpty) ...[
                          _SectionTitle(title: 'Gestionadas (${respondidas.length})', color: AppTheme.accentColor),
                          const SizedBox(height: 8),
                          ...respondidas.map((s) => _AdminSugerenciaCard(sugerencia: s, fs: fs)),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }
}

class _AdminSugerenciaCard extends StatefulWidget {
  final Sugerencia sugerencia;
  final FirestoreService fs;
  const _AdminSugerenciaCard({required this.sugerencia, required this.fs});

  @override
  State<_AdminSugerenciaCard> createState() => _AdminSugerenciaCardState();
}

class _AdminSugerenciaCardState extends State<_AdminSugerenciaCard> {
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
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
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
                        decoration: BoxDecoration(
                          color: (esPeticion ? Colors.orange : AppTheme.accentColor).withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(esPeticion ? 'Petici\u00f3n' : 'Sugerencia',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: esPeticion ? Colors.orange.shade700 : AppTheme.accentColor)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: estadoColor.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                        child: Text(estadoLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: estadoColor)),
                      ),
                      const Spacer(),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: AppTheme.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(s.cofradeNombre, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(s.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(s.mensaje, style: const TextStyle(color: AppTheme.textSecondary, height: 1.4)),
                  const SizedBox(height: 4),
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
              if (!s.isCerrada) ...[
                if (s.estado == 'pendiente')
                  TextButton.icon(
                    onPressed: () => widget.fs.marcarSugerenciaLeida(s.id),
                    icon: const Icon(Icons.visibility, size: 14),
                    label: const Text('Marcar le\u00edda', style: TextStyle(fontSize: 12)),
                  ),
                TextButton.icon(
                  onPressed: _cerrarTicket,
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Cerrar', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<MensajeSugerencia>>(
            stream: widget.fs.getMensajesSugerencia(s.id),
            builder: (context, snapshot) {
              final mensajes = snapshot.data ?? [];
              if (mensajes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    s.isCerrada ? 'No hubo mensajes.' : 'No hay mensajes a\u00fan. Responde al cofrade.',
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
                      hintText: 'Responder como Junta Directiva...',
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
                  Text('Ticket cerrado', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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
      await widget.fs.enviarMensajeSugerencia(
        sugerenciaId: widget.sugerencia.id,
        autor: 'admin',
        autorNombre: 'Junta Directiva',
        mensaje: _replyController.text.trim(),
      );
      _replyController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respuesta enviada'), backgroundColor: AppTheme.accentColor),
        );
      }
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
        content: const Text('\u00bfCerrar este ticket? El cofrade no podr\u00e1 enviar m\u00e1s mensajes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar ticket'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.fs.cerrarSugerencia(widget.sugerencia.id, 'admin');
    }
  }
}
