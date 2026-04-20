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
  late TextEditingController _telefonoController;
  late TextEditingController _direccionController;
  late TextEditingController _localidadController;
  late TextEditingController _codigoPostalController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final cofrade = context.read<AuthService>().cofrade;
    _nombreController = TextEditingController(text: cofrade?.nombre ?? '');
    _apellidosController = TextEditingController(text: cofrade?.apellidos ?? '');
    _telefonoController = TextEditingController(text: cofrade?.telefono ?? '');
    _direccionController = TextEditingController(text: cofrade?.direccion ?? '');
    _localidadController = TextEditingController(text: cofrade?.localidad ?? '');
    _codigoPostalController =
        TextEditingController(text: cofrade?.codigoPostal ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _localidadController.dispose();
    _codigoPostalController.dispose();
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
              Chip(
                label: Text(cofrade.cargo),
                backgroundColor: AppTheme.primaryColor.withAlpha(25),
                labelStyle: const TextStyle(color: AppTheme.primaryColor),
              ),
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
                      _buildField('Teléfono', _telefonoController,
                          keyboardType: TextInputType.phone),
                      _buildField('Dirección', _direccionController),
                      _buildField('Localidad', _localidadController),
                      _buildField('Código Postal', _codigoPostalController,
                          keyboardType: TextInputType.number),
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
                          label: 'Estado',
                          value: cofrade.estado.toUpperCase(),
                          icon: cofrade.isActivo
                              ? Icons.check_circle
                              : Icons.pending),
                      _InfoRow(
                          label: 'Cargo',
                          value: cofrade.cargo,
                          icon: Icons.badge),
                      if (cofrade.fechaIngreso != null)
                        _InfoRow(
                          label: 'Fecha de ingreso',
                          value:
                              '${cofrade.fechaIngreso!.day}/${cofrade.fechaIngreso!.month}/${cofrade.fechaIngreso!.year}',
                          icon: Icons.calendar_today,
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
    _telefonoController.text = cofrade?.telefono ?? '';
    _direccionController.text = cofrade?.direccion ?? '';
    _localidadController.text = cofrade?.localidad ?? '';
    _codigoPostalController.text = cofrade?.codigoPostal ?? '';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final userId = context.read<AuthService>().userId;
      if (userId == null) return;

      await context.read<FirestoreService>().updateCofrade(userId, {
        'nombre': _nombreController.text,
        'apellidos': _apellidosController.text,
        'telefono': _telefonoController.text,
        'direccion': _direccionController.text,
        'localidad': _localidadController.text,
        'codigo_postal': _codigoPostalController.text,
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
          Text(value),
        ],
      ),
    );
  }
}
