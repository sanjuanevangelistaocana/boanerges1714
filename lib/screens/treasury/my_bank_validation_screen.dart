import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/treasury/treasury_bank_validation_service.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';

class MyBankValidationScreen extends StatefulWidget {
  const MyBankValidationScreen({super.key});

  @override
  State<MyBankValidationScreen> createState() => _MyBankValidationScreenState();
}

class _MyBankValidationScreenState extends State<MyBankValidationScreen> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final userId = auth.userId;
    final service = context.read<TreasuryBankValidationService>();
    final repository = context.read<TreasuryRepository>();

    if (userId == null) {
      return const Center(child: Text('Debes iniciar sesión.'));
    }

    return StreamBuilder<List<TreasuryBankValidation>>(
      stream: service.watchMyBankValidations(
        userId,
        cofradeId: auth.cofrade?.id,
      ),
      builder: (context, snap) {
        final validations = (snap.data ?? [])
            .where((v) =>
                v.status == 'pending' ||
                (v.status == 'modified' && v.validatedAt == null))
            .toList();
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (validations.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No tienes validaciones bancarias pendientes.'),
            ),
          );
        }
        final validation = validations.first;
        return StreamBuilder<TreasurySettings?>(
          stream: repository.watchSettingsByYear(validation.year),
          builder: (context, settingsSnap) {
            final settings = settingsSnap.data;
            final isOpen = repository.isValidationCampaignOpen(settings);
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
                          Icon(Icons.account_balance,
                              color: Colors.white70, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Validación bancaria',
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
                      child: Column(
                        children: [
                          _ValidationCard(
                            validation: validation,
                            settings: settings,
                            isOpen: isOpen,
                            working: _working,
                            onConfirm: () => _confirm(validation),
                            onModify: settings?.allowIbanEdition == true
                                ? () => context.go('/profile?editBank=1')
                                : null,
                          ),
                          if (!isOpen)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: _ClosedCampaignNotice(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirm(TreasuryBankValidation validation) async {
    setState(() => _working = true);
    final service = context.read<TreasuryBankValidationService>();
    final auth = context.read<AuthService>();
    try {
      await service.confirmBankValidation(
        validationId: validation.id,
        updatedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos bancarios confirmados.')),
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

class _ValidationCard extends StatelessWidget {
  final TreasuryBankValidation validation;
  final TreasurySettings? settings;
  final bool isOpen;
  final bool working;
  final VoidCallback onConfirm;
  final VoidCallback? onModify;

  const _ValidationCard({
    required this.validation,
    required this.settings,
    required this.isOpen,
    required this.working,
    required this.onConfirm,
    required this.onModify,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance,
                      color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        validation.invoiceNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Año ${validation.year} · ${_statusLabel(validation.status)}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _InfoRow(
                label: 'Importe',
                value: '${validation.totalAmount.toStringAsFixed(2)} €'),
            _InfoRow(label: 'IBAN actual', value: validation.ibanMasked),
            if (validation.newIbanMasked.isNotEmpty)
              _InfoRow(
                  label: 'IBAN propuesto', value: validation.newIbanMasked),
            _InfoRow(
              label: 'Cofrades',
              value: validation.cofradeNames.join(', '),
            ),
            if (settings?.validationStartDate != null &&
                settings?.validationEndDate != null)
              _InfoRow(
                label: 'Campaña',
                value:
                    '${dateFormat.format(settings!.validationStartDate!)} - ${dateFormat.format(settings!.validationEndDate!)}',
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isOpen && !working ? onConfirm : null,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Confirmar datos'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isOpen && !working ? onModify : null,
                    icon: const Icon(Icons.edit),
                    label: const Text('Modificar IBAN'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

class _ClosedCampaignNotice extends StatelessWidget {
  const _ClosedCampaignNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.amber.shade900),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'La campaña de validación bancaria está cerrada. No se pueden confirmar ni modificar datos.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Sin dato' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
