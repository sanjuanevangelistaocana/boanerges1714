import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/solicitud.dart';
import 'package:boanerges1714/services/firestore_service.dart';

const Map<String, String> _localidadesCp = {
  'Oca\u00f1a': '45300',
  'Dos Barrios': '45311',
  'Villatobas': '45310',
  'La Guardia': '45760',
  'Noblejas': '45350',
  'Santa Cruz de la Zarza': '45370',
  'Villasequilla': '45740',
  'Yepes': '45313',
  'Huerta de Valdecar\u00e1banos': '45750',
  'Ont\u00edgola': '45340',
  'Caba\u00f1as de Yepes': '45312',
  'Ciruelos': '45314',
  'Villarrubia de Santiago': '45360',
  'Aranjuez': '28300',
  'Toledo': '45001',
  'Madrid': '28001',
};

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
  String? _genero;
  bool _isSending = false;
  bool _sent = false;

  String? _validateDni(String? value) {
    if (value == null || value.isEmpty) return null;
    final v = value.trim().toUpperCase();
    final dniRegex = RegExp(r'^[0-9]{8}[A-Z]$');
    final nieRegex = RegExp(r'^[XYZ][0-9]{7}[A-Z]$');
    if (!dniRegex.hasMatch(v) && !nieRegex.hasMatch(v)) {
      return 'Formato inv\u00e1lido (ej: 12345678A o X1234567A)';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+34')) {
      if (cleaned.length != 12) return 'Tel\u00e9fono inv\u00e1lido';
    } else if (cleaned.length == 9) {
      if (!RegExp(r'^[6-9][0-9]{8}$').hasMatch(cleaned)) {
        return 'Tel\u00e9fono inv\u00e1lido (debe empezar por 6, 7, 8 o 9)';
      }
    } else {
      return 'Introduce 9 d\u00edgitos o +34 seguido de 9 d\u00edgitos';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Campo obligatorio';
    final emailRegex = RegExp(r'^[\w\.\-\+]+@[\w\.\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Introduce un email v\u00e1lido';
    }
    return null;
  }

  String? _validateCp(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!RegExp(r'^[0-9]{5}$').hasMatch(value.trim())) {
      return 'El c\u00f3digo postal debe tener 5 d\u00edgitos';
    }
    return null;
  }

  void _onLocalidadSelected(String localidad) {
    _localidadController.text = localidad;
    final cp = _localidadesCp[localidad];
    if (cp != null && _codigoPostalController.text.isEmpty) {
      _codigoPostalController.text = cp;
    }
  }

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
                              style: Theme.of(context).textTheme.titleMedium),
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
                              hintText: 'ejemplo@correo.com',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _telefonoController,
                            decoration: const InputDecoration(
                              labelText: 'Tel\u00e9fono m\u00f3vil',
                              prefixIcon: Icon(Icons.phone_outlined),
                              hintText: '612 345 678',
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d\s\+\-\(\)]')),
                            ],
                            validator: _validatePhone,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _dniController,
                            decoration: const InputDecoration(
                              labelText: 'DNI / NIE',
                              prefixIcon: Icon(Icons.badge_outlined),
                              hintText: '12345678A',
                            ),
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9A-Za-zXYZxyz]')),
                              LengthLimitingTextInputFormatter(9),
                            ],
                            validator: _validateDni,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _genero,
                            decoration: const InputDecoration(
                              labelText: 'Género *',
                              prefixIcon: Icon(Icons.wc_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Hombre', child: Text('Hombre')),
                              DropdownMenuItem(
                                  value: 'Mujer', child: Text('Mujer')),
                            ],
                            onChanged: (value) =>
                                setState(() => _genero = value),
                            validator: (value) =>
                                value == null ? 'Campo obligatorio' : null,
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.cake, color: Colors.grey),
                            title: Text(
                              _fechaNacimiento != null
                                  ? '${_fechaNacimiento!.day.toString().padLeft(2, '0')}/${_fechaNacimiento!.month.toString().padLeft(2, '0')}/${_fechaNacimiento!.year}'
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
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _domicilioController,
                            decoration: const InputDecoration(
                              labelText: 'Domicilio',
                              prefixIcon: Icon(Icons.home_outlined),
                              hintText: 'C/ Ejemplo, 1',
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 12),
                          Autocomplete<String>(
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              final query = textEditingValue.text.toLowerCase();
                              return _localidadesCp.keys.where(
                                (loc) => loc.toLowerCase().contains(query),
                              );
                            },
                            onSelected: _onLocalidadSelected,
                            fieldViewBuilder: (context, controller, focusNode,
                                onFieldSubmitted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_localidadController.text.isNotEmpty &&
                                    controller.text.isEmpty) {
                                  controller.text = _localidadController.text;
                                }
                              });
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Localidad',
                                  prefixIcon: Icon(Icons.location_city),
                                  hintText: 'Oca\u00f1a',
                                ),
                                textCapitalization: TextCapitalization.words,
                                onChanged: (v) {
                                  _localidadController.text = v;
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _codigoPostalController,
                            decoration: const InputDecoration(
                              labelText: 'C\u00f3digo postal',
                              prefixIcon: Icon(Icons.markunread_mailbox),
                              hintText: '45300',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            validator: _validateCp,
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
                                          strokeWidth: 2, color: Colors.white),
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
        genero: _genero,
        dni: _dniController.text.trim(),
        motivacion: _motivacionController.text.trim(),
        fechaSolicitud: DateTime.now(),
      );

      await context.read<FirestoreService>().createSolicitud(solicitud);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Error al enviar la solicitud.';
        final errorStr = e.toString();
        if (errorStr.contains('permission-denied') ||
            errorStr.contains('PERMISSION_DENIED')) {
          errorMsg =
              'Error de permisos. Int\u00e9ntalo de nuevo m\u00e1s tarde.';
        } else if (errorStr.contains('unavailable') ||
            errorStr.contains('network')) {
          errorMsg =
              'Error de conexi\u00f3n. Comprueba tu internet e int\u00e9ntalo de nuevo.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
