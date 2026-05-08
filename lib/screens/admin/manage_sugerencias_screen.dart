import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
              gradient: LinearGradient(
                  colors: [AppTheme.primaryDark, AppTheme.primaryColor]),
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_outlined, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Administración de Mensajería',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: fs.watchAllConversations(),
                      builder: (context, snapshot) {
                        final conversations = snapshot.data ?? [];
                        final pending = conversations
                            .where((c) => c['status'] == 'pending_admin')
                            .toList();
                        final open = conversations
                            .where((c) => c['status'] != 'closed')
                            .toList();
                        final closed = conversations
                            .where((c) => c['status'] == 'closed')
                            .toList();
                        if (conversations.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                                title:
                                    'Pendientes de respuesta (${pending.length})',
                                color: Colors.orange.shade700),
                            const SizedBox(height: 8),
                            ...pending.map((c) => _AdminConversationCard(
                                conversation: c, fs: fs)),
                            const SizedBox(height: 16),
                            _SectionTitle(
                                title: 'Abiertas (${open.length})',
                                color: AppTheme.primaryColor),
                            const SizedBox(height: 8),
                            ...open
                                .where((c) => c['status'] != 'pending_admin')
                                .map((c) => _AdminConversationCard(
                                    conversation: c, fs: fs)),
                            if (closed.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _SectionTitle(
                                  title: 'Cerradas (${closed.length})',
                                  color: Colors.grey.shade600),
                              const SizedBox(height: 8),
                              ...closed.map((c) => _AdminConversationCard(
                                  conversation: c, fs: fs)),
                            ],
                            const Divider(height: 32),
                          ],
                        );
                      },
                    ),
                    StreamBuilder<List<Sugerencia>>(
                      stream: fs.getSugerencias(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final items = snapshot.data ?? [];
                        if (items.isEmpty) {
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200)),
                            child: const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                  child: Text(
                                      'No hay sugerencias ni peticiones.')),
                            ),
                          );
                        }
                        final pendientes = items
                            .where((s) => s.estado == 'pendiente')
                            .toList();
                        final respondidas = items
                            .where((s) => s.estado != 'pendiente')
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (pendientes.isNotEmpty) ...[
                              _SectionTitle(
                                  title: 'Pendientes (${pendientes.length})',
                                  color: Colors.orange.shade700),
                              const SizedBox(height: 8),
                              ...pendientes.map((s) =>
                                  _AdminSugerenciaCard(sugerencia: s, fs: fs)),
                              const SizedBox(height: 24),
                            ],
                            if (respondidas.isNotEmpty) ...[
                              _SectionTitle(
                                  title: 'Gestionadas (${respondidas.length})',
                                  color: AppTheme.accentColor),
                              const SizedBox(height: 8),
                              ...respondidas.map((s) =>
                                  _AdminSugerenciaCard(sugerencia: s, fs: fs)),
                            ],
                          ],
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

class _AdminConversationCard extends StatefulWidget {
  final Map<String, dynamic> conversation;
  final FirestoreService fs;

  const _AdminConversationCard({
    required this.conversation,
    required this.fs,
  });

  @override
  State<_AdminConversationCard> createState() => _AdminConversationCardState();
}

class _AdminConversationCardState extends State<_AdminConversationCard> {
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
    final c = widget.conversation;
    final type = '${c['type'] ?? 'admin_message'}';
    final status = '${c['status'] ?? 'open'}';
    final label = switch (type) {
      'request' => 'Petición',
      'suggestion' => 'Sugerencia',
      _ => 'Mensaje admin',
    };
    final pending = status == 'pending_admin';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: pending ? Colors.orange.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    pending ? Icons.mark_email_unread : Icons.forum_outlined,
                    color: pending
                        ? Colors.orange.shade700
                        : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${c['subject'] ?? 'Comunicación'}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(
                          '${c['cofradeName'] ?? c['cofradeId'] ?? ''} · ${_statusLabel(status)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha(16),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.primaryColor)),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            _buildMessages(context),
          ],
        ],
      ),
    );
  }

  Widget _buildMessages(BuildContext context) {
    final c = widget.conversation;
    final cofradeId = '${c['cofradeId'] ?? ''}';
    final conversationId = '${c['id']}';
    final isClosed = c['status'] == 'closed';
    final fmt = DateFormat('dd/MM HH:mm');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream:
                widget.fs.watchConversationMessages(cofradeId, conversationId),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) return const Text('Sin mensajes.');
              return Column(
                children: messages.map((message) {
                  final createdAt = message['createdAt'];
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${message['createdByRole'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            if (createdAt is Timestamp)
                              Text(fmt.format(createdAt.toDate()),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${message['body'] ?? ''}'),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: isClosed
                ? OutlinedButton.icon(
                    onPressed: () => widget.fs.reopenConversation(
                      conversationId: conversationId,
                      cofradeId: cofradeId,
                      reopenedBy: 'admin',
                    ),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Reabrir ticket'),
                  )
                : OutlinedButton.icon(
                    onPressed: () => widget.fs.closeConversation(
                      conversationId: conversationId,
                      cofradeId: cofradeId,
                      closedBy: 'admin',
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Cerrar ticket'),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  enabled: !isClosed,
                  decoration: const InputDecoration(
                    hintText: 'Responder...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sending || isClosed
                    ? null
                    : () async {
                        if (_replyController.text.trim().isEmpty) return;
                        setState(() => _sending = true);
                        try {
                          await widget.fs.replyConversation(
                            cofradeId: cofradeId,
                            conversationId: conversationId,
                            body: _replyController.text.trim(),
                            createdBy: 'admin',
                            createdByRole: 'admin',
                          );
                          _replyController.clear();
                        } finally {
                          if (mounted) setState(() => _sending = false);
                        }
                      },
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'pending_admin' => 'Pendiente de administración',
      'pending_cofrade' => 'Pendiente del cofrade',
      'closed' => 'Cerrada',
      _ => 'Abierta',
    };
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
        Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (esPeticion
                                  ? Colors.orange
                                  : AppTheme.accentColor)
                              .withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(esPeticion ? 'Petici\u00f3n' : 'Sugerencia',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: esPeticion
                                    ? Colors.orange.shade700
                                    : AppTheme.accentColor)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: estadoColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(estadoLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: estadoColor)),
                      ),
                      const Spacer(),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                          size: 20, color: AppTheme.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(s.cofradeNombre,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(s.titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(s.mensaje,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, height: 1.4)),
                  const SizedBox(height: 4),
                  Text(fmt.format(s.fecha),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
              const Text('Conversaci\u00f3n',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.primaryColor)),
              const Spacer(),
              if (!s.isCerrada) ...[
                if (s.estado == 'pendiente')
                  TextButton.icon(
                    onPressed: () => widget.fs.marcarSugerenciaLeida(s.id),
                    icon: const Icon(Icons.visibility, size: 14),
                    label: const Text('Marcar le\u00edda',
                        style: TextStyle(fontSize: 12)),
                  ),
                TextButton.icon(
                  onPressed: _cerrarTicket,
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Cerrar', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade400),
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
                    s.isCerrada
                        ? 'No hubo mensajes.'
                        : 'No hay mensajes a\u00fan. Responde al cofrade.',
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
                      color: isAdmin
                          ? AppTheme.primaryColor.withAlpha(10)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isAdmin
                              ? AppTheme.primaryColor.withAlpha(30)
                              : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                                isAdmin
                                    ? Icons.admin_panel_settings
                                    : Icons.person,
                                size: 14,
                                color: isAdmin
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(isAdmin ? 'Junta Directiva' : m.autorNombre,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isAdmin
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondary)),
                            const Spacer(),
                            Text(fmtShort.format(m.fecha),
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey.shade500)),
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
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _enviarMensaje,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 14, color: AppTheme.textSecondary),
                  SizedBox(width: 6),
                  Text('Ticket cerrado',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
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
          const SnackBar(
              content: Text('Respuesta enviada'),
              backgroundColor: AppTheme.accentColor),
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
        content: const Text(
            '\u00bfCerrar este ticket? El cofrade no podr\u00e1 enviar m\u00e1s mensajes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
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
