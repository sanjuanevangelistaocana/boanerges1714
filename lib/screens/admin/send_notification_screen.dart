import 'package:flutter/material.dart';
import 'package:boanerges1714/config/theme.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() =>
      _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _mensajeController = TextEditingController();
  String _destinatario = 'todos';
  bool _enviando = false;
  bool _enviado = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enviar Notificación',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Envía una notificación push a los cofrades',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (_enviado)
              Card(
                color: Colors.green[50],
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Notificación enviada correctamente.',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_enviado)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _tituloController,
                          decoration: const InputDecoration(
                            labelText: 'Título de la notificación *',
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Introduce un título'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _mensajeController,
                          decoration: const InputDecoration(
                            labelText: 'Mensaje *',
                            prefixIcon: Icon(Icons.message),
                          ),
                          maxLines: 4,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Introduce un mensaje'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text('Destinatarios',
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Todos los cofrades'),
                              selected: _destinatario == 'todos',
                              onSelected: (_) =>
                                  setState(() => _destinatario = 'todos'),
                            ),
                            ChoiceChip(
                              label: const Text('Solo activos'),
                              selected: _destinatario == 'activos',
                              onSelected: (_) =>
                                  setState(() => _destinatario = 'activos'),
                            ),
                            ChoiceChip(
                              label: const Text('Junta Directiva'),
                              selected: _destinatario == 'junta',
                              onSelected: (_) =>
                                  setState(() => _destinatario = 'junta'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Card(
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'La notificación se enviará a todos los '
                                    'dispositivos registrados de los cofrades '
                                    'seleccionados.',
                                    style: TextStyle(
                                        color: Colors.blue[800], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _enviando ? null : _enviarNotificacion,
                            icon: _enviando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send),
                            label: Text(
                                _enviando ? 'Enviando...' : 'Enviar Notificación'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_enviado)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _enviado = false;
                      _tituloController.clear();
                      _mensajeController.clear();
                    });
                  },
                  child: const Text('Enviar otra notificación'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarNotificacion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);

    // In production, this would call a Cloud Function to send FCM notifications
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _enviando = false;
        _enviado = true;
      });
    }
  }
}
