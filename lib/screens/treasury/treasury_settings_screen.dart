import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/treasury/treasury_settings_service.dart';

class TreasurySettingsScreen extends StatefulWidget {
  const TreasurySettingsScreen({super.key});

  @override
  State<TreasurySettingsScreen> createState() => _TreasurySettingsScreenState();
}

class _TreasurySettingsScreenState extends State<TreasurySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feeCtrl = TextEditingController();
  int _year = DateTime.now().year;
  DateTime? _validationStart;
  DateTime? _validationEnd;
  DateTime? _remittanceDate;
  bool _allowIbanEdition = true;
  bool _isActive = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _feeCtrl.dispose();
    super.dispose();
  }

  void _fill(TreasurySettings? settings) {
    if (_loaded) return;
    _loaded = true;
    _year = settings?.year ?? DateTime.now().year;
    _feeCtrl.text = (settings?.annualFeeAmount ?? 0).toStringAsFixed(2);
    _validationStart = settings?.validationStartDate;
    _validationEnd = settings?.validationEndDate;
    _remittanceDate = settings?.remittanceDate;
    _allowIbanEdition = settings?.allowIbanEdition ?? true;
    _isActive = settings?.isActive ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final service = context.read<TreasurySettingsService>();
    final auth = context.read<AuthService>();
    try {
      await service.saveSettings(
        TreasurySettings(
          id: '',
          year: _year,
          annualFeeAmount:
              double.tryParse(_feeCtrl.text.replaceAll(',', '.')) ?? 0,
          validationStartDate: _validationStart,
          validationEndDate: _validationEnd,
          remittanceDate: _remittanceDate,
          allowIbanEdition: _allowIbanEdition,
          isActive: _isActive,
        ),
        changedBy: auth.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración de tesorería guardada.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.canEditTreasurySettings) {
      return const Center(
          child: Text('No tienes permisos para configurar Tesorería.'));
    }
    final service = context.read<TreasurySettingsService>();

    return StreamBuilder<TreasurySettings?>(
      stream: service.watchSettingsByYear(_year),
      builder: (context, snap) {
        _fill(snap.data);
        return SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryDark, AppTheme.primaryColor],
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(32, 28, 32, 24),
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.white70, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Configuración de Tesorería',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Campaña anual',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              initialValue: '$_year',
                              decoration: const InputDecoration(
                                labelText: 'Año',
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => int.tryParse(v ?? '') == null
                                  ? 'Año válido'
                                  : null,
                              onChanged: (v) {
                                final parsed = int.tryParse(v);
                                if (parsed != null) _year = parsed;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _feeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cuota anual',
                                suffixText: '€',
                                prefixIcon: Icon(Icons.euro),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (v) {
                                final amount = double.tryParse(
                                    (v ?? '').replaceAll(',', '.'));
                                return amount == null || amount < 0
                                    ? 'Importe válido'
                                    : null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _DateTile(
                              label: 'Inicio validación bancaria',
                              value: _validationStart,
                              onTap: () async {
                                final picked =
                                    await _pickDate(_validationStart);
                                if (picked != null) {
                                  setState(() => _validationStart = picked);
                                }
                              },
                            ),
                            _DateTile(
                              label: 'Fin validación bancaria',
                              value: _validationEnd,
                              onTap: () async {
                                final picked = await _pickDate(_validationEnd);
                                if (picked != null) {
                                  setState(() => _validationEnd = picked);
                                }
                              },
                            ),
                            _DateTile(
                              label: 'Fecha prevista de remesa',
                              value: _remittanceDate,
                              onTap: () async {
                                final picked = await _pickDate(_remittanceDate);
                                if (picked != null) {
                                  setState(() => _remittanceDate = picked);
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Permitir edición de IBAN'),
                              subtitle: const Text(
                                  'Los cofrades podrán validar/modificar datos bancarios durante la campaña.'),
                              value: _allowIbanEdition,
                              onChanged: (v) =>
                                  setState(() => _allowIbanEdition = v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Campaña activa'),
                              subtitle: const Text(
                                  'Solo una configuración anual debería estar activa.'),
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label:
                                    Text(_saving ? 'Guardando...' : 'Guardar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 3),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(label),
      subtitle: Text(value == null
          ? 'Sin fecha'
          : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}'),
      trailing: const Icon(Icons.edit_calendar),
      onTap: onTap,
    );
  }
}
