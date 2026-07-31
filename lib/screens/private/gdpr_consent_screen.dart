import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/storage_service.dart';
import 'package:boanerges1714/widgets/responsive_layout.dart';

class GdprConsentScreen extends StatefulWidget {
  const GdprConsentScreen({super.key});

  @override
  State<GdprConsentScreen> createState() => _GdprConsentScreenState();
}

class _GdprConsentScreenState extends State<GdprConsentScreen> {
  bool _read = false;
  bool _treatment = false;
  bool _communications = false;
  bool _saving = false;
  final _tutorNameController = TextEditingController();
  final _tutorDniController = TextEditingController();
  final _tutorPhoneController = TextEditingController();
  final _tutorEmailController = TextEditingController();
  final _tutorRelationshipController = TextEditingController();
  String? _loadedTutorForCofradeId;

  @override
  void dispose() {
    _tutorNameController.dispose();
    _tutorDniController.dispose();
    _tutorPhoneController.dispose();
    _tutorEmailController.dispose();
    _tutorRelationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final consent = auth.activeLegalConsent ??
        {
          'title': 'Consentimiento de protección de datos',
          'legalText': defaultGdprLegalText,
          'versionId': 'gdpr-rgpd-v1',
        };
    final cofrade = auth.cofrade;
    if (cofrade != null && _loadedTutorForCofradeId != cofrade.id) {
      _loadedTutorForCofradeId = cofrade.id;
      _tutorNameController.text = cofrade.digitalTutorName;
      _tutorDniController.text = cofrade.digitalTutorDni;
      _tutorPhoneController.text = cofrade.digitalTutorPhone;
      _tutorEmailController.text = cofrade.digitalTutorEmail;
      _tutorRelationshipController.text = cofrade.digitalTutorRelationship;
    }
    final requiresTutor = cofrade?.requiresDigitalTutor == true;
    final tutorDataMissing = requiresTutor &&
        (_tutorNameController.text.trim().isEmpty ||
            _tutorDniController.text.trim().isEmpty ||
            _tutorPhoneController.text.trim().isEmpty ||
            _tutorEmailController.text.trim().isEmpty ||
            _tutorRelationshipController.text.trim().isEmpty);
    final canSubmit = _read && _treatment && _communications && !_saving;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ResponsiveContentBox(
        maxWidth: 820,
        padding: EdgeInsets.zero,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${consent['title'] ?? 'Consentimiento de protección de datos'}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text('Versión: ${consent['versionId'] ?? 'gdpr-rgpd-v1'}'),
                if (requiresTutor) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: tutorDataMissing
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Firma por tutela digital',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                              'Cofrade tutelado: ${cofrade?.nombreCompleto ?? "-"}'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _tutorNameController,
                            decoration: const InputDecoration(
                                labelText: 'Nombre del tutor'),
                            onChanged: (_) => setState(() {}),
                          ),
                          TextField(
                            controller: _tutorDniController,
                            decoration:
                                const InputDecoration(labelText: 'DNI tutor'),
                            onChanged: (_) => setState(() {}),
                          ),
                          TextField(
                            controller: _tutorPhoneController,
                            decoration: const InputDecoration(
                                labelText: 'Teléfono tutor'),
                            keyboardType: TextInputType.phone,
                            onChanged: (_) => setState(() {}),
                          ),
                          TextField(
                            controller: _tutorEmailController,
                            decoration:
                                const InputDecoration(labelText: 'Email tutor'),
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) => setState(() {}),
                          ),
                          TextField(
                            controller: _tutorRelationshipController,
                            decoration:
                                const InputDecoration(labelText: 'Parentesco'),
                            onChanged: (_) => setState(() {}),
                          ),
                          if (tutorDataMissing) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Faltan datos obligatorios del tutor. Contacta con la Cofradía para completarlos antes de firmar.',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  height: 360,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child:
                        Text('${consent['legalText'] ?? defaultGdprLegalText}'),
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _read,
                  onChanged: (value) => setState(() => _read = value ?? false),
                  title: const Text(
                      'He leído y comprendido la información sobre protección de datos'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _treatment,
                  onChanged: (value) =>
                      setState(() => _treatment = value ?? false),
                  title: const Text(
                      'Consiento el tratamiento de mis datos personales para la gestión interna de la Cofradía'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _communications,
                  onChanged: (value) =>
                      setState(() => _communications = value ?? false),
                  title: const Text(
                      'Consiento recibir comunicaciones relacionadas con la actividad de la Cofradía'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canSubmit && !tutorDataMissing ? _accept : null,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Firmar y aceptar consentimiento'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Podrás consultar posteriormente la fecha, versión y estado del consentimiento desde tu perfil.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accept() async {
    if (_saving) return;
    final auth = context.read<AuthService>();
    final cofrade = auth.cofrade;
    final user = auth.user;
    if (cofrade == null || user == null) {
      _showError(
          'No se ha podido identificar tu sesión. Vuelve a iniciar sesión.');
      return;
    }
    if (!_read || !_treatment || !_communications) {
      _showError('Debes marcar todas las casillas obligatorias para firmar.');
      return;
    }
    setState(() => _saving = true);
    try {
      final consent = auth.activeLegalConsent ??
          {
            'versionId': 'gdpr-rgpd-v1',
            'legalText': defaultGdprLegalText,
          };
      final version = '${consent['versionId'] ?? 'gdpr-rgpd-v1'}';
      final legalText = '${consent['legalText'] ?? defaultGdprLegalText}';
      final legalHash = sha256.convert(utf8.encode(legalText)).toString();
      final acceptedAt = DateTime.now();
      final isTutorSignature = cofrade.requiresDigitalTutor;
      if (isTutorSignature) {
        final tutorMissing = _tutorNameController.text.trim().isEmpty ||
            _tutorDniController.text.trim().isEmpty ||
            _tutorPhoneController.text.trim().isEmpty ||
            _tutorEmailController.text.trim().isEmpty ||
            _tutorRelationshipController.text.trim().isEmpty;
        if (tutorMissing) {
          throw StateError('Faltan datos obligatorios del tutor.');
        }
        await _withTimeout(
          'guardar datos del tutor',
          context.read<FirestoreService>().updateCofrade(
                cofrade.id,
                {
                  'digitalTutorName': _tutorNameController.text.trim(),
                  'digitalTutorDni':
                      _tutorDniController.text.trim().toUpperCase(),
                  'digitalTutorPhone': _tutorPhoneController.text.trim(),
                  'digitalTutorEmail': _tutorEmailController.text.trim(),
                  'digitalTutorRelationship':
                      _tutorRelationshipController.text.trim(),
                  'dni_tutor': _tutorDniController.text.trim().toUpperCase(),
                  'parentesco_tutor': _tutorRelationshipController.text.trim(),
                  'requiresDigitalTutor': true,
                  'tutelado_digital': true,
                },
                changedBy: cofrade.id,
                changedByRole: 'cofrade',
              ),
        );
        await _withTimeout('refrescar perfil', auth.refreshCofradeData());
      }
      final signingCofrade = auth.cofrade ?? cofrade;
      final signatureMetadata = {
        'signedByType': isTutorSignature ? 'digital_tutor' : 'cofrade',
        'signedByName': isTutorSignature
            ? _tutorNameController.text.trim()
            : signingCofrade.nombreCompleto,
        'signedByDni': isTutorSignature
            ? _tutorDniController.text.trim().toUpperCase()
            : (signingCofrade.dni ?? ''),
        'signedForCofradeId': signingCofrade.id,
        'signedForCofradeName': signingCofrade.nombreCompleto,
        'signedByRelationship':
            isTutorSignature ? _tutorRelationshipController.text.trim() : '',
      };
      final fieldsConfig =
          await context.read<FirestoreService>().getCofradeFieldsConfig().first;
      final visibleCustomFields = <String, String>{};
      for (final field in fieldsConfig.where((f) =>
          f.active && f.visibleInPrivateProfile && f.fieldKey.isNotEmpty)) {
        final value = signingCofrade.valueForFieldKey(field.fieldKey);
        if (value != null && '$value'.trim().isNotEmpty) {
          visibleCustomFields[field.label] = '$value';
        }
      }
      final pdfBytes = await _withTimeout(
        'generar PDF',
        _buildConsentPdf(
          cofrade: signingCofrade,
          visibleCustomFields: visibleCustomFields,
          signatureMetadata: signatureMetadata,
          acceptedAt: acceptedAt,
          version: version,
          legalTextHash: legalHash,
          legalText: legalText,
          checkboxes: {
            'He leído y comprendido la información sobre protección de datos':
                _read,
            'Consiento el tratamiento de mis datos personales': _treatment,
            'Consiento recibir comunicaciones relacionadas con la actividad de la Cofradía':
                _communications,
          },
        ),
      );
      final safeVersion = version.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      final upload = await _withTimeout(
        'subir PDF',
        context.read<StorageService>().uploadBytesAtPath(
          fullPath:
              'cofrades/${signingCofrade.id}/documents/gdpr/gdpr_digital_$safeVersion.pdf',
          bytes: pdfBytes,
          contentType: 'application/pdf',
          customMetadata: {
            'cofradeId': signingCofrade.id,
            'consentVersion': version,
          },
        ),
      );
      final documentId = await _withTimeout(
        'crear documento privado',
        context.read<FirestoreService>().saveGdprDigitalDocument(
              cofrade: signingCofrade,
              upload: {
                ...upload,
                'nombre': 'Consentimiento digital.pdf',
              },
              consentVersion: version,
              legalTextHash: legalHash,
              performedBy: signingCofrade.id,
              signatureMetadata: signatureMetadata,
            ),
      );
      await _withTimeout(
        'guardar consentimiento',
        context.read<FirestoreService>().acceptDigitalGdprConsent(
              cofrade: signingCofrade,
              acceptedByUid: user.uid,
              acceptedByEmail: user.email ?? signingCofrade.email,
              consent: consent,
              checkboxes: {
                'read_and_understood': _read,
                'personal_data_treatment': _treatment,
                'communications': _communications,
              },
              documentId: documentId,
            ),
      );
      await _withTimeout('actualizar sesión', auth.refreshCofradeData());
      if (mounted) context.go('/dashboard');
    } catch (e, st) {
      debugPrint('[GDPR] Error firmando consentimiento: $e\n$st');
      _showError(
        'No se ha podido firmar el consentimiento. Revisa tu conexión e inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<T> _withTimeout<T>(String step, Future<T> future) {
    return future.timeout(
      const Duration(seconds: 25),
      onTimeout: () {
        throw TimeoutException('Tiempo agotado al $step.');
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<Uint8List> _buildConsentPdf({
    required cofrade,
    required Map<String, String> visibleCustomFields,
    required Map<String, dynamic> signatureMetadata,
    required DateTime acceptedAt,
    required String version,
    required String legalTextHash,
    required String legalText,
    required Map<String, bool> checkboxes,
  }) async {
    String value(Object? raw) {
      final text = '${raw ?? ''}'.trim();
      return text.isEmpty ? 'No informado' : text;
    }

    pw.Widget section(String title, List<pw.Widget> children) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#D8DEE4')),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#6F1D1B'),
              ),
            ),
            pw.SizedBox(height: 8),
            ...children,
          ],
        ),
      );
    }

    pw.Widget row(String label, Object? raw) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 145,
              child: pw.Text(
                label,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Expanded(child: pw.Text(value(raw))),
          ],
        ),
      );
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.fromLTRB(38, 36, 38, 36),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Cofradía de San Juan Evangelista de Ocaña',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Página ${context.pageNumber}/${context.pagesCount} · $version',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) {
          final tutorSignature =
              signatureMetadata['signedByType'] == 'digital_tutor';
          return [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#6F1D1B'),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'COFRADÍA DE SAN JUAN EVANGELISTA DE OCAÑA',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Consentimiento Digital y Tratamiento de Datos Personales',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 21,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            section('1. Datos del consentimiento', [
              row('Identificador', 'gdpr_digital_$version'),
              row('Estado', 'Firmado'),
              row('Fecha y hora de firma', acceptedAt.toIso8601String()),
              row('Versión legal', version),
              row('Hash texto legal', legalTextHash),
            ]),
            section('2. Datos del cofrade', [
              row('ID cofrade', cofrade.id),
              row('Número de cofrade', cofrade.numero),
              row('Nombre y apellidos', cofrade.nombreCompleto),
              row('DNI/NIF', cofrade.dni),
              row('Email', cofrade.email),
              row('Teléfono', cofrade.telefonoMovil),
              row('Dirección', cofrade.domicilio),
              row('Localidad', cofrade.localidad),
              row('Fecha nacimiento', cofrade.fechaNacimientoStr),
              ...visibleCustomFields.entries
                  .where((entry) => ![
                        'Nombre',
                        'Apellidos',
                        'Email',
                        'Teléfono móvil',
                        'DNI',
                      ].contains(entry.key))
                  .take(12)
                  .map((entry) => row(entry.key, entry.value)),
            ]),
            if (tutorSignature)
              section('3. Datos del firmante / representante', [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FFF7ED'),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Text(
                    'El presente consentimiento ha sido firmado por ${value(signatureMetadata['signedByName'])}, en calidad de ${value(signatureMetadata['signedByRelationship'])}, en representación de ${value(signatureMetadata['signedForCofradeName'])}.',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 8),
                row('Firmante', signatureMetadata['signedByName']),
                row('DNI firmante', signatureMetadata['signedByDni']),
                row('Relación', signatureMetadata['signedByRelationship']),
                row('Firma para', signatureMetadata['signedForCofradeName']),
              ])
            else
              section('3. Datos del firmante', [
                row('Firmante', signatureMetadata['signedByName']),
                row('DNI/NIF', signatureMetadata['signedByDni']),
                row('Tipo', 'Firma propia del cofrade'),
              ]),
            section('4. Casillas aceptadas', [
              ...checkboxes.entries.map(
                (entry) => pw.Bullet(
                  text: '${entry.key}: ${entry.value ? 'Sí' : 'No'}',
                ),
              ),
            ]),
            section('5. Texto legal aceptado', [
              pw.Text(
                legalText,
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
              ),
            ]),
            section('6. Evidencia técnica de firma', [
              row('Origen', 'Aplicación privada'),
              row('Cofrade vinculado', cofrade.id),
              row('Hash legal', legalTextHash),
              row('Generado', DateTime.now().toIso8601String()),
            ]),
          ];
        },
      ),
    );
    return doc.save();
  }
}
