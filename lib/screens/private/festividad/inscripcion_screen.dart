import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/cofrade.dart';

class InscripcionFestividadScreen extends StatefulWidget {
  final String edicionId;
  final String? inscripcionId;
  const InscripcionFestividadScreen({super.key, required this.edicionId, this.inscripcionId});

  @override
  State<InscripcionFestividadScreen> createState() => _InscripcionFestividadScreenState();
}

class _InscripcionFestividadScreenState extends State<InscripcionFestividadScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _edicion;
  List<Map<String, dynamic>> _menus = [];
  List<_AsistenteData> _asistentes = [];
  bool _isEdit = false;
  String? _existingInscId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final fs = context.read<FirestoreService>();
    final auth = context.read<AuthService>();
    final cofrade = auth.cofrade;

    final edicion = await fs.getFestividadEdicion(widget.edicionId);
    final menusSnap = await fs.getFestividadMenus(widget.edicionId).first;
    final activeMenus = menusSnap.where((m) => m['activo'] == true).toList();

    if (widget.inscripcionId != null) {
      _isEdit = true;
      _existingInscId = widget.inscripcionId;
      final allInsc = await fs.getFestividadInscripciones(widget.edicionId).first;
      final existing = allInsc.where((i) => i['id'] == widget.inscripcionId).toList();
      if (existing.isNotEmpty) {
        final data = existing.first;
        final asistentes = List<Map<String, dynamic>>.from(
            (data['asistentes'] as List<dynamic>?) ?? []);
        _asistentes = asistentes.map((a) => _AsistenteData.fromMap(a)).toList();
      }
    } else if (cofrade != null) {
      final yaInscrito = await fs.isCofradeInscritoFestividad(widget.edicionId, cofrade.id);
      if (yaInscrito && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
              'Ya figuras inscrito/a en esta edición de la Festividad San Juan Evangelista dentro de otra inscripción. '
              'Si necesitas modificarlo, contacta con la persona que realizó la inscripción o con la administración.')),
        );
        context.pop(false);
        return;
      }
      _asistentes.add(_AsistenteData(
        nombre: cofrade.nombre,
        apellidos: cofrade.apellidos,
        tipo: 'hermano',
        cofradeId: cofrade.id,
        isCurrentUser: true,
      ));
    }

    if (mounted) {
      setState(() {
        _edicion = edicion;
        _menus = activeMenus;
        _loading = false;
      });
    }
  }

  double _precioAsistente(_AsistenteData a) {
    if (_edicion == null) return 0;
    final precioHermano = (_edicion!['precio_hermano'] as num?)?.toDouble() ?? 5.0;
    final precioInvitado = (_edicion!['precio_invitado'] as num?)?.toDouble() ?? 27.0;

    double base;
    switch (a.tipo) {
      case 'hermano': base = precioHermano; break;
      case 'protocolo': base = 0; break;
      default: base = precioInvitado;
    }

    double extra = 0;
    if (a.menuId != null) {
      final menu = _menus.where((m) => m['id'] == a.menuId).toList();
      if (menu.isNotEmpty) {
        extra = (menu.first['precio_extra'] as num?)?.toDouble() ?? 0;
      }
    }
    return base + extra;
  }

  double get _totalPagar {
    double total = 0;
    for (final a in _asistentes) {
      total += _precioAsistente(a);
    }
    return total;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_asistentes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debe haber al menos un asistente.')));
      return;
    }
    for (final a in _asistentes) {
      if (a.menuId == null || a.menuId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Todos los asistentes deben tener un menú seleccionado.')));
        return;
      }
    }

    setState(() => _saving = true);
    final fs = context.read<FirestoreService>();
    final auth = context.read<AuthService>();
    final cofrade = auth.cofrade;

    final asistentesData = _asistentes.map((a) {
      final menuNombre = _menus.where((m) => m['id'] == a.menuId).toList();
      return {
        'nombre': a.nombre,
        'apellidos': a.apellidos,
        'tipo': a.tipo,
        'cofrade_id': a.cofradeId ?? '',
        'menu_id': a.menuId ?? '',
        'menu_nombre': menuNombre.isNotEmpty ? menuNombre.first['nombre'] ?? '' : '',
        'alergias': a.alergiasCtrl.text.trim(),
        'observaciones': a.observacionesCtrl.text.trim(),
        'telefono': a.telefonoCtrl.text.trim(),
        'cargo': a.cargoCtrl.text.trim(),
        'precio_aplicado': _precioAsistente(a),
      };
    }).toList();

    final data = <String, dynamic>{
      'cofrade_id': cofrade?.id ?? '',
      'cofrade_nombre': cofrade?.nombreCompleto ?? '',
      'asistentes': asistentesData,
      'total': _totalPagar,
      'estado': 'pendiente',
      'payment_status': 'pendiente',
    };

    try {
      if (_isEdit && _existingInscId != null) {
        await fs.updateFestividadInscripcion(widget.edicionId, _existingInscId!, data);
      } else {
        await fs.createFestividadInscripcion(widget.edicionId, data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isEdit ? 'Inscripción actualizada' : 'Inscripción creada correctamente')));
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addAcompanante(String tipo) {
    setState(() {
      _asistentes.add(_AsistenteData(tipo: tipo));
    });
  }

  void _removeAsistente(int index) {
    if (_asistentes[index].isCurrentUser) return;
    setState(() => _asistentes.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_edicion == null) {
      return Scaffold(
        body: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se encontró la edición del evento.'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => context.pop(), child: const Text('Volver')),
          ],
        )),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryDark, AppTheme.primaryColor],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Editar inscripción' : 'Inscripción',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Asistentes list
                    ..._asistentes.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final a = entry.value;
                      return _AsistenteCard(
                        index: idx,
                        data: a,
                        menus: _menus,
                        edicion: _edicion!,
                        precio: _precioAsistente(a),
                        onRemove: a.isCurrentUser ? null : () => _removeAsistente(idx),
                        onChanged: () => setState(() {}),
                        fs: context.read<FirestoreService>(),
                        edicionId: widget.edicionId,
                      );
                    }),
                    const SizedBox(height: 16),
                    // Add companion buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddCompanionDialog(),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Añadir acompañante'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Summary card
                    Card(
                      elevation: 0,
                      color: AppTheme.primaryColor.withAlpha(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppTheme.primaryColor.withAlpha(40)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Resumen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Divider(height: 24),
                            _SummaryRow(label: 'Nº asistentes', value: '${_asistentes.length}'),
                            _SummaryRow(label: 'Hermanos/as',
                                value: '${_asistentes.where((a) => a.tipo == "hermano").length}'),
                            _SummaryRow(label: 'Invitados/as',
                                value: '${_asistentes.where((a) => a.tipo == "invitado").length}'),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total a pagar',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('${_totalPagar.toStringAsFixed(2)} €',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                        color: AppTheme.primaryColor)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _guardar,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_isEdit ? 'Actualizar inscripción' : 'Confirmar inscripción'),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCompanionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tipo de acompañante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: AppTheme.accentColor),
              title: const Text('Hermano/a'),
              subtitle: const Text('Cofrade registrado'),
              onTap: () { Navigator.pop(ctx); _addAcompanante('hermano'); },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppTheme.primaryColor),
              title: const Text('Invitado/a no hermano/a'),
              subtitle: const Text('Persona externa'),
              onTap: () { Navigator.pop(ctx); _addAcompanante('invitado'); },
            ),
          ],
        ),
      ),
    );
  }
}

class _AsistenteData {
  String nombre;
  String apellidos;
  String tipo;
  String? cofradeId;
  String? menuId;
  bool isCurrentUser;
  final TextEditingController alergiasCtrl;
  final TextEditingController observacionesCtrl;
  final TextEditingController telefonoCtrl;
  final TextEditingController cargoCtrl;

  _AsistenteData({
    this.nombre = '',
    this.apellidos = '',
    this.tipo = 'invitado',
    this.cofradeId,
    this.menuId,
    this.isCurrentUser = false,
    String alergias = '',
    String observaciones = '',
    String telefono = '',
    String cargo = '',
  })  : alergiasCtrl = TextEditingController(text: alergias),
        observacionesCtrl = TextEditingController(text: observaciones),
        telefonoCtrl = TextEditingController(text: telefono),
        cargoCtrl = TextEditingController(text: cargo);

  factory _AsistenteData.fromMap(Map<String, dynamic> m) {
    return _AsistenteData(
      nombre: m['nombre'] ?? '',
      apellidos: m['apellidos'] ?? '',
      tipo: m['tipo'] ?? 'invitado',
      cofradeId: m['cofrade_id'] as String?,
      menuId: m['menu_id'] as String?,
      alergias: m['alergias'] ?? '',
      observaciones: m['observaciones'] ?? '',
      telefono: m['telefono'] ?? '',
      cargo: m['cargo'] ?? '',
    );
  }
}

class _AsistenteCard extends StatefulWidget {
  final int index;
  final _AsistenteData data;
  final List<Map<String, dynamic>> menus;
  final Map<String, dynamic> edicion;
  final double precio;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;
  final FirestoreService fs;
  final String edicionId;

  const _AsistenteCard({
    required this.index,
    required this.data,
    required this.menus,
    required this.edicion,
    required this.precio,
    this.onRemove,
    required this.onChanged,
    required this.fs,
    required this.edicionId,
  });

  @override
  State<_AsistenteCard> createState() => _AsistenteCardState();
}

class _AsistenteCardState extends State<_AsistenteCard> {
  List<Cofrade> _searchResults = [];
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final a = widget.data;
    final isHermano = a.tipo == 'hermano';
    final isProtocolo = a.tipo == 'protocolo';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHermano ? AppTheme.accentColor.withAlpha(60)
              : isProtocolo ? Colors.purple.withAlpha(60)
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  isHermano ? Icons.person : isProtocolo ? Icons.stars : Icons.person_outline,
                  color: isHermano ? AppTheme.accentColor
                      : isProtocolo ? Colors.purple : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.isCurrentUser
                        ? '${a.nombre} ${a.apellidos} (Tú)'
                        : a.nombre.isEmpty
                            ? 'Acompañante ${widget.index + 1}'
                            : '${a.nombre} ${a.apellidos}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Text('${widget.precio.toStringAsFixed(2)} €',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
                if (widget.onRemove != null)
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red.shade400, size: 20),
                    onPressed: widget.onRemove,
                    tooltip: 'Eliminar',
                  ),
              ],
            ),
            const Divider(height: 20),
            // Name fields (for hermano = cofrade search, for invitado = manual)
            if (isHermano && !a.isCurrentUser) ...[
              _buildCofradeSearch(),
            ] else if (!a.isCurrentUser) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: a.nombre,
                      decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null,
                      onChanged: (v) { a.nombre = v; widget.onChanged(); },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: a.apellidos,
                      decoration: const InputDecoration(labelText: 'Apellidos', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null,
                      onChanged: (v) { a.apellidos = v; widget.onChanged(); },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: a.telefonoCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
            ],
            if (isProtocolo && !a.isCurrentUser) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: a.nombre,
                      decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null,
                      onChanged: (v) { a.nombre = v; widget.onChanged(); },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: a.apellidos,
                      decoration: const InputDecoration(labelText: 'Apellidos', border: OutlineInputBorder()),
                      onChanged: (v) { a.apellidos = v; widget.onChanged(); },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: a.cargoCtrl,
                      decoration: const InputDecoration(labelText: 'Cargo/Representación (opcional)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: a.telefonoCtrl,
                      decoration: const InputDecoration(labelText: 'Teléfono (opcional)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Menu selection
            DropdownButtonFormField<String>(
              value: a.menuId != null && widget.menus.any((m) => m['id'] == a.menuId) ? a.menuId : null,
              decoration: const InputDecoration(labelText: 'Menú *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.isEmpty ? 'Selecciona un menú' : null,
              items: widget.menus.map((m) {
                final extra = (m['precio_extra'] as num?)?.toDouble() ?? 0;
                return DropdownMenuItem<String>(
                  value: m['id'] as String,
                  child: Text('${m['nombre']}${extra > 0 ? " (+${extra.toStringAsFixed(2)} €)" : ""}'),
                );
              }).toList(),
              onChanged: (v) {
                a.menuId = v;
                widget.onChanged();
              },
            ),
            const SizedBox(height: 12),
            // Allergies
            TextFormField(
              controller: a.alergiasCtrl,
              decoration: const InputDecoration(
                labelText: 'Alergias alimentarias',
                border: OutlineInputBorder(),
                helperText: 'Indica cualquier alergia o intolerancia alimentaria de forma clara y específica '
                    'para que el restaurante pueda tomar las precauciones adecuadas.',
                helperMaxLines: 3,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            // Observations
            TextFormField(
              controller: a.observacionesCtrl,
              decoration: const InputDecoration(
                labelText: 'Observaciones (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCofradeSearch() {
    final a = widget.data;
    if (a.cofradeId != null && a.cofradeId!.isNotEmpty && a.nombre.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${a.nombre} ${a.apellidos}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    a.nombre = '';
                    a.apellidos = '';
                    a.cofradeId = null;
                    _searchCtrl.clear();
                    _searchResults = [];
                  });
                  widget.onChanged();
                },
                child: const Text('Cambiar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            labelText: 'Buscar hermano/a por nombre',
            border: const OutlineInputBorder(),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const Icon(Icons.search),
          ),
          validator: (_) => a.cofradeId == null || a.cofradeId!.isEmpty ? 'Selecciona un hermano/a' : null,
          onChanged: (v) async {
            if (v.trim().length < 2) {
              setState(() => _searchResults = []);
              return;
            }
            setState(() => _searching = true);
            try {
              final results = await widget.fs.searchCofrades(v);
              if (mounted) setState(() { _searchResults = results; _searching = false; });
            } catch (e) {
              if (mounted) setState(() => _searching = false);
            }
          },
        ),
        if (_searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, idx) {
                final c = _searchResults[idx];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.accentColor.withAlpha(20),
                    child: Text(c.nombre.isNotEmpty ? c.nombre[0] : '?',
                        style: const TextStyle(color: AppTheme.accentColor, fontSize: 14)),
                  ),
                  title: Text('${c.nombre} ${c.apellidos}', style: const TextStyle(fontSize: 14)),
                  subtitle: c.numero != null ? Text('Nº ${c.numero}', style: const TextStyle(fontSize: 12)) : null,
                  onTap: () async {
                    final yaInscrito = await widget.fs.isCofradeInscritoFestividad(widget.edicionId, c.id);
                    if (yaInscrito && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Este hermano/a ya figura inscrito/a en esta edición.')),
                      );
                      return;
                    }
                    setState(() {
                      a.nombre = c.nombre;
                      a.apellidos = c.apellidos;
                      a.cofradeId = c.id;
                      _searchResults = [];
                      _searchCtrl.text = '${c.nombre} ${c.apellidos}';
                    });
                    widget.onChanged();
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
