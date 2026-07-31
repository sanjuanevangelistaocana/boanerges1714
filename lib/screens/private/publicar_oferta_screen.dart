import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/screens/private/banco_tunicas_screen.dart';

class PublicarOfertaScreen extends StatefulWidget {
  const PublicarOfertaScreen({super.key});

  @override
  State<PublicarOfertaScreen> createState() => _PublicarOfertaScreenState();
}

class _PublicarOfertaScreenState extends State<PublicarOfertaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _observacionesController = TextEditingController();
  final _telefonoController = TextEditingController();

  final Set<String> _elementosSeleccionados = {};
  final Map<String, TextEditingController> _tallaControllers = {};
  String _estadoConservacion = 'Bueno';
  String _propiedad = 'particular';
  bool _isLoading = false;

  final List<String> _estadosConservacion = [
    'Nuevo',
    'Muy bueno',
    'Bueno',
    'Aceptable',
    'Usado',
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _telefonoController.text = auth.cofrade?.telefonoMovil ?? '';
  }

  @override
  void dispose() {
    for (final c in _tallaControllers.values) {
      c.dispose();
    }
    _observacionesController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  TextEditingController _getTallaController(String elemento) {
    return _tallaControllers.putIfAbsent(
        elemento, () => TextEditingController());
  }

  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_elementosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un elemento')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthService>();
      final fs = context.read<FirestoreService>();

      final tallasPorElemento = <String, String>{};
      for (final e in _elementosSeleccionados) {
        final t = _getTallaController(e).text.trim();
        if (t.isNotEmpty) tallasPorElemento[e] = t;
      }
      final tallaResumen = tallasPorElemento.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');

      await fs.crearOferta(
        cofradeId: auth.cofrade?.id ?? '',
        nombrePublicador:
            '${auth.cofrade?.nombre ?? ''} ${auth.cofrade?.apellidos ?? ''}'
                .trim(),
        telefonoPublicador: _telefonoController.text.trim(),
        elementos: _elementosSeleccionados.toList(),
        talla: tallaResumen,
        tallasPorElemento: tallasPorElemento,
        estadoConservacion: _estadoConservacion,
        observaciones: _observacionesController.text.trim(),
        propiedad: _propiedad,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oferta publicada correctamente')),
        );
        context.go('/banco-tunicas');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al publicar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isAdmin = auth.isAdmin;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppTheme.primaryDark, AppTheme.primaryColor]),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.go('/banco-tunicas'),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.add_circle_outline,
                        color: Colors.white, size: 26),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Publicar Oferta',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Elementos que ofreces *',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kElementosHabito.map((e) {
                          final selected = _elementosSeleccionados.contains(e);
                          return FilterChip(
                            label: Text(e),
                            avatar: Icon(kElementoIcons[e] ?? Icons.checkroom,
                                size: 18),
                            selected: selected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _elementosSeleccionados.add(e);
                                } else {
                                  _elementosSeleccionados.remove(e);
                                }
                              });
                            },
                            selectedColor: AppTheme.accentColor.withAlpha(30),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      if (_elementosSeleccionados.isNotEmpty) ...[
                        const Text('Talla / Medidas por elemento',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        ..._elementosSeleccionados.map((elemento) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: TextFormField(
                                controller: _getTallaController(elemento),
                                decoration: InputDecoration(
                                  labelText: 'Talla de $elemento',
                                  hintText: 'Ej: M, 42, 1.75m...',
                                  prefixIcon: Icon(
                                      kElementoIcons[elemento] ??
                                          Icons.straighten,
                                      size: 20),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            )),
                        const SizedBox(height: 6),
                      ],
                      DropdownButtonFormField<String>(
                        value: _estadoConservacion,
                        decoration: const InputDecoration(
                          labelText: 'Estado de conservaci\u00f3n *',
                          prefixIcon: Icon(Icons.star_outline),
                          border: OutlineInputBorder(),
                        ),
                        items: _estadosConservacion
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _estadoConservacion = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      if (isAdmin) ...[
                        DropdownButtonFormField<String>(
                          value: _propiedad,
                          decoration: const InputDecoration(
                            labelText: 'Propiedad',
                            prefixIcon: Icon(Icons.business),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'particular',
                                child: Text('Particular (usuario)')),
                            DropdownMenuItem(
                                value: 'cofradia',
                                child: Text('Cofrad\u00eda')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _propiedad = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _telefonoController,
                        decoration: const InputDecoration(
                          labelText: 'Tel\u00e9fono de contacto *',
                          hintText: '600123456',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'El tel\u00e9fono es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _observacionesController,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones',
                          hintText:
                              'Detalles adicionales sobre los elementos...',
                          prefixIcon: Icon(Icons.notes),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _publicar,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.publish),
                          label: Text(
                              _isLoading ? 'Publicando...' : 'Publicar Oferta'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
