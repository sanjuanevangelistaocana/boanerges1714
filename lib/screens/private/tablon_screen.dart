import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class TablonScreen extends StatefulWidget {
  const TablonScreen({super.key});

  @override
  State<TablonScreen> createState() => _TablonScreenState();
}

class _TablonScreenState extends State<TablonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _mensajeController = TextEditingController();
  String _categoria = 'general';
  bool _enviando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    try {
      final auth = context.read<AuthService>();
      final fs = context.read<FirestoreService>();
      final cofrade = auth.cofrade;

      await fs.crearAnuncio(
        cofradeId: cofrade?.id ?? '',
        cofradeNombre: cofrade?.nombreCompleto ?? 'Cofrade',
        titulo: _tituloController.text.trim(),
        mensaje: _mensajeController.text.trim(),
        categoria: _categoria,
      );

      _tituloController.clear();
      _mensajeController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anuncio enviado. Ser\u00e1 visible tras la aprobaci\u00f3n de un administrador.'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

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
                  Icon(Icons.campaign, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Tabl\u00f3n de Anuncios',
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
                              const Text('Publicar anuncio',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Tu anuncio ser\u00e1 revisado por un administrador antes de publicarse.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _categoria,
                                decoration: const InputDecoration(labelText: 'Categor\u00eda', prefixIcon: Icon(Icons.category)),
                                items: const [
                                  DropdownMenuItem(value: 'general', child: Text('General')),
                                  DropdownMenuItem(value: 'venta', child: Text('Venta / Intercambio')),
                                  DropdownMenuItem(value: 'busqueda', child: Text('B\u00fasqueda')),
                                  DropdownMenuItem(value: 'ofrecimiento', child: Text('Ofrecimiento')),
                                  DropdownMenuItem(value: 'otro', child: Text('Otro')),
                                ],
                                onChanged: (v) => setState(() => _categoria = v ?? 'general'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _tituloController,
                                decoration: const InputDecoration(labelText: 'T\u00edtulo', prefixIcon: Icon(Icons.title)),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Introduce un t\u00edtulo' : null,
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
                                  onPressed: _enviando ? null : _publicar,
                                  icon: _enviando
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.send),
                                  label: const Text('Enviar para revisi\u00f3n'),
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
                        Text('Anuncios publicados', style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: fs.getAnuncios(soloAprobados: true),
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
                              child: Text('No hay anuncios publicados a\u00fan.'),
                            ),
                          );
                        }
                        return Column(
                          children: items.map((a) => _AnuncioCard(anuncio: a)).toList(),
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

class _AnuncioCard extends StatelessWidget {
  final Map<String, dynamic> anuncio;
  const _AnuncioCard({required this.anuncio});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final fecha = (anuncio['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
    final categoria = anuncio['categoria'] as String? ?? 'general';

    Color catColor;
    String catLabel;
    switch (categoria) {
      case 'venta':
        catColor = Colors.green.shade700;
        catLabel = 'Venta / Intercambio';
        break;
      case 'busqueda':
        catColor = Colors.blue.shade700;
        catLabel = 'B\u00fasqueda';
        break;
      case 'ofrecimiento':
        catColor = Colors.purple.shade700;
        catLabel = 'Ofrecimiento';
        break;
      case 'otro':
        catColor = Colors.grey.shade700;
        catLabel = 'Otro';
        break;
      default:
        catColor = AppTheme.accentColor;
        catLabel = 'General';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: catColor.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                  child: Text(catLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: catColor)),
                ),
                const Spacer(),
                Text(fmt.format(fecha), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 10),
            Text(anuncio['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(anuncio['mensaje'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, height: 1.4)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(anuncio['cofrade_nombre'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
