import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _telefonoFijoController;
  late TextEditingController _telefonoMovilController;
  late TextEditingController _domicilioController;
  late TextEditingController _localidadController;
  late TextEditingController _codigoPostalController;
  late TextEditingController _estaturaController;
  late TextEditingController _tallaController;
  late TextEditingController _emailSecundarioController;
  late TextEditingController _telefonoSecundarioController;
  late TextEditingController _dniController;
  late TextEditingController _emailController;
  late TextEditingController _ibanController;
  late TextEditingController _titularIbanController;
  bool _isEditing = false;
  bool _isSaving = false;
  late bool _tieneTunicaPropia;

  @override
  void initState() {
    super.initState();
    final cofrade = context.read<AuthService>().cofrade;
    _tieneTunicaPropia = cofrade?.tieneTunicaPropia ?? false;
    _telefonoFijoController = TextEditingController(text: cofrade?.telefonoFijo ?? '');
    _telefonoMovilController = TextEditingController(text: cofrade?.telefonoMovil ?? '');
    _domicilioController = TextEditingController(text: cofrade?.domicilio ?? '');
    _localidadController = TextEditingController(text: cofrade?.localidad ?? '');
    _codigoPostalController =
        TextEditingController(text: cofrade?.codigoPostal ?? '');
    _estaturaController = TextEditingController(
        text: cofrade?.estatura?.toString() ?? '');
    _tallaController = TextEditingController(text: cofrade?.talla ?? '');
    _emailSecundarioController = TextEditingController(text: cofrade?.emailSecundario ?? '');
    _telefonoSecundarioController = TextEditingController(text: cofrade?.telefonoSecundario ?? '');
    _dniController = TextEditingController(text: cofrade?.dni ?? '');
    _emailController = TextEditingController(text: cofrade?.email ?? '');
    _ibanController = TextEditingController(text: cofrade?.iban ?? '');
    _titularIbanController = TextEditingController(text: cofrade?.titularIban ?? '');
  }

  @override
  void dispose() {
    _telefonoFijoController.dispose();
    _telefonoMovilController.dispose();
    _domicilioController.dispose();
    _localidadController.dispose();
    _codigoPostalController.dispose();
    _estaturaController.dispose();
    _tallaController.dispose();
    _emailSecundarioController.dispose();
    _telefonoSecundarioController.dispose();
    _dniController.dispose();
    _emailController.dispose();
    _ibanController.dispose();
    _titularIbanController.dispose();
    super.dispose();
  }

  String? _validateIban(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (cleaned.length < 15 || cleaned.length > 34) {
      return 'IBAN debe tener entre 15 y 34 caracteres';
    }
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}').hasMatch(cleaned)) {
      return 'Formato IBAN no v\u00e1lido (ej: ES12 3456 7890 1234 5678 9012)';
    }
    return null;
  }

  String? _validateDni(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.trim().toUpperCase();
    if (!RegExp(r'^[0-9]{8}[A-Z]$').hasMatch(cleaned) &&
        !RegExp(r'^[XYZ][0-9]{7}[A-Z]$').hasMatch(cleaned)) {
      return 'Formato DNI/NIE no v\u00e1lido (ej: 12345678A)';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!value.contains('@') || !value.contains('.')) {
      return 'Email no v\u00e1lido';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final cofrade = authService.cofrade;

    final bool dniLocked = cofrade?.dni != null && cofrade!.dni!.isNotEmpty;

    final incompleteFields = <String>[];
    if (cofrade != null) {
      if (cofrade.telefonoMovil.isEmpty) incompleteFields.add('Tel\u00e9fono m\u00f3vil');
      if (cofrade.domicilio.isEmpty) incompleteFields.add('Domicilio');
      if (cofrade.localidad.isEmpty) incompleteFields.add('Localidad');
      if (cofrade.codigoPostal.isEmpty) incompleteFields.add('C\u00f3digo postal');
      if (cofrade.dni == null || cofrade.dni!.isEmpty) incompleteFields.add('DNI');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (incompleteFields.isNotEmpty) ...[
              Card(
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Perfil incompleto',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Faltan por rellenar: ${incompleteFields.join(", ")}',
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mi Perfil',
                    style: Theme.of(context).textTheme.headlineMedium),
                if (!_isEditing)
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (cofrade != null)
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text('Nº ${cofrade.numero ?? "-"}'),
                    backgroundColor: AppTheme.primaryColor.withAlpha(25),
                    labelStyle: const TextStyle(color: AppTheme.primaryColor),
                  ),
                  Chip(
                    label: Text(cofrade.estado),
                    backgroundColor: cofrade.isActivo
                        ? Colors.green.withAlpha(25)
                        : Colors.orange.withAlpha(25),
                    labelStyle: TextStyle(
                        color: cofrade.isActivo ? Colors.green : Colors.orange),
                  ),
                  if (cofrade.tuteladoDigital != null &&
                      cofrade.tuteladoDigital!.isNotEmpty)
                    Chip(
                      label: const Text('Tutelado'),
                      backgroundColor: Colors.blue.withAlpha(25),
                      labelStyle: const TextStyle(color: Colors.blue),
                      avatar: const Icon(Icons.supervisor_account,
                          size: 16, color: Colors.blue),
                    ),
                ],
              ),
            if (authService.hasMultipleCofrades) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Viendo perfil de: ',
                          style: TextStyle(color: Colors.blue)),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: cofrade?.id,
                          underline: const SizedBox.shrink(),
                          items: authService.cofrades.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.nombreCompleto,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                          onChanged: (id) {
                            if (id != null) {
                              authService.selectCofrade(id);
                              _resetFields();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Datos Personales',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 20),
                      _buildField('Nombre', null,
                          value: cofrade?.nombre ?? '', enabled: false),
                      _buildField('Apellidos', null,
                          value: cofrade?.apellidos ?? '', enabled: false),
                      _buildField('DNI', _dniController,
                          enabled: !dniLocked,
                          validator: _validateDni,
                          helperText: dniLocked
                              ? 'El DNI no se puede modificar una vez guardado'
                              : null),
                      _buildField('Email', _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail),
                      _buildField('Email Secundario', _emailSecundarioController,
                          keyboardType: TextInputType.emailAddress),
                      _buildField('Teléfono Móvil', _telefonoMovilController,
                          keyboardType: TextInputType.phone),
                      _buildField('Teléfono Fijo', _telefonoFijoController,
                          keyboardType: TextInputType.phone),
                      _buildField('Teléfono Secundario', _telefonoSecundarioController,
                          keyboardType: TextInputType.phone),
                      _buildField('Domicilio', _domicilioController),
                      _buildField('Localidad', _localidadController),
                      _buildField('Código Postal', _codigoPostalController,
                          keyboardType: TextInputType.number),
                      _buildField('Estatura (cm)', _estaturaController,
                          keyboardType: TextInputType.number),
                      _buildField('Talla', _tallaController),
                      if (_isEditing) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SwitchListTile(
                            title: const Text('Tengo t\u00fanica propia'),
                            subtitle: const Text('Marca si dispones de t\u00fanica propia'),
                            value: _tieneTunicaPropia,
                            onChanged: (v) => setState(() => _tieneTunicaPropia = v),
                            secondary: const Icon(Icons.checkroom),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() => _isEditing = false);
                                  _resetFields();
                                },
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('Guardar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Member info card
            if (cofrade != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Información de Cofrade',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      _InfoRow(
                          label: 'Nº Cofrade',
                          value: '${cofrade.numero ?? "-"}',
                          icon: Icons.tag),
                      _InfoRow(
                          label: 'Estado',
                          value: cofrade.estado,
                          icon: cofrade.isActivo
                              ? Icons.check_circle
                              : Icons.pending),
                      if (cofrade.anioAlta != null)
                        _InfoRow(
                          label: 'Año de Alta',
                          value: '${cofrade.anioAlta}',
                          icon: Icons.calendar_today,
                        ),
                      if (cofrade.aniosHermandad != null)
                        _InfoRow(
                          label: 'Años en Hermandad',
                          value: '${cofrade.aniosHermandad}',
                          icon: Icons.access_time,
                        ),
                      if (cofrade.genero != null)
                        _InfoRow(
                          label: 'Género',
                          value: cofrade.genero!,
                          icon: Icons.person,
                        ),
                      if (cofrade.tuteladoDigital != null &&
                          cofrade.tuteladoDigital!.isNotEmpty)
                        _InfoRow(
                          label: 'Tutor Digital',
                          value: cofrade.tuteladoDigital!,
                          icon: Icons.supervisor_account,
                        ),
                      if (cofrade.cargo != null && cofrade.cargo!.isNotEmpty)
                        _InfoRow(
                          label: 'Cargo',
                          value: cofrade.cargo!,
                          icon: Icons.badge,
                        ),
                      _InfoRow(
                          label: 'Túnica propia',
                          value: cofrade.tieneTunicaPropia ? 'Sí' : 'No',
                          icon: Icons.checkroom),
                      _InfoRow(
                          label: 'GDPR Firmado (Papel)',
                          value: cofrade.gdprFirmado ? 'Sí' : 'No',
                          icon: cofrade.gdprFirmado
                              ? Icons.verified
                              : Icons.warning),
                      _InfoRow(
                          label: 'GDPR Firmado (Digital)',
                          value: cofrade.gdprFirmadoDigital ? 'Sí' : 'No',
                          icon: cofrade.gdprFirmadoDigital
                              ? Icons.verified
                              : Icons.warning),
                      if (cofrade.emailSecundario != null &&
                          cofrade.emailSecundario!.isNotEmpty)
                        _InfoRow(
                          label: 'Email secundario',
                          value: cofrade.emailSecundario!,
                          icon: Icons.alternate_email,
                        ),
                      if (cofrade.telefonoSecundario != null &&
                          cofrade.telefonoSecundario!.isNotEmpty)
                        _InfoRow(
                          label: 'Teléfono secundario',
                          value: cofrade.telefonoSecundario!,
                          icon: Icons.phone,
                        ),
                      if (cofrade.parentescoTutor != null &&
                          cofrade.parentescoTutor!.isNotEmpty)
                        _InfoRow(
                          label: 'Parentesco tutor',
                          value: cofrade.parentescoTutor!,
                          icon: Icons.family_restroom,
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (cofrade != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Datos Bancarios',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      if (!_isEditing)
                        Text(
                          'Pulsa "Editar" para modificar tus datos bancarios.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      const SizedBox(height: 16),
                      _InfoRow(
                          label: 'Cuota activa',
                          value: cofrade.tieneCuota ? 'S\u00ed' : 'No',
                          icon: Icons.payments),
                      if (cofrade.tieneCuota) ...[
                        _InfoRow(
                            label: 'Tipo',
                            value: cofrade.cuotaDomiciliada
                                ? 'Domiciliada'
                                : cofrade.cuotaMetalico
                                    ? 'Met\u00e1lico'
                                    : 'No especificado',
                            icon: Icons.account_balance),
                      ],
                      if (_isEditing) ...[                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _ibanController,
                          decoration: const InputDecoration(
                            labelText: 'IBAN',
                            prefixIcon: Icon(Icons.credit_card),
                            hintText: 'ES12 3456 7890 1234 5678 9012',
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s]')),
                            _UpperCaseTextFormatter(),
                          ],
                          validator: _validateIban,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titularIbanController,
                          decoration: const InputDecoration(
                            labelText: 'Titular IBAN',
                            prefixIcon: Icon(Icons.person_outline),
                            hintText: 'Nombre del titular de la cuenta',
                          ),
                        ),
                      ] else ...[                        if (cofrade.iban != null && cofrade.iban!.isNotEmpty)
                          _InfoRow(
                              label: 'IBAN',
                              value: cofrade.iban!,
                              icon: Icons.credit_card),
                        if (cofrade.titularIban != null && cofrade.titularIban!.isNotEmpty)
                          _InfoRow(
                              label: 'Titular IBAN',
                              value: cofrade.titularIban!,
                              icon: Icons.person_outline),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController? controller,
      {String? value,
      bool enabled = true,
      bool required = false,
      TextInputType? keyboardType,
      String? Function(String?)? validator,
      String? helperText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? value : null,
        enabled: _isEditing && enabled,
        decoration: InputDecoration(
          labelText: label,
          helperText: (_isEditing && !enabled && helperText != null) ? helperText : null,
          helperStyle: TextStyle(color: Colors.orange.shade700, fontSize: 12),
        ),
        keyboardType: keyboardType,
        validator: validator ??
            (required
                ? (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null
                : null),
      ),
    );
  }

  void _resetFields() {
    final cofrade = context.read<AuthService>().cofrade;
    _telefonoFijoController.text = cofrade?.telefonoFijo ?? '';
    _telefonoMovilController.text = cofrade?.telefonoMovil ?? '';
    _domicilioController.text = cofrade?.domicilio ?? '';
    _localidadController.text = cofrade?.localidad ?? '';
    _codigoPostalController.text = cofrade?.codigoPostal ?? '';
    _estaturaController.text = cofrade?.estatura?.toString() ?? '';
    _tallaController.text = cofrade?.talla ?? '';
    _emailSecundarioController.text = cofrade?.emailSecundario ?? '';
    _telefonoSecundarioController.text = cofrade?.telefonoSecundario ?? '';
    _dniController.text = cofrade?.dni ?? '';
    _emailController.text = cofrade?.email ?? '';
    _ibanController.text = cofrade?.iban ?? '';
    _titularIbanController.text = cofrade?.titularIban ?? '';
    _tieneTunicaPropia = cofrade?.tieneTunicaPropia ?? false;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final cofradeId = context.read<AuthService>().cofrade?.id;
      if (cofradeId == null) return;

      final data = <String, dynamic>{
        'telefono_fijo': _telefonoFijoController.text,
        'telefono_movil': _telefonoMovilController.text,
        'domicilio': _domicilioController.text,
        'localidad': _localidadController.text,
        'codigo_postal': _codigoPostalController.text,
        'estatura': _estaturaController.text.isNotEmpty
            ? int.tryParse(_estaturaController.text)
            : null,
        'talla': _tallaController.text,
        'email_secundario': _emailSecundarioController.text,
        'telefono_secundario': _telefonoSecundarioController.text,
        'tiene_tunica_propia': _tieneTunicaPropia,
        'iban': _ibanController.text.trim(),
        'titular_iban': _titularIbanController.text.trim(),
        'email': _emailController.text.trim(),
      };

      final cofrade = context.read<AuthService>().cofrade;
      final dniIsLocked = cofrade?.dni != null && cofrade!.dni!.isNotEmpty;
      if (!dniIsLocked && _dniController.text.trim().isNotEmpty) {
        data['dni'] = _dniController.text.trim().toUpperCase();
      }

      await context.read<FirestoreService>().updateCofrade(cofradeId, data);

      await context.read<AuthService>().refreshCofradeData();

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Flexible(child: Text(value)),
        ],
      ),
    );
  }
}
