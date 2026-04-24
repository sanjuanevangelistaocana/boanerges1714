import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/cofrade.dart';

class ManageCofradesScreen extends StatefulWidget {
  const ManageCofradesScreen({super.key});

  @override
  State<ManageCofradesScreen> createState() => _ManageCofradesScreenState();
}

class _ManageCofradesScreenState extends State<ManageCofradesScreen> {
  String _filtroEstado = 'todos';
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gestión de Cofrades',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            // Filters
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
                  ),
                ),
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _filtroEstado == 'todos',
                  onSelected: (_) => setState(() => _filtroEstado = 'todos'),
                ),
                ChoiceChip(
                  label: const Text('Activos'),
                  selected: _filtroEstado == 'activo',
                  onSelected: (_) => setState(() => _filtroEstado = 'activo'),
                ),
                ChoiceChip(
                  label: const Text('Pendientes'),
                  selected: _filtroEstado == 'pendiente',
                  onSelected: (_) =>
                      setState(() => _filtroEstado = 'pendiente'),
                ),
                ChoiceChip(
                  label: const Text('Baja'),
                  selected: _filtroEstado == 'baja',
                  onSelected: (_) => setState(() => _filtroEstado = 'baja'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Cofrade>>(
              stream: firestoreService.getCofrades(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var cofrades = snapshot.data ?? [];

                // Apply filters
                if (_filtroEstado != 'todos') {
                  cofrades = cofrades
                      .where((c) => c.estado == _filtroEstado)
                      .toList();
                }
                if (_busqueda.isNotEmpty) {
                  cofrades = cofrades
                      .where((c) =>
                          c.nombreCompleto.toLowerCase().contains(_busqueda))
                      .toList();
                }

                if (cofrades.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No se encontraron cofrades.')),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cofrades.length,
                  itemBuilder: (context, index) {
                    final cofrade = cofrades[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(cofrade.estado),
                          child: Text(
                            cofrade.nombre.isNotEmpty
                                ? cofrade.nombre[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(cofrade.nombreCompleto),
                        subtitle: Text(
                          '${cofrade.email} · Nº ${cofrade.numero ?? "-"}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              tooltip: 'Editar cofrade',
                              onPressed: () => _showEditCofradeDialog(cofrade),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) =>
                                  _handleAction(action, cofrade),
                              itemBuilder: (context) => [
                                if (cofrade.estado == 'Pendiente' ||
                                    cofrade.estado == 'pendiente')
                                  const PopupMenuItem(
                                    value: 'aprobar',
                                    child: ListTile(
                                      leading: Icon(Icons.check, color: Colors.green),
                                      title: Text('Aprobar'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                if (!cofrade.isBaja)
                                  const PopupMenuItem(
                                    value: 'baja',
                                    child: ListTile(
                                      leading: Icon(Icons.block, color: Colors.red),
                                      title: Text('Dar de baja'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                if (cofrade.isBaja)
                                  const PopupMenuItem(
                                    value: 'reactivar',
                                    child: ListTile(
                                      leading:
                                          Icon(Icons.refresh, color: Colors.blue),
                                      title: Text('Reactivar'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                if (!cofrade.isAdmin)
                                  const PopupMenuItem(
                                    value: 'hacer_admin',
                                    child: ListTile(
                                      leading: Icon(Icons.admin_panel_settings,
                                          color: AppTheme.primaryColor),
                                      title: Text('Hacer admin'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'baja':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showEditCofradeDialog(Cofrade cofrade) {
    final nombreC = TextEditingController(text: cofrade.nombre);
    final apellidosC = TextEditingController(text: cofrade.apellidos);
    final emailC = TextEditingController(text: cofrade.email);
    final emailSecC = TextEditingController(text: cofrade.emailSecundario ?? '');
    final dniC = TextEditingController(text: cofrade.dni ?? '');
    final telefonoMovilC = TextEditingController(text: cofrade.telefonoMovil);
    final telefonoFijoC = TextEditingController(text: cofrade.telefonoFijo);
    final telefonoSecC = TextEditingController(text: cofrade.telefonoSecundario ?? '');
    final domicilioC = TextEditingController(text: cofrade.domicilio);
    final localidadC = TextEditingController(text: cofrade.localidad);
    final codigoPostalC = TextEditingController(text: cofrade.codigoPostal);
    final ibanC = TextEditingController(text: cofrade.iban ?? '');
    final titularIbanC = TextEditingController(text: cofrade.titularIban ?? '');
    final comentariosC = TextEditingController(text: cofrade.comentarios ?? '');
    final numeroC = TextEditingController(text: cofrade.numero?.toString() ?? '');
    final estaturaC = TextEditingController(text: cofrade.estatura?.toString() ?? '');
    final anioAltaC = TextEditingController(text: cofrade.anioAlta?.toString() ?? '');
    final aniosHermandadC = TextEditingController(text: cofrade.aniosHermandad?.toString() ?? '');
    final anioMayordomiaC = TextEditingController(text: cofrade.anioMayordomia?.toString() ?? '');
    final cargoC = TextEditingController(text: cofrade.cargo ?? '');
    final dniTutorC = TextEditingController(text: cofrade.dniTutor ?? '');
    final parentescoTutorC = TextEditingController(text: cofrade.parentescoTutor ?? '');
    final tuteladoDigitalC = TextEditingController(text: cofrade.tuteladoDigital ?? '');
    final causaBajaC = TextEditingController(text: cofrade.causaBaja ?? '');

    String estado = cofrade.estado;
    String genero = cofrade.genero ?? '';
    String talla = cofrade.talla ?? '';
    String rol = cofrade.rol;
    bool tieneCuota = cofrade.tieneCuota;
    bool cuotaMetalico = cofrade.cuotaMetalico;
    bool cuotaDomiciliada = cofrade.cuotaDomiciliada;
    bool gdprFirmado = cofrade.gdprFirmado;
    bool gdprFirmadoDigital = cofrade.gdprFirmadoDigital;
    bool tieneTunicaPropia = cofrade.tieneTunicaPropia;
    bool notificacionesActivas = cofrade.notificacionesActivas;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Editar: ${cofrade.nombreCompleto}'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Datos personales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  TextField(controller: numeroC, decoration: const InputDecoration(labelText: 'N\u00famero de cofrade'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextField(controller: nombreC, decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 8),
                  TextField(controller: apellidosC, decoration: const InputDecoration(labelText: 'Apellidos')),
                  const SizedBox(height: 8),
                  TextField(controller: dniC, decoration: const InputDecoration(labelText: 'DNI')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: genero.isNotEmpty ? genero : null,
                    decoration: const InputDecoration(labelText: 'G\u00e9nero'),
                    items: const [
                      DropdownMenuItem(value: 'H', child: Text('Hombre')),
                      DropdownMenuItem(value: 'M', child: Text('Mujer')),
                    ],
                    onChanged: (v) => setDialogState(() => genero = v ?? ''),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: estaturaC, decoration: const InputDecoration(labelText: 'Estatura (cm)'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: talla.isNotEmpty ? talla : null,
                    decoration: const InputDecoration(labelText: 'Talla'),
                    items: const [
                      DropdownMenuItem(value: 'XS', child: Text('XS')),
                      DropdownMenuItem(value: 'S', child: Text('S')),
                      DropdownMenuItem(value: 'M', child: Text('M')),
                      DropdownMenuItem(value: 'L', child: Text('L')),
                      DropdownMenuItem(value: 'XL', child: Text('XL')),
                      DropdownMenuItem(value: 'XXL', child: Text('XXL')),
                    ],
                    onChanged: (v) => setDialogState(() => talla = v ?? ''),
                  ),
                  const Divider(height: 28),
                  const Text('Contacto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 8),
                  TextField(controller: emailSecC, decoration: const InputDecoration(labelText: 'Email secundario')),
                  const SizedBox(height: 8),
                  TextField(controller: telefonoMovilC, decoration: const InputDecoration(labelText: 'Tel\u00e9fono m\u00f3vil')),
                  const SizedBox(height: 8),
                  TextField(controller: telefonoFijoC, decoration: const InputDecoration(labelText: 'Tel\u00e9fono fijo')),
                  const SizedBox(height: 8),
                  TextField(controller: telefonoSecC, decoration: const InputDecoration(labelText: 'Tel\u00e9fono secundario')),
                  const SizedBox(height: 8),
                  TextField(controller: domicilioC, decoration: const InputDecoration(labelText: 'Domicilio')),
                  const SizedBox(height: 8),
                  TextField(controller: localidadC, decoration: const InputDecoration(labelText: 'Localidad')),
                  const SizedBox(height: 8),
                  TextField(controller: codigoPostalC, decoration: const InputDecoration(labelText: 'C\u00f3digo postal')),
                  const Divider(height: 28),
                  const Text('Cofrad\u00eda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: estado,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'Activo', child: Text('Activo')),
                      DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente')),
                      DropdownMenuItem(value: 'Baja', child: Text('Baja')),
                    ],
                    onChanged: (v) => setDialogState(() => estado = v ?? 'Activo'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: rol,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: const [
                      DropdownMenuItem(value: 'cofrade', child: Text('Cofrade')),
                      DropdownMenuItem(value: 'junta', child: Text('Junta')),
                      DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                    ],
                    onChanged: (v) => setDialogState(() => rol = v ?? 'cofrade'),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: cargoC, decoration: const InputDecoration(labelText: 'Cargo')),
                  const SizedBox(height: 8),
                  TextField(controller: anioAltaC, decoration: const InputDecoration(labelText: 'A\u00f1o de alta'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextField(controller: aniosHermandadC, decoration: const InputDecoration(labelText: 'A\u00f1os de hermandad'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextField(controller: anioMayordomiaC, decoration: const InputDecoration(labelText: 'A\u00f1o de mayordom\u00eda'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextField(controller: causaBajaC, decoration: const InputDecoration(labelText: 'Causa de baja')),
                  const Divider(height: 28),
                  const Text('Econom\u00eda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  TextField(controller: ibanC, decoration: const InputDecoration(labelText: 'IBAN')),
                  const SizedBox(height: 8),
                  TextField(controller: titularIbanC, decoration: const InputDecoration(labelText: 'Titular IBAN')),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Tiene cuota'),
                    value: tieneCuota,
                    onChanged: (v) => setDialogState(() => tieneCuota = v),
                    dense: true, contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Cuota en met\u00e1lico'),
                    value: cuotaMetalico,
                    onChanged: (v) => setDialogState(() => cuotaMetalico = v),
                    dense: true, contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Cuota domiciliada'),
                    value: cuotaDomiciliada,
                    onChanged: (v) => setDialogState(() => cuotaDomiciliada = v),
                    dense: true, contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 28),
                  const Text('GDPR y T\u00fanica', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('GDPR firmado (papel)'),
                    value: gdprFirmado,
                    onChanged: (v) => setDialogState(() => gdprFirmado = v),
                    dense: true, contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('GDPR firmado (digital)'),
                    value: gdprFirmadoDigital,
                    onChanged: (v) => setDialogState(() => gdprFirmadoDigital = v),
                    dense: true, contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Tiene t\u00fanica propia'),
                    value: tieneTunicaPropia,
                    onChanged: (v) => setDialogState(() => tieneTunicaPropia = v),
                    dense: true, contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 28),
                  const Text('Tutela', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  TextField(controller: tuteladoDigitalC, decoration: const InputDecoration(labelText: 'Email tutor (tutelado digital)')),
                  const SizedBox(height: 8),
                  TextField(controller: dniTutorC, decoration: const InputDecoration(labelText: 'DNI del tutor')),
                  const SizedBox(height: 8),
                  TextField(controller: parentescoTutorC, decoration: const InputDecoration(labelText: 'Parentesco del tutor')),
                  const Divider(height: 28),
                  const Text('Otros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Notificaciones activas'),
                    value: notificacionesActivas,
                    onChanged: (v) => setDialogState(() => notificacionesActivas = v),
                    dense: true, contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: comentariosC, decoration: const InputDecoration(labelText: 'Comentarios'), maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final data = <String, dynamic>{
                    'nombre': nombreC.text.trim(),
                    'apellidos': apellidosC.text.trim(),
                    'email': emailC.text.trim(),
                    'email_secundario': emailSecC.text.trim(),
                    'dni': dniC.text.trim().toUpperCase(),
                    'genero': genero,
                    'estatura': int.tryParse(estaturaC.text.trim()),
                    'talla': talla,
                    'telefono_movil': telefonoMovilC.text.trim(),
                    'telefono_fijo': telefonoFijoC.text.trim(),
                    'telefono_secundario': telefonoSecC.text.trim(),
                    'domicilio': domicilioC.text.trim(),
                    'localidad': localidadC.text.trim(),
                    'codigo_postal': codigoPostalC.text.trim(),
                    'estado': estado,
                    'rol': rol,
                    'cargo': cargoC.text.trim(),
                    'anio_alta': int.tryParse(anioAltaC.text.trim()),
                    'anios_hermandad': int.tryParse(aniosHermandadC.text.trim()),
                    'anio_mayordomia': int.tryParse(anioMayordomiaC.text.trim()),
                    'causa_baja': causaBajaC.text.trim(),
                    'numero': int.tryParse(numeroC.text.trim()),
                    'iban': ibanC.text.trim(),
                    'titular_iban': titularIbanC.text.trim(),
                    'tiene_cuota': tieneCuota,
                    'cuota_metalico': cuotaMetalico,
                    'cuota_domiciliada': cuotaDomiciliada,
                    'gdpr_firmado': gdprFirmado,
                    'gdpr_firmado_digital': gdprFirmadoDigital,
                    'tiene_tunica_propia': tieneTunicaPropia,
                    'tutelado_digital': tuteladoDigitalC.text.trim(),
                    'dni_tutor': dniTutorC.text.trim(),
                    'parentesco_tutor': parentescoTutorC.text.trim(),
                    'notificaciones_activas': notificacionesActivas,
                    'comentarios': comentariosC.text.trim(),
                  };
                  await context.read<FirestoreService>().updateCofrade(cofrade.id, data);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${cofrade.nombreCompleto} actualizado.')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(String action, Cofrade cofrade) async {
    final firestoreService = context.read<FirestoreService>();

    switch (action) {
      case 'aprobar':
        await firestoreService
            .updateCofrade(cofrade.id, {'estado': 'Activo'});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${cofrade.nombreCompleto} aprobado.')),
          );
        }
        break;
      case 'baja':
        await firestoreService
            .updateCofrade(cofrade.id, {'estado': 'Baja'});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${cofrade.nombreCompleto} dado de baja.')),
          );
        }
        break;
      case 'reactivar':
        await firestoreService
            .updateCofrade(cofrade.id, {'estado': 'Activo'});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${cofrade.nombreCompleto} reactivado.')),
          );
        }
        break;
      case 'hacer_admin':
        await firestoreService
            .updateCofrade(cofrade.id, {'rol': 'admin'});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${cofrade.nombreCompleto} es ahora administrador.')),
          );
        }
        break;
    }
  }
}
