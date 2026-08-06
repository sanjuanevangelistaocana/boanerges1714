import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/storage_service.dart';
import 'package:boanerges1714/widgets/responsive_layout.dart';
import 'package:boanerges1714/models/cofrade_field_config.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/utils/madrid_date.dart';

class ProfileScreen extends StatefulWidget {
  final bool startEditing;
  const ProfileScreen({super.key, this.startEditing = false});

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
  late bool _isEditing;
  bool _isSaving = false;
  late bool _tieneTunicaPropia;
  late bool _cumpleanosVisible;
  final Map<String, dynamic> _dynamicFieldValues = {};

  @override
  void initState() {
    super.initState();
    _isEditing = widget.startEditing;
    final cofrade = context.read<AuthService>().cofrade;
    _tieneTunicaPropia = cofrade?.tieneTunicaPropia ?? false;
    _cumpleanosVisible = cofrade?.cumpleanosVisible ?? true;
    _telefonoFijoController =
        TextEditingController(text: cofrade?.telefonoFijo ?? '');
    _telefonoMovilController =
        TextEditingController(text: cofrade?.telefonoMovil ?? '');
    _domicilioController =
        TextEditingController(text: cofrade?.domicilio ?? '');
    _localidadController =
        TextEditingController(text: cofrade?.localidad ?? '');
    _codigoPostalController =
        TextEditingController(text: cofrade?.codigoPostal ?? '');
    _estaturaController =
        TextEditingController(text: cofrade?.estatura?.toString() ?? '');
    _tallaController = TextEditingController(text: cofrade?.talla ?? '');
    _emailSecundarioController =
        TextEditingController(text: cofrade?.emailSecundario ?? '');
    _telefonoSecundarioController =
        TextEditingController(text: cofrade?.telefonoSecundario ?? '');
    _dniController = TextEditingController(text: cofrade?.dni ?? '');
    _emailController = TextEditingController(text: cofrade?.email ?? '');
    _ibanController = TextEditingController(text: cofrade?.iban ?? '');
    _titularIbanController =
        TextEditingController(text: cofrade?.titularIban ?? '');
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

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ResponsiveContentBox(
        maxWidth: 600,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder(
              stream: context.read<FirestoreService>().getCofradeFieldsConfig(),
              builder: (context, snapshot) {
                if (cofrade == null || !snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final missing = context
                    .read<FirestoreService>()
                    .getMissingRequiredFields(cofrade, snapshot.data ?? []);
                if (missing.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    color: Colors.orange.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.orange.shade300),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.assignment_late,
                          color: Colors.orange.shade700),
                      title: const Text(
                          'Tienes datos obligatorios pendientes de completar'),
                      subtitle: Text(missing.map((f) => f.label).join(', ')),
                      trailing: TextButton(
                        onPressed: () => setState(() => _isEditing = true),
                        child: const Text('Completar mis datos'),
                      ),
                    ),
                  ),
                );
              },
            ),
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
                  if (cofrade.tuteladoDigitalBool)
                    Chip(
                      label: const Text('Tutelado'),
                      backgroundColor: Colors.blue.withAlpha(25),
                      labelStyle: const TextStyle(color: Colors.blue),
                      avatar: const Icon(Icons.supervisor_account,
                          size: 16, color: Colors.blue),
                    ),
                  if (cofrade.tagsAuto.isNotEmpty)
                    StreamBuilder(
                      stream: context.read<FirestoreService>().getTagsConfig(),
                      builder: (context, snapshot) {
                        final tags = (snapshot.data ?? [])
                            .where(
                                (tag) => tag.activo && tag.showInPrivateProfile)
                            .toList();
                        final names = {
                          for (final tag in tags)
                            if (tag.nombre.trim().isNotEmpty)
                              tag.id: tag.nombre.trim(),
                        };
                        final colors = {
                          for (final tag in tags) tag.id: tag.color,
                        };
                        return Wrap(
                          spacing: 8,
                          children: cofrade.tagsAuto
                              .where((tag) =>
                                  tag != 'faltan_datos' &&
                                  names.containsKey(tag))
                              .map(
                                (tag) => Chip(
                                  label: Text(names[tag]!),
                                  backgroundColor:
                                      _parseHexColor(colors[tag]).withAlpha(30),
                                  labelStyle: TextStyle(
                                      color: _parseHexColor(colors[tag])),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                ],
              ),
            if (authService.hasMultipleCofrades) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            if (cofrade != null &&
                cofrade.fechaNacimiento != null &&
                cofrade.fechaNacimiento!.month == MadridDate.now().month &&
                cofrade.fechaNacimiento!.day == MadridDate.now().day)
              Card(
                color: Colors.amber.shade50,
                child: const ListTile(
                  leading: Text('🎂', style: TextStyle(fontSize: 30)),
                  title: Text('¡Feliz cumpleaños!'),
                  subtitle: Text(
                      'La Cofradía de San Juan Evangelista te desea un maravilloso día.'),
                ),
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
                      _buildField(
                          'Email Secundario', _emailSecundarioController,
                          keyboardType: TextInputType.emailAddress),
                      _buildField('Teléfono Móvil', _telefonoMovilController,
                          keyboardType: TextInputType.phone),
                      _buildField('Teléfono Fijo', _telefonoFijoController,
                          keyboardType: TextInputType.phone),
                      _buildField(
                          'Teléfono Secundario', _telefonoSecundarioController,
                          keyboardType: TextInputType.phone),
                      _buildField('Domicilio', _domicilioController),
                      _buildField('Localidad', _localidadController),
                      _buildField('Código Postal', _codigoPostalController,
                          keyboardType: TextInputType.number),
                      _buildField('Estatura (cm)', _estaturaController,
                          keyboardType: TextInputType.number),
                      _buildField('Talla', _tallaController),
                      if (cofrade != null)
                        StreamBuilder<List<CofradeFieldConfig>>(
                          stream: context
                              .read<FirestoreService>()
                              .getCofradeFieldsConfig(),
                          builder: (context, snapshot) {
                            final fields = (snapshot.data ?? [])
                                .where((field) =>
                                    field.active &&
                                    field.visibleInPrivateProfile &&
                                    !_basePrivateFieldKeys
                                        .contains(field.fieldKey))
                                .toList()
                              ..sort((a, b) => a.order.compareTo(b.order));
                            if (fields.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  'Otros datos',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                ...fields.map(
                                  (field) => _buildDynamicField(field, cofrade),
                                ),
                              ],
                            );
                          },
                        ),
                      if (_isEditing) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SwitchListTile(
                            title: const Text('Mostrar mi cumpleaños'),
                            subtitle: const Text(
                                'Otros cofrades verán sólo mi nombre y día/mes'),
                            value: _cumpleanosVisible,
                            onChanged: (value) =>
                                setState(() => _cumpleanosVisible = value),
                            secondary: const Icon(Icons.cake_outlined),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SwitchListTile(
                            title: const Text('Tengo t\u00fanica propia'),
                            subtitle: const Text(
                                'Marca si dispones de t\u00fanica propia'),
                            value: _tieneTunicaPropia,
                            onChanged: (v) =>
                                setState(() => _tieneTunicaPropia = v),
                            secondary: const Icon(Icons.checkroom),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ResponsiveFormRow(
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                setState(() => _isEditing = false);
                                _resetFields();
                              },
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Guardar'),
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
                      if (cofrade.anioAlta != null)
                        _InfoRow(
                          label: 'Años en Hermandad',
                          value: '${DateTime.now().year - cofrade.anioAlta!}',
                          icon: Icons.access_time,
                        ),
                      if (cofrade.genero != null)
                        _InfoRow(
                          label: 'Género',
                          value: cofrade.genero!,
                          icon: Icons.person,
                        ),
                      if (cofrade.requiresDigitalTutor)
                        _InfoRow(
                          label: 'Tutela digital',
                          value: cofrade.digitalTutorEmail.isEmpty
                              ? 'Requiere tutor'
                              : cofrade.digitalTutorEmail,
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
                      StreamBuilder<Map<String, dynamic>?>(
                        stream: context
                            .read<FirestoreService>()
                            .watchGdprPaperDocument(cofrade.id),
                        builder: (context, snapshot) {
                          final hasPaper = snapshot.data != null ||
                              cofrade.gdprPapel == true;
                          return _InfoRow(
                            label: 'GDPR Firmado (Papel)',
                            value: hasPaper ? 'Sí' : 'No',
                            icon: hasPaper ? Icons.verified : Icons.warning,
                          );
                        },
                      ),
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
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
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
                      if (_isEditing) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _ibanController,
                          decoration: const InputDecoration(
                            labelText: 'IBAN',
                            prefixIcon: Icon(Icons.credit_card),
                            hintText: 'ES12 3456 7890 1234 5678 9012',
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9\s]')),
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
                      ] else ...[
                        if (cofrade.iban != null && cofrade.iban!.isNotEmpty)
                          _InfoRow(
                              label: 'IBAN',
                              value: cofrade.iban!,
                              icon: Icons.credit_card),
                        if (cofrade.titularIban != null &&
                            cofrade.titularIban!.isNotEmpty)
                          _InfoRow(
                              label: 'Titular IBAN',
                              value: cofrade.titularIban!,
                              icon: Icons.person_outline),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (cofrade != null) _buildGdprDocumentationCard(cofrade),
            const SizedBox(height: 16),
            if (cofrade != null) _buildPrivacyCard(cofrade),
          ],
        ),
      ),
    );
  }

  Color _parseHexColor(String? value) {
    final hex = (value ?? '#607D8B').replaceAll('#', '').trim();
    final parsed = int.tryParse('FF$hex', radix: 16);
    return Color(parsed ?? 0xFF607D8B);
  }

  static const Set<String> _basePrivateFieldKeys = {
    'nombre',
    'apellidos',
    'dni',
    'email',
    'email_secundario',
    'telefono_movil',
    'telefono_fijo',
    'telefono_secundario',
    'domicilio',
    'localidad',
    'codigo_postal',
    'estatura',
    'talla',
    'tiene_tunica_propia',
    'iban',
    'titular_iban',
    'tiene_cuota',
    'cuota_metalico',
    'cuota_domiciliada',
    'gdpr_firmado',
    'tutelado_digital',
  };

  Widget _buildGdprDocumentationCard(cofrade) {
    final fs = context.read<FirestoreService>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Documentación GDPR',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: fs.watchGdprDocuments(cofrade.id),
              builder: (context, snapshot) {
                final docs = snapshot.data ?? const <Map<String, dynamic>>[];
                final hasPaper = docs.any((doc) =>
                    doc['type'] == 'GDPR_PAPEL' ||
                    doc['subtype'] == 'GDPR_PAPEL');
                if (docs.isEmpty) {
                  return Text(
                    'No consta documentación GDPR en papel subida.',
                    style: TextStyle(color: Colors.orange.shade700),
                  );
                }
                final documentTiles = docs.map<Widget>((doc) {
                  final isDigital = doc['type'] == 'GDPR_DIGITAL' ||
                      doc['subtype'] == 'GDPR_DIGITAL';
                  final title =
                      isDigital ? 'Consentimiento digital' : 'GDPR en papel';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isDigital
                          ? Icons.verified_user_outlined
                          : Icons.description_outlined,
                    ),
                    title: Text(title),
                    subtitle: Text('${doc['status'] ?? ''}'),
                    trailing: ((doc['downloadUrl'] ?? '').toString().isEmpty &&
                            (doc['storagePath'] ?? '').toString().isEmpty)
                        ? null
                        : OutlinedButton.icon(
                            onPressed: () => _openPrivateDocument(doc),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Ver'),
                          ),
                  );
                }).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        hasPaper
                            ? 'Consta GDPR en papel'
                            : 'No consta GDPR en papel',
                        style: TextStyle(
                          color: hasPaper
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                    ...documentTiles,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard(cofrade) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Protección de datos',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              cofrade.gdprDigitalStatus == 'revocation_requested'
                  ? 'Revocación solicitada'
                  : cofrade.gdprDigitalRevoked
                      ? 'Consentimiento digital revocado'
                      : 'Consentimiento digital vigente',
              style: TextStyle(
                color: cofrade.gdprDigitalStatus == 'revocation_requested'
                    ? Colors.orange.shade700
                    : cofrade.gdprDigitalRevoked
                        ? Colors.red.shade700
                        : Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: cofrade.gdprDigitalRevoked ||
                      cofrade.gdprDigitalStatus == 'revocation_requested'
                  ? null
                  : _confirmGdprRevocation,
              icon: const Icon(Icons.block_outlined),
              label: const Text('Solicitar revocación del consentimiento'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPrivateDocument(Map<String, dynamic> doc) async {
    try {
      final storagePath = '${doc['storagePath'] ?? ''}';
      final url = storagePath.isNotEmpty
          ? await context
              .read<StorageService>()
              .getDownloadUrlFromPath(storagePath)
          : '${doc['downloadUrl']}';
      if (!mounted) return;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para ver este documento.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          helperText: (_isEditing && !enabled && helperText != null)
              ? helperText
              : null,
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

  Widget _buildDynamicField(CofradeFieldConfig field, cofrade) {
    final editable = _isEditing && field.editableByCofrade;
    final current = _dynamicFieldValues.containsKey(field.fieldKey)
        ? _dynamicFieldValues[field.fieldKey]
        : cofrade.valueForFieldKey(field.fieldKey);
    if (!_dynamicFieldValues.containsKey(field.fieldKey) && current != null) {
      _dynamicFieldValues[field.fieldKey] = current;
    }
    final requiredValidator = field.required
        ? (String? value) {
            if (value == null || value.trim().isEmpty) {
              return 'Campo obligatorio';
            }
            return null;
          }
        : null;
    switch (field.type) {
      case 'boolean':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SwitchListTile(
            title: Text(field.label),
            value: _coerceBool(current),
            onChanged: editable
                ? (value) =>
                    setState(() => _dynamicFieldValues[field.fieldKey] = value)
                : null,
            contentPadding: EdgeInsets.zero,
          ),
        );
      case 'select':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            initialValue:
                field.options.contains('$current') ? '$current' : null,
            decoration: InputDecoration(labelText: field.label),
            items: field.options
                .map((option) => DropdownMenuItem(
                      value: option,
                      child: Text(option),
                    ))
                .toList(),
            onChanged: editable
                ? (value) =>
                    setState(() => _dynamicFieldValues[field.fieldKey] = value)
                : null,
            validator: requiredValidator,
          ),
        );
      case 'number':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            initialValue: current == null ? '' : '$current',
            enabled: editable,
            decoration: InputDecoration(labelText: field.label),
            keyboardType: TextInputType.number,
            validator: requiredValidator,
            onChanged: (value) => _dynamicFieldValues[field.fieldKey] =
                value.trim().isEmpty ? null : num.tryParse(value.trim()),
          ),
        );
      case 'date':
        final currentDate = Cofrade.parseBirthDate(current);
        final controller = TextEditingController(
            text: Cofrade.birthDateString(currentDate) ?? '');
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: controller,
            enabled: editable,
            readOnly: true,
            decoration: InputDecoration(
              labelText: field.label,
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            validator: requiredValidator,
            onTap: editable
                ? () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: DateTime.now(),
                    );
                    if (picked == null) return;
                    if (field.fieldKey == 'fecha_nacimiento' ||
                        field.fieldKey == 'fecha_nacimiento_str') {
                      final fields = Cofrade.birthDateFields(picked);
                      controller.text =
                          fields['fecha_nacimiento_str'] as String;
                      _dynamicFieldValues.addAll(fields);
                    } else {
                      final value = Cofrade.birthDateString(picked) ?? '';
                      controller.text = value;
                      _dynamicFieldValues[field.fieldKey] = value;
                    }
                  }
                : null,
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            initialValue: current == null ? '' : '$current',
            enabled: editable,
            decoration: InputDecoration(labelText: field.label),
            keyboardType: _keyboardForDynamicField(field),
            validator: _validatorForDynamicField(field, requiredValidator),
            onChanged: (value) =>
                _dynamicFieldValues[field.fieldKey] = value.trim(),
          ),
        );
    }
  }

  TextInputType _keyboardForDynamicField(CofradeFieldConfig field) {
    final key = field.fieldKey.toLowerCase();
    if (key.contains('email')) return TextInputType.emailAddress;
    if (key.contains('telefono') || key.contains('phone')) {
      return TextInputType.phone;
    }
    if (key.contains('iban') || key.contains('dni')) return TextInputType.text;
    return TextInputType.text;
  }

  String? Function(String?)? _validatorForDynamicField(
    CofradeFieldConfig field,
    String? Function(String?)? requiredValidator,
  ) {
    final key = field.fieldKey.toLowerCase();
    return (value) {
      final requiredError = requiredValidator?.call(value);
      if (requiredError != null) return requiredError;
      if (key.contains('email')) return _validateEmail(value);
      if (key.contains('iban')) return _validateIban(value);
      if (key == 'dni' || key.contains('dni')) return _validateDni(value);
      if (key.contains('telefono') || key.contains('phone')) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isNotEmpty &&
            !RegExp(r'^[0-9 +()-]{6,20}$').hasMatch(trimmed)) {
          return 'Teléfono no válido';
        }
      }
      return null;
    };
  }

  bool _coerceBool(Object? value) {
    if (value is bool) return value;
    final normalized = '${value ?? ''}'.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'si' ||
        normalized == 'sí';
  }

  Future<void> _confirmGdprRevocation() async {
    final auth = context.read<AuthService>();
    final fs = context.read<FirestoreService>();
    final cofrade = auth.cofrade;
    if (cofrade == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revocar consentimiento'),
        content: const Text(
          'La revocación del consentimiento puede limitar o impedir el acceso a la aplicación, al ser necesario para la gestión digital de tu perfil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar revocación'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await fs.requestGdprDigitalRevocation(
        cofrade: cofrade,
        performedBy: cofrade.id,
        performedByRole:
            cofrade.requiresDigitalTutor ? 'digital_tutor' : 'cofrade',
      );
      await auth.refreshCofradeData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Solicitud de revocación registrada correctamente.')),
        );
      }
    } catch (e, st) {
      debugPrint('[Profile] revocation request failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo registrar la revocación.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    _cumpleanosVisible = cofrade?.cumpleanosVisible ?? true;
    _dynamicFieldValues.clear();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final cofradeId = context.read<AuthService>().cofrade?.id;
      if (cofradeId == null) return;
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();

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
        'cumpleanos_visible': _cumpleanosVisible,
        'iban': _ibanController.text.trim(),
        'titular_iban': _titularIbanController.text.trim(),
        'email': _emailController.text.trim(),
      };
      data.addAll(_dynamicFieldValues);

      final cofrade = authService.cofrade;
      final dniIsLocked = cofrade?.dni != null && cofrade!.dni!.isNotEmpty;
      if (!dniIsLocked && _dniController.text.trim().isNotEmpty) {
        data['dni'] = _dniController.text.trim().toUpperCase();
      }

      await firestoreService.updateCofrade(
        cofradeId,
        data,
        changedBy: cofradeId,
        changedByRole: authService.cofrade?.rol ?? 'cofrade',
      );

      await authService.refreshCofradeData();

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
