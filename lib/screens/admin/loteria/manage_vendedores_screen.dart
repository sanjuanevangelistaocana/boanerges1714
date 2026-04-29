import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/loteria.dart';
import 'package:boanerges1714/models/cofrade.dart';

class ManageVendedoresLoteriaScreen extends StatelessWidget {
  const ManageVendedoresLoteriaScreen({super.key});

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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Vendedores de Lotería',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showVendedorDialog(context, fs),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Añadir Vendedor'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor),
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
                constraints: const BoxConstraints(maxWidth: 1000),
                child: StreamBuilder<List<VendedorLoteria>>(
                  stream: fs.getVendedoresLoteria(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final vendedores = snapshot.data ?? [];
                    if (vendedores.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                              child: Text('No hay vendedores registrados.')),
                        ),
                      );
                    }

                    final cofrades =
                        vendedores.where((v) => v.isCofrade).length;
                    final externos = vendedores.length - cofrades;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _MiniStat(
                                    value: '${vendedores.length}',
                                    label: 'Total',
                                    color: AppTheme.primaryColor),
                                _MiniStat(
                                    value: '$cofrades',
                                    label: 'Cofrades',
                                    color: AppTheme.accentColor),
                                _MiniStat(
                                    value: '$externos',
                                    label: 'Externos',
                                    color: Colors.orange.shade700),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...vendedores.map((v) => Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side:
                                      BorderSide(color: Colors.grey.shade200)),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (v.isCofrade
                                            ? AppTheme.accentColor
                                            : Colors.orange.shade700)
                                        .withAlpha(20),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    v.isCofrade ? Icons.person : Icons.store,
                                    color: v.isCofrade
                                        ? AppTheme.accentColor
                                        : Colors.orange.shade700,
                                  ),
                                ),
                                title: Text(v.nombre,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${v.isCofrade ? "Cofrade" : "Externo"}${v.telefono.isNotEmpty ? ' · ${v.telefono}' : ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    if (action == 'edit') {
                                      _showVendedorDialog(context, fs,
                                          vendedor: v);
                                    } else if (action == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title:
                                              const Text('Eliminar vendedor'),
                                          content: const Text(
                                              '¿Seguro? Se eliminarán también sus asignaciones.'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancelar')),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Eliminar',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true)
                                        await fs.deleteVendedorLoteria(v.id);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                        value: 'edit', child: Text('Editar')),
                                    const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Eliminar',
                                            style:
                                                TextStyle(color: Colors.red))),
                                  ],
                                ),
                              ),
                            )),
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

  void _showVendedorDialog(BuildContext context, FirestoreService fs,
      {VendedorLoteria? vendedor}) {
    final isEdit = vendedor != null;
    final nombreCtrl = TextEditingController(text: vendedor?.nombre ?? '');
    final telefonoCtrl = TextEditingController(text: vendedor?.telefono ?? '');
    final contactoCtrl = TextEditingController(text: vendedor?.contacto ?? '');
    final direccionCtrl =
        TextEditingController(text: vendedor?.direccion ?? '');
    final mapsCtrl = TextEditingController(text: vendedor?.mapsUrl ?? '');
    final logoCtrl = TextEditingController(text: vendedor?.logoUrl ?? '');
    final observacionesCtrl =
        TextEditingController(text: vendedor?.observaciones ?? '');
    String tipo = vendedor?.tipo ?? 'cofrade';
    String? selectedCofradeId = vendedor?.cofradeId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isEdit ? 'Editar Vendedor' : 'Nuevo Vendedor'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'cofrade', child: Text('Cofrade')),
                    DropdownMenuItem(
                        value: 'externo',
                        child: Text('Externo (establecimiento)')),
                  ],
                  onChanged: (v) => setState(() {
                    tipo = v ?? 'cofrade';
                    if (tipo == 'externo') selectedCofradeId = null;
                  }),
                ),
                const SizedBox(height: 12),
                if (tipo == 'cofrade')
                  FutureBuilder<List<Cofrade>>(
                    future: fs.searchCofrades(''),
                    builder: (context, snap) {
                      final cofrades = snap.data ?? [];
                      return Autocomplete<Cofrade>(
                        optionsBuilder: (textEditingValue) {
                          final query = textEditingValue.text.toLowerCase();
                          if (query.isEmpty) return cofrades.take(20);
                          return cofrades.where((c) =>
                              c.nombreCompleto.toLowerCase().contains(query));
                        },
                        displayStringForOption: (c) => c.nombreCompleto,
                        onSelected: (c) async {
                          selectedCofradeId = c.id;
                          nombreCtrl.text = c.nombreCompleto;
                          final full = await fs.getCofrade(c.id);
                          telefonoCtrl.text =
                              full?.telefonoMovil.isNotEmpty == true
                                  ? full!.telefonoMovil
                                  : full?.telefonoFijo ?? '';
                        },
                        fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
                          if (ctrl.text.isEmpty && nombreCtrl.text.isNotEmpty) {
                            ctrl.text = nombreCtrl.text;
                          }
                          return TextField(
                            controller: ctrl,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Buscar cofrade',
                              prefixIcon: Icon(Icons.search),
                            ),
                          );
                        },
                      );
                    },
                  )
                else
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nombre', hintText: 'Ej: Bar Pepe'),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: telefonoCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Teléfono', prefixIcon: Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                ),
                if (tipo == 'externo') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactoCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Persona de contacto'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: direccionCtrl,
                    decoration: const InputDecoration(labelText: 'Dirección'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mapsCtrl,
                    decoration: const InputDecoration(
                        labelText: 'URL Google Maps',
                        hintText: 'https://maps.google.com/...'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: logoCtrl,
                    decoration:
                        const InputDecoration(labelText: 'URL logo (opcional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: observacionesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Observaciones'),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                if (nombre.isEmpty) return;
                final mapsUrl = mapsCtrl.text.trim();
                final mapsUri = Uri.tryParse(mapsUrl);
                if (tipo == 'externo' &&
                    mapsUrl.isNotEmpty &&
                    (mapsUri == null ||
                        !mapsUri.hasScheme ||
                        !mapsUrl.toLowerCase().contains('map'))) {
                  return;
                }

                if (isEdit) {
                  await fs.updateVendedorLoteria(vendedor.id, {
                    'tipo': tipo,
                    'nombre': nombre,
                    'telefono': telefonoCtrl.text.trim(),
                    'cofrade_id': tipo == 'cofrade' ? selectedCofradeId : null,
                    'contacto':
                        tipo == 'externo' ? contactoCtrl.text.trim() : '',
                    'direccion':
                        tipo == 'externo' ? direccionCtrl.text.trim() : '',
                    'maps_url': tipo == 'externo' ? mapsUrl : '',
                    'logo_url': tipo == 'externo' ? logoCtrl.text.trim() : '',
                    'observaciones':
                        tipo == 'externo' ? observacionesCtrl.text.trim() : '',
                  });
                } else {
                  await fs.createVendedorLoteria(VendedorLoteria(
                    id: '',
                    tipo: tipo,
                    nombre: nombre,
                    telefono: telefonoCtrl.text.trim(),
                    cofradeId: tipo == 'cofrade' ? selectedCofradeId : null,
                    contacto: tipo == 'externo' ? contactoCtrl.text.trim() : '',
                    direccion:
                        tipo == 'externo' ? direccionCtrl.text.trim() : '',
                    mapsUrl: tipo == 'externo' ? mapsUrl : '',
                    logoUrl: tipo == 'externo' ? logoCtrl.text.trim() : '',
                    observaciones:
                        tipo == 'externo' ? observacionesCtrl.text.trim() : '',
                  ));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isEdit ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MiniStat(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
