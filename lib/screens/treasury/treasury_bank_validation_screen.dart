import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/treasury/treasury_bank_validation_service.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';

class TreasuryBankValidationScreen extends StatefulWidget {
  const TreasuryBankValidationScreen({super.key});

  @override
  State<TreasuryBankValidationScreen> createState() =>
      _TreasuryBankValidationScreenState();
}

class _TreasuryBankValidationScreenState
    extends State<TreasuryBankValidationScreen> {
  int _year = DateTime.now().year;
  String _statusFilter = 'all';
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TreasuryRepository>();
    final validationService = context.read<TreasuryBankValidationService>();
    final auth = context.watch<AuthService>();
    final canManage = auth.canManageTreasury;

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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
              child: Row(
                children: [
                  const Icon(Icons.account_balance,
                      color: Colors.white70, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Validación bancaria',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (canManage)
                    ElevatedButton.icon(
                      onPressed: _working ? null : () => _publishCampaign(),
                      icon: const Icon(Icons.campaign),
                      label: const Text('Publicar campaña'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  if (canManage) const SizedBox(width: 8),
                  if (canManage)
                    OutlinedButton.icon(
                      onPressed: _working ? null : () => _lockValidations(),
                      icon: const Icon(Icons.lock),
                      label: const Text('Bloquear cerradas'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1150),
              child: Column(
                children: [
                  _FiltersCard(
                    year: _year,
                    statusFilter: _statusFilter,
                    onYearChanged: (year) => setState(() => _year = year),
                    onStatusChanged: (status) =>
                        setState(() => _statusFilter = status),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<TreasurySettings?>(
                    stream: repository.watchSettingsByYear(_year),
                    builder: (context, settingsSnap) {
                      final settings = settingsSnap.data;
                      final isOpen =
                          repository.isValidationCampaignOpen(settings);
                      return StreamBuilder<List<TreasuryFeeDraft>>(
                        stream: repository.getFeeDraftsByYear(_year),
                        builder: (context, draftSnap) {
                          final draftCount = (draftSnap.data ?? []).length;
                          return StreamBuilder<List<TreasuryBankValidation>>(
                            stream: validationService
                                .getBankValidationsByYear(_year),
                            builder: (context, validationSnap) {
                              final validations = validationSnap.data ?? [];
                              final filtered = validations
                                  .where((v) =>
                                      _statusFilter == 'all' ||
                                      v.status == _statusFilter)
                                  .toList();
                              return Column(
                                children: [
                                  _ValidationSummaryCard(
                                    settings: settings,
                                    isOpen: isOpen,
                                    feeDraftCount: draftCount,
                                    validations: validations,
                                  ),
                                  const SizedBox(height: 16),
                                  _ValidationList(
                                    validations: filtered,
                                    loading: validationSnap.connectionState ==
                                        ConnectionState.waiting,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _publishCampaign() async {
    setState(() => _working = true);
    final service = context.read<TreasuryBankValidationService>();
    final auth = context.read<AuthService>();
    try {
      final result = await service.publishBankValidationCampaign(
        year: _year,
        changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Campaña publicada. Validaciones creadas ${result.createdCount}. Existentes ${result.existingCount}. Omitidas ${result.skippedCount}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _lockValidations() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquear validaciones'),
        content: Text(
          'Se bloquearán las validaciones no bloqueadas de $_year si la campaña está cerrada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _working = true);
    final service = context.read<TreasuryBankValidationService>();
    final auth = context.read<AuthService>();
    try {
      final count = await service.lockClosedBankValidations(
        year: _year,
        lockedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Validaciones bloqueadas: $count.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

class _FiltersCard extends StatelessWidget {
  final int year;
  final String statusFilter;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<String> onStatusChanged;

  const _FiltersCard({
    required this.year,
    required this.statusFilter,
    required this.onYearChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 150,
              child: TextFormField(
                initialValue: '$year',
                decoration: const InputDecoration(
                  labelText: 'Año',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) onYearChanged(parsed);
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: statusFilter,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Todos')),
                  DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                  DropdownMenuItem(value: 'validated', child: Text('Validado')),
                  DropdownMenuItem(
                      value: 'modified', child: Text('Modificado')),
                  DropdownMenuItem(value: 'locked', child: Text('Bloqueado')),
                ],
                onChanged: (value) => onStatusChanged(value ?? 'all'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationSummaryCard extends StatelessWidget {
  final TreasurySettings? settings;
  final bool isOpen;
  final int feeDraftCount;
  final List<TreasuryBankValidation> validations;

  const _ValidationSummaryCard({
    required this.settings,
    required this.isOpen,
    required this.feeDraftCount,
    required this.validations,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final start = settings?.validationStartDate;
    final end = settings?.validationEndDate;
    return Card(
      elevation: 0,
      color: isOpen ? AppTheme.accentColor.withAlpha(12) : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOpen
              ? AppTheme.accentColor.withAlpha(70)
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOpen ? Icons.lock_open : Icons.lock_outline,
                  color: isOpen ? AppTheme.accentColor : Colors.grey.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isOpen ? 'Campaña abierta' : 'Campaña cerrada',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  start == null || end == null
                      ? 'Sin fechas'
                      : '${dateFormat.format(start)} - ${dateFormat.format(end)}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MiniMetric(label: 'Precuotas bancarias', value: feeDraftCount),
                _MiniMetric(
                    label: 'Pendientes',
                    value:
                        validations.where((v) => v.status == 'pending').length),
                _MiniMetric(
                    label: 'Validadas',
                    value: validations
                        .where((v) => v.status == 'validated')
                        .length),
                _MiniMetric(
                    label: 'Modificadas',
                    value: validations
                        .where((v) => v.status == 'modified')
                        .length),
                _MiniMetric(
                    label: 'Bloqueadas',
                    value:
                        validations.where((v) => v.status == 'locked').length),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final int value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text('$value',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}

class _ValidationList extends StatelessWidget {
  final List<TreasuryBankValidation> validations;
  final bool loading;

  const _ValidationList({required this.validations, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (validations.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No hay validaciones para este filtro.')),
        ),
      );
    }
    return Column(
      children: validations.map((validation) {
        final color = _statusColor(validation.status);
        final when = validation.validatedAt ??
            validation.changedAt ??
            validation.lockedAt ??
            validation.updatedAt;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.account_balance, color: color),
            ),
            title: Text(
              validation.invoiceNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${validation.cofradeNames.join(', ')} · ${validation.ibanMasked} · ${_statusLabel(validation.status)}'
              '${when == null ? '' : ' · ${DateFormat('dd/MM/yyyy').format(when)}'}'
              '${validation.updatedBy == null ? '' : ' · ${validation.updatedBy}'}',
            ),
            trailing: Text(
              '${validation.totalAmount.toStringAsFixed(2)} €',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'validated':
        return AppTheme.accentColor;
      case 'modified':
        return Colors.amber.shade800;
      case 'locked':
        return Colors.grey.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'validated':
        return 'Validado';
      case 'modified':
        return 'Modificado';
      case 'locked':
        return 'Bloqueado';
      default:
        return 'Pendiente';
    }
  }
}
