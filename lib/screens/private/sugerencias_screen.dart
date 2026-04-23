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
    setState(() => _enviando = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tipo == 'sugerencia' ? 'Sugerencia enviada' : 'Petición enviada'),
          backgroundColor: AppTheme.accentColor,
        ),
      );
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
                            children: items.map((s) => _SugerenciaCard(sugerencia: s)).toList(),
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

class _SugerenciaCard extends StatelessWidget {
  final Sugerencia sugerencia;
  const _SugerenciaCard({required this.sugerencia});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final esPeticion = sugerencia.tipo == 'peticion';
    final color = esPeticion ? Colors.orange.shade700 : AppTheme.accentColor;
    final estadoColor = sugerencia.estado == 'respondida'
        ? AppTheme.accentColor
        : sugerencia.estado == 'leida'
            ? Colors.blue.shade600
            : Colors.orange.shade700;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: sugerencia.estado == 'respondida' ? AppTheme.accentColor.withAlpha(60) : Colors.grey.shade200),
      ),
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
                  child: Text(esPeticion ? 'Petición' : 'Sugerencia',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: estadoColor.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    sugerencia.estado == 'respondida' ? 'Respondida' : sugerencia.estado == 'leida' ? 'Leída' : 'Pendiente',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: estadoColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(sugerencia.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(sugerencia.mensaje, style: const TextStyle(color: AppTheme.textSecondary, height: 1.4)),
            const SizedBox(height: 6),
            Text(fmt.format(sugerencia.fecha), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            if (sugerencia.respuestaAdmin != null && sugerencia.respuestaAdmin!.isNotEmpty) ...[
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.admin_panel_settings, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  const Text('Respuesta de la Junta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                ],
              ),
              const SizedBox(height: 6),
              Text(sugerencia.respuestaAdmin!, style: const TextStyle(height: 1.4)),
              if (sugerencia.fechaRespuesta != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(fmt.format(sugerencia.fechaRespuesta!), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
