import 'package:flutter/material.dart';
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
  late TextEditingController _nombreController;
  late TextEditingController _apellidosController;
  late TextEditingController _telefonoFijoController;
  late TextEditingController _telefonoMovilController;
  late TextEditingController _domicilioController;
  late TextEditingController _localidadController;
  late TextEditingController _codigoPostalController;
  late TextEditingController _estaturaController;
  late TextEditingController _tallaController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final cofrade = context.read<AuthService>().cofrade;
    _nombreController = TextEditingController(text: cofrade?.nombre ?? '');
    _apellidosController = TextEditingController(text: cofrade?.apellidos ?? '');
    _telefonoFijoController = TextEditingController(text: cofrade?.telefonoFijo ?? '');
    _telefonoMovilController = TextEditingController(text: cofrade?.telefonoMovil ?? '');
    _domicilioController = TextEditingController(text: cofrade?.domicilio ?? '');
    _localidadController = TextEditingController(text: cofrade?.localidad ?? '');
    _codigoPostalController =
        TextEditingController(text: cofrade?.codigoPostal ?? '');
    _estaturaController = TextEditingController(
        text: cofrade?.estatura?.toString() ?? '');
    _tallaController = TextEditingController(text: cofrade?.talla ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _telefonoFijoController.dispose();
    _telefonoMovilController.dispose();
    _domicilioController.dispose();
    _localidadController.dispose();
    _codigoPostalController.dispose();
    _estaturaController.dispose();
    _tallaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final cofrade = authService.cofrade;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      _buildField('Nombre', _nombreController, required: true),
                      _buildField('Apellidos', _apellidosController,
                          required: true),
                      _buildField('Email', null,
                          value: cofrade?.email ?? '', enabled: false),
                      _buildField('Teléfono Móvil', _telefonoMovilController,
                          keyboardType: TextInputType.phone),
                      _buildField('Teléfono Fijo', _telefonoFijoController,
                          keyboardType: TextInputType.phone),
                      _buildField('Domicilio', _domicilioController),
                      _buildField('Localidad', _localidadController),
                      _buildField('Código Postal', _codigoPostalController,
                          keyboardType: TextInputType.number),
                      _buildField('Estatura (cm)', _estaturaController,
                          keyboardType: TextInputType.number),
                      _buildField('Talla', _tallaController),
                      if (_isEditing) ...[
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
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController? controller,
      {String? value,
      bool enabled = true,
      bool required = false,
      TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? value : null,
        enabled: _isEditing && enabled,
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboardType,
        validator: required
            ? (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null
            : null,
      ),
    );
  }

  void _resetFields() {
    final cofrade = context.read<AuthService>().cofrade;
    _nombreController.text = cofrade?.nombre ?? '';
    _apellidosController.text = cofrade?.apellidos ?? '';
    _telefonoFijoController.text = cofrade?.telefonoFijo ?? '';
    _telefonoMovilController.text = cofrade?.telefonoMovil ?? '';
    _domicilioController.text = cofrade?.domicilio ?? '';
    _localidadController.text = cofrade?.localidad ?? '';
    _codigoPostalController.text = cofrade?.codigoPostal ?? '';
    _estaturaController.text = cofrade?.estatura?.toString() ?? '';
    _tallaController.text = cofrade?.talla ?? '';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final cofradeId = context.read<AuthService>().cofrade?.id;
      if (cofradeId == null) return;

      await context.read<FirestoreService>().updateCofrade(cofradeId, {
        'nombre': _nombreController.text,
        'apellidos': _apellidosController.text,
        'telefono_fijo': _telefonoFijoController.text,
        'telefono_movil': _telefonoMovilController.text,
        'domicilio': _domicilioController.text,
        'localidad': _localidadController.text,
        'codigo_postal': _codigoPostalController.text,
        'estatura': _estaturaController.text.isNotEmpty
            ? int.tryParse(_estaturaController.text)
            : null,
        'talla': _tallaController.text,
      });

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
