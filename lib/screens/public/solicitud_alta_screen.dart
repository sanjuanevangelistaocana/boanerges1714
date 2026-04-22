import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/solicitud.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class SolicitudAltaScreen extends StatefulWidget {
  const SolicitudAltaScreen({super.key});

  @override
  State<SolicitudAltaScreen> createState() => _SolicitudAltaScreenState();
}

class _SolicitudAltaScreenState extends State<SolicitudAltaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _domicilioController = TextEditingController();
  final _localidadController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  final _dniController = TextEditingController();
  final _motivacionController = TextEditingController();
  DateTime? _fechaNacimiento;
  bool _isSending = false;
  bool _sent = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _domicilioController.dispose();
    _localidadController.dispose();
    _codigoPostalController.dispose();
    _dniController.dispose();
    _motivacionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 80, color: Colors.green),
                const SizedBox(height: 24),
                Text(
                  'Solicitud enviada',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tu solicitud de alta ha sido enviada correctamente. '
                  'La Junta Directiva revisará tu solicitud y te notificará '
                  'cuando sea aprobada. Recibirás un email de confirmación.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home),
                  label: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitud de Alta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                const Icon(Icons.person_add,
                    size: 48, color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  '¿Quieres ser cofrade?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rellena este formulario y la Junta Directiva revisará '
                  'tu solicitud. Te notificaremos cuando sea aprobada.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Datos personales',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nombreController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Campo obligatorio'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _apellidosController,
                            decoration: const InputDecoration(
                              labelText: 'Apellidos *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Campo obligatorio'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email *',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v == null || !v.contains('@')
                                ? 'Introduce un email válido'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _telefonoController,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono móvil',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _dniController,
                            decoration: const InputDecoration(
                              labelText: 'DNI / NIE',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading:
                                const Icon(Icons.cake, color: Colors.grey),
                            title: Text(
                              _fechaNacimiento != null
                                  ? '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}'
                                  : 'Fecha de nacimiento',
                              style: TextStyle(
                                color: _fechaNacimiento != null
                                    ? null
                                    : Colors.grey[600],
                              ),
                            ),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime(2000, 1, 1),
                                firstDate: DateTime(1920),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => _fechaNacimiento = date);
                              }
                            },
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text('Dirección',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _domicilioController,
                            decoration: const InputDecoration(
                              labelText: 'Domicilio',
                              prefixIcon: Icon(Icons.home_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _localidadController,
                            decoration: const InputDecoration(
                              labelText: 'Localidad',
                              prefixIcon: Icon(Icons.location_city),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _codigoPostalController,
                            decoration: const InputDecoration(
                              labelText: 'Código postal',
                              prefixIcon: Icon(Icons.markunread_mailbox),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const Divider(height: 32),
                          TextFormField(
                            controller: _motivacionController,
                            decoration: const InputDecoration(
                              labelText: '¿Por qué quieres ser cofrade?',
                              prefixIcon: Icon(Icons.edit_note),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isSending ? null : _enviarSolicitud,
                              icon: _isSending
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.send),
                              label: const Text('Enviar solicitud'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    try {
      final solicitud = Solicitud(
        id: '',
        nombre: _nombreController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        email: _emailController.text.trim(),
        telefono: _telefonoController.text.trim(),
        domicilio: _domicilioController.text.trim(),
        localidad: _localidadController.text.trim(),
        codigoPostal: _codigoPostalController.text.trim(),
        fechaNacimiento: _fechaNacimiento,
        dni: _dniController.text.trim(),
        motivacion: _motivacionController.text.trim(),
        fechaSolicitud: DateTime.now(),
      );

      await context.read<FirestoreService>().createSolicitud(solicitud);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
