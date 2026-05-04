import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/treasury/treasury_bank_validation_service.dart';
import 'package:boanerges1714/services/treasury/treasury_invoice_service.dart';
import 'package:boanerges1714/services/treasury/treasury_payment_service.dart';
import 'package:boanerges1714/services/treasury/treasury_pdf_service.dart';
import 'package:boanerges1714/services/treasury/treasury_remittance_service.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';
import 'package:boanerges1714/services/treasury/treasury_settings_service.dart';
import 'package:url_launcher/url_launcher.dart';

class BillingAndCollectionsScreen extends StatefulWidget {
  const BillingAndCollectionsScreen({super.key});

  @override
  State<BillingAndCollectionsScreen> createState() =>
      _BillingAndCollectionsScreenState();
}

class _BillingAndCollectionsScreenState
    extends State<BillingAndCollectionsScreen> {
  int _year = DateTime.now().year;
  bool _generating = false;
  bool _generatingFinal = false;
  bool _reviewing = false;
  bool _publishingValidation = false;
  bool _closingValidation = false;
  bool _generatingRemittance = false;
  bool _previewingRemittance = false;
  bool _savingCollectionSettings = false;
  List<TreasuryRemittanceRow> _remittancePreview = const [];

  @override
  Widget build(BuildContext context) {
    final service = context.read<TreasuryInvoiceService>();
    final auth = context.watch<AuthService>();

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
                  Icon(Icons.receipt_long, color: Colors.white70, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Facturación y cobros',
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
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<List<int>>(
                    stream: context
                        .read<TreasuryRepository>()
                        .watchAvailableTreasuryYears(),
                    builder: (context, yearSnap) {
                      final years = yearSnap.data ?? [_year];
                      final items = years.contains(_year)
                          ? years
                          : (List<int>.from(years)..insert(0, _year));
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
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<int>(
                                  initialValue: _year,
                                  decoration: const InputDecoration(
                                    labelText: 'Año / campaña histórica',
                                    prefixIcon: Icon(Icons.account_tree),
                                  ),
                                  items: items
                                      .map((year) => DropdownMenuItem(
                                            value: year,
                                            child: Text('Campaña $year'),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _year = value);
                                    }
                                  },
                                ),
                              ),
                              Text(
                                '${items.length} ejercicio${items.length == 1 ? '' : 's'} disponible${items.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const _FlowStepsCard(),
                  const SizedBox(height: 16),
                  StreamBuilder<TreasurySettings?>(
                    stream: context
                        .read<TreasurySettingsService>()
                        .watchSettingsByYear(_year),
                    builder: (context, snap) {
                      return _CollectionSettingsCard(
                        year: _year,
                        settings: snap.data,
                        canManage: auth.canManageTreasury,
                        saving: _savingCollectionSettings,
                        onYearChanged: (year) => setState(() => _year = year),
                        onSave: _saveCollectionSettings,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<TreasuryFeeDraft>>(
                    stream: service.getFeeDraftsByYear(_year),
                    builder: (context, snap) {
                      final drafts = snap.data ?? [];
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _FeeDraftsCard(
                        drafts: drafts,
                        canManage: auth.canManageTreasury,
                        onReview: (draft) => _reviewFeeDraft(draft),
                        onEdit: (draft) => _editFeeDraft(draft),
                        onGenerate: auth.canManageTreasury
                            ? () => _generate(false)
                            : null,
                        onReviewAll: auth.canManageTreasury
                            ? () => _reviewAllFeeDrafts()
                            : null,
                        generating: _generating,
                        reviewing: _reviewing,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<TreasuryBankValidation>>(
                    stream: context
                        .read<TreasuryBankValidationService>()
                        .getBankValidationsByYear(_year),
                    builder: (context, snap) {
                      return _BankValidationStepCard(
                        validations: snap.data ?? [],
                        canManage: auth.canManageTreasury,
                        publishing: _publishingValidation,
                        closing: _closingValidation,
                        onOpenDetail: () =>
                            context.go('/treasury/bank-validation'),
                        onPublish: () => _publishValidationCampaign(),
                        onClose: () => _closeValidationCampaign(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<TreasuryInvoice>>(
                    stream: service.getInvoicesByYear(_year),
                    builder: (context, snap) {
                      final invoices = snap.data ?? [];
                      return _FinalInvoicesStepCard(
                        invoices: invoices,
                        loading:
                            snap.connectionState == ConnectionState.waiting,
                        canManage: auth.canManageTreasury,
                        generating: _generatingFinal,
                        onGenerate: () => _generateFinalInvoices(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<TreasuryRemittance>>(
                    stream: context
                        .read<TreasuryRemittanceService>()
                        .getRemittancesByYear(_year),
                    builder: (context, snap) {
                      return _RemittanceStepCard(
                        remittances: snap.data ?? [],
                        rows: _remittancePreview,
                        canManage: auth.canManageTreasury,
                        generating: _generatingRemittance,
                        previewing: _previewingRemittance,
                        onPreview: _previewRemittance,
                        onGenerate: _generateRemittance,
                        onOpenUrl: _openUrl,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<TreasuryPayment>>(
                    stream: context
                        .read<TreasuryPaymentService>()
                        .getCollectionAttemptsByYear(_year),
                    builder: (context, snap) {
                      return _RemittanceResultsCard(
                        payments: snap.data ?? const [],
                        canManage: auth.canManageTreasury,
                        onMarkPaid: (payment) =>
                            _markPayment(payment, status: 'paid'),
                        onMarkRejected: (payment) => _rejectPayment(payment),
                        onRetry: (payment) => _markPayment(
                          payment,
                          status: 'retry_pending',
                        ),
                        onManualPending: (payment) => _markPayment(
                          payment,
                          status: 'manual_pending',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<TreasuryInvoice>>(
                    stream: service.getInvoicesByYear(_year),
                    builder: (context, invoiceSnap) {
                      return StreamBuilder<List<TreasuryPayment>>(
                        stream: context
                            .read<TreasuryPaymentService>()
                            .getCollectionAttemptsByYear(_year),
                        builder: (context, paymentSnap) {
                          return _ManualCollectionsCard(
                            invoices: invoiceSnap.data ?? const [],
                            payments: paymentSnap.data ?? const [],
                            canManage: auth.canManageTreasury,
                            onCollect: _recordManualPayment,
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

  Future<void> _reviewFeeDraft(TreasuryFeeDraft draft) async {
    final service = context.read<TreasuryInvoiceService>();
    final auth = context.read<AuthService>();
    try {
      await service.reviewFeeDraft(
        feeDraftId: draft.id,
        changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Precuota de ${draft.cofradeName} validada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _saveCollectionSettings(TreasurySettings settings) async {
    setState(() => _savingCollectionSettings = true);
    final service = context.read<TreasurySettingsService>();
    final auth = context.read<AuthService>();
    try {
      await service.saveSettings(
        settings,
        changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración del cobro guardada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _savingCollectionSettings = false);
    }
  }

  Future<void> _editFeeDraft(TreasuryFeeDraft draft) async {
    final amountController =
        TextEditingController(text: draft.amount.toStringAsFixed(2));
    final conceptController = TextEditingController(text: draft.concept);
    var paymentMethod = draft.paymentMethod;
    final result =
        await showDialog<({double amount, String concept, String method})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text('Editar precuota de ${draft.cofradeName}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: conceptController,
                  decoration: const InputDecoration(labelText: 'Concepto'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Importe'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(labelText: 'Forma de pago'),
                  items: const [
                    DropdownMenuItem(
                      value: 'bank_remittance',
                      child: Text('Domiciliación bancaria'),
                    ),
                    DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                  ],
                  onChanged: (value) =>
                      setLocalState(() => paymentMethod = value ?? 'cash'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(
                  amountController.text.replaceAll(',', '.'),
                );
                if (amount == null || amount <= 0) return;
                Navigator.pop(
                  ctx,
                  (
                    amount: amount,
                    concept: conceptController.text.trim(),
                    method: paymentMethod,
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    conceptController.dispose();
    if (result == null || !mounted) return;
    final service = context.read<TreasuryInvoiceService>();
    final auth = context.read<AuthService>();
    try {
      await service.updateFeeDraft(
        feeDraftId: draft.id,
        amount: result.amount,
        concept: result.concept,
        paymentMethod: result.method,
        changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precuota actualizada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _reviewAllFeeDrafts() async {
    setState(() => _reviewing = true);
    final service = context.read<TreasuryInvoiceService>();
    final auth = context.read<AuthService>();
    try {
      final count = await service.reviewAllFeeDrafts(
        year: _year,
        changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Precuotas validadas: $count.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _generate(bool force) async {
    setState(() => _generating = true);
    final service = context.read<TreasuryInvoiceService>();
    final auth = context.read<AuthService>();
    try {
      final result = await service.generateAnnualFees(
        year: _year,
        generatedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
        forceRegenerate: force,
      );
      if (!mounted) return;
      final message = 'Generadas ${result.invoicesCreated} precuotas.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      if (result.warnings.isNotEmpty) {
        _showWarnings(result.warnings);
      }
    } catch (e) {
      if (!mounted) return;
      final text = '$e';
      if (text.contains('Ya existen precuotas')) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Regenerar precuotas'),
            content: const Text(
              'Ya existen precuotas activas para este año. Si continúas, se cancelarán las anteriores y se creará una nueva generación.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Regenerar')),
            ],
          ),
        );
        if (confirm == true) await _generate(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(text.replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _generateFinalInvoices() async {
    final service = context.read<TreasuryInvoiceService>();
    final pdfService = context.read<TreasuryPdfService>();
    final validationService = context.read<TreasuryBankValidationService>();
    final auth = context.read<AuthService>();
    try {
      final validations =
          await validationService.getBankValidationsByYear(_year).first;
      final pending = validations.where((v) => v.status == 'pending').toList();
      final drafts = await service.getFeeDraftsByYear(_year).first;
      final pendingDrafts = drafts
          .where((draft) =>
              draft.status == 'approved' &&
              draft.paymentMethod == 'bank_remittance' &&
              !['validated', 'modified', 'locked']
                  .contains(draft.validationStatus) &&
              (draft.finalInvoiceId == null || draft.finalInvoiceId!.isEmpty))
          .toList();
      if ((pending.isNotEmpty || pendingDrafts.isNotEmpty) && mounted) {
        final pendingAmount = pending.isNotEmpty
            ? pending.fold<double>(0, (total, v) => total + v.totalAmount)
            : pendingDrafts.fold<double>(
                0,
                (total, draft) => total + draft.amount,
              );
        final pendingCount =
            pending.isNotEmpty ? pending.length : pendingDrafts.length;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hay validaciones pendientes'),
            content: Text(
              'Hay $pendingCount validaciones sin confirmar (${pendingAmount.toStringAsFixed(2)} €). Puedes generar igualmente las facturas, pero quedará auditado.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Generar igualmente'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
      setState(() => _generatingFinal = true);
      final result = await service.generateFinalInvoices(
        year: _year,
        generatedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      final invoices = await service.getInvoicesByYear(_year).first;
      final generatedInvoices = invoices
          .where((invoice) =>
              invoice.status == 'approved' &&
              invoice.pdfUrl.isEmpty &&
              invoice.sourceFeeDraftIds.isNotEmpty)
          .toList();
      for (final invoice in generatedInvoices) {
        await pdfService.generateAndUploadInvoicePdf(
          invoiceId: invoice.id,
          generatedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Generadas ${result.invoicesCreated} facturas definitivas, ${result.linesCreated} líneas y ${generatedInvoices.length} PDF.',
          ),
        ),
      );
      if (result.warnings.isNotEmpty) {
        _showWarnings(result.warnings);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _generatingFinal = false);
    }
  }

  Future<void> _publishValidationCampaign() async {
    setState(() => _publishingValidation = true);
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
            'Campaña publicada. Nuevas validaciones: ${result.createdCount}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _publishingValidation = false);
    }
  }

  Future<void> _closeValidationCampaign() async {
    setState(() => _closingValidation = true);
    final service = context.read<TreasuryBankValidationService>();
    final auth = context.read<AuthService>();
    try {
      final count = await service.closeBankValidationCampaign(
        year: _year,
        closedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Campaña cerrada. Validaciones bloqueadas: $count.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _closingValidation = false);
    }
  }

  Future<void> _previewRemittance() async {
    setState(() => _previewingRemittance = true);
    try {
      final rows =
          await context.read<TreasuryRemittanceService>().previewRows(_year);
      if (mounted) setState(() => _remittancePreview = rows);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _previewingRemittance = false);
    }
  }

  Future<void> _generateRemittance() async {
    setState(() => _generatingRemittance = true);
    final service = context.read<TreasuryRemittanceService>();
    final auth = context.read<AuthService>();
    try {
      final result = await service.generateRemittance(
        year: _year,
        generatedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      setState(() => _remittancePreview = result.rows);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Remesa generada: ${result.rows.length} recibos, ${result.remittance.totalAmount.toStringAsFixed(2)} €.',
          ),
        ),
      );
      if (result.warnings.isNotEmpty) _showWarnings(result.warnings);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _generatingRemittance = false);
    }
  }

  Future<void> _markPayment(
    TreasuryPayment payment, {
    required String status,
    String method = '',
    String reference = '',
    String rejectionReason = '',
  }) async {
    final service = context.read<TreasuryPaymentService>();
    final auth = context.read<AuthService>();
    try {
      await service.markPaymentAttempt(
        paymentId: payment.id,
        status: status,
        method: method,
        reference: reference,
        rejectionReason: rejectionReason,
        changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado de cobro actualizado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _rejectPayment(TreasuryPayment payment) async {
    final controller = TextEditingController(text: payment.rejectionReason);
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar recibo como rechazado'),
        content: TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Motivo del rechazo',
            prefixIcon: Icon(Icons.report_problem),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Marcar rechazado'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    await _markPayment(
      payment,
      status: 'rejected',
      rejectionReason: reason,
    );
  }

  Future<void> _recordManualPayment(TreasuryInvoice invoice) async {
    final service = context.read<TreasuryPaymentService>();
    final auth = context.read<AuthService>();
    String method = 'cash';
    final referenceController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text('Registrar cobro de ${invoice.invoiceNumber}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Método'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'bizum', child: Text('Bizum')),
                    DropdownMenuItem(
                        value: 'transfer', child: Text('Transferencia')),
                  ],
                  onChanged: (value) =>
                      setLocalState(() => method = value ?? 'cash'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Referencia opcional',
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Marcar cobrado'),
            ),
          ],
        ),
      ),
    );
    final reference = referenceController.text.trim();
    referenceController.dispose();
    if (confirmed != true) return;
    try {
      await service.createManualPayment(
        invoice: invoice,
        method: method,
        reference: reference,
        changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cobro manual registrado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _showWarnings(List<String> warnings) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Avisos de generación'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: warnings
                .map((w) => ListTile(
                      dense: true,
                      leading: Icon(Icons.warning_amber,
                          color: Colors.orange.shade700),
                      title: Text(w),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final TreasuryInvoice invoice;
  const _InvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final color = switch (invoice.status) {
      'approved' => AppTheme.accentColor,
      'paid' => AppTheme.accentColor,
      'pending_collection' => Colors.amber.shade800,
      'manual_pending' => Colors.blueGrey.shade700,
      'returned' => Colors.red.shade700,
      'cancelled' => Colors.red.shade700,
      _ => Colors.blue.shade700,
    };
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
          child: Icon(
            invoice.paymentMethod == 'cash'
                ? Icons.payments
                : Icons.account_balance,
            color: color,
          ),
        ),
        title: Text(invoice.invoiceNumber,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${invoice.holderName} · ${invoice.cofradeIds.length} línea${invoice.cofradeIds.length == 1 ? '' : 's'} · ${_status(invoice.status)}',
        ),
        trailing: Text(
          '${invoice.totalAmount.toStringAsFixed(2)} €',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        onTap: () => context.go('/treasury/invoices/${invoice.id}'),
      ),
    );
  }

  String _status(String status) {
    switch (status) {
      case 'approved':
        return 'Aprobada';
      case 'pending_collection':
        return 'Pendiente de resultado';
      case 'manual_pending':
        return 'Cobro manual';
      case 'paid':
        return 'Cobrada';
      case 'returned':
        return 'Impagada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Borrador';
    }
  }
}

class _FlowStepsCard extends StatelessWidget {
  const _FlowStepsCard();

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', 'Precuotas', Icons.playlist_add),
      ('2', 'Validación bancaria', Icons.account_balance),
      ('3', 'Facturas PDF', Icons.receipt_long),
      ('4', 'Remesas', Icons.table_view),
      ('5', 'Resultado', Icons.fact_check),
      ('6', 'Cobros manuales', Icons.payments),
    ];
    return Card(
      elevation: 0,
      color: const Color(0xFFF6F7F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          children: steps
              .map(
                (step) => SizedBox(
                  width: 160,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withAlpha(16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(step.$3,
                            size: 18, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          step.$2,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _CollectionSettingsCard extends StatefulWidget {
  final int year;
  final TreasurySettings? settings;
  final bool canManage;
  final bool saving;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<TreasurySettings> onSave;

  const _CollectionSettingsCard({
    required this.year,
    required this.settings,
    required this.canManage,
    required this.saving,
    required this.onYearChanged,
    required this.onSave,
  });

  @override
  State<_CollectionSettingsCard> createState() =>
      _CollectionSettingsCardState();
}

class _CollectionSettingsCardState extends State<_CollectionSettingsCard> {
  late final TextEditingController _yearController;
  late final TextEditingController _feeController;
  late final TextEditingController _messageController;
  DateTime? _validationStart;
  DateTime? _validationEnd;
  DateTime? _remittanceDate;
  bool _allowIbanEdition = true;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _yearController = TextEditingController();
    _feeController = TextEditingController();
    _messageController = TextEditingController();
    _load(widget.year, widget.settings);
  }

  @override
  void didUpdateWidget(covariant _CollectionSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year ||
        oldWidget.settings?.id != widget.settings?.id ||
        oldWidget.settings?.updatedAt != widget.settings?.updatedAt) {
      _load(widget.year, widget.settings);
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _feeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _load(int year, TreasurySettings? settings) {
    _yearController.text = '$year';
    _feeController.text = (settings?.annualFeeAmount ?? 0).toStringAsFixed(2);
    _messageController.text = settings?.validationMessage.trim().isNotEmpty ==
            true
        ? settings!.validationMessage
        : 'Tienes pendiente la validación de tus datos de cobro para la cuota anual.';
    _validationStart = settings?.validationStartDate;
    _validationEnd = settings?.validationEndDate;
    _remittanceDate = settings?.remittanceDate;
    _allowIbanEdition = settings?.allowIbanEdition ?? true;
    _isActive = settings?.isActive ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final configured = widget.settings != null;
    const bottleGreen = Color(0xFF0F3D2E);
    return Card(
      elevation: 0,
      color: const Color(0xFFEEF5F1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: configured ? const Color(0xFFB7D0C4) : Colors.orange.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: bottleGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Configuración del cobro',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _StatusPill(
                  text: configured ? 'Guardada' : 'Pendiente',
                  color: configured ? bottleGreen : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Define aquí la cuota, fechas y parámetros necesarios para precuotas, validación bancaria y remesas.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 130,
                  child: TextFormField(
                    controller: _yearController,
                    enabled: widget.canManage,
                    decoration: const InputDecoration(
                      labelText: 'Año',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: _changeYear,
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextFormField(
                    controller: _feeController,
                    enabled: widget.canManage,
                    decoration: const InputDecoration(
                      labelText: 'Cuota anual',
                      suffixText: '€',
                      prefixIcon: Icon(Icons.euro),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                _DateActionChip(
                  label: 'Inicio validación',
                  value: _fmt(_validationStart),
                  enabled: widget.canManage,
                  onTap: () => _pickDate(
                    initial: _validationStart,
                    onPicked: (date) => setState(() => _validationStart = date),
                  ),
                ),
                _DateActionChip(
                  label: 'Fin validación',
                  value: _fmt(_validationEnd),
                  enabled: widget.canManage,
                  onTap: () => _pickDate(
                    initial: _validationEnd,
                    onPicked: (date) => setState(() => _validationEnd = date),
                  ),
                ),
                _DateActionChip(
                  label: 'Fecha remesa',
                  value: _fmt(_remittanceDate),
                  enabled: widget.canManage,
                  onTap: () => _pickDate(
                    initial: _remittanceDate,
                    onPicked: (date) => setState(() => _remittanceDate = date),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageController,
              enabled: widget.canManage,
              decoration: const InputDecoration(
                labelText: 'Mensaje/banner de validación',
                prefixIcon: Icon(Icons.campaign),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Permitir edición de IBAN'),
                    value: _allowIbanEdition,
                    onChanged: widget.canManage
                        ? (value) => setState(() => _allowIbanEdition = value)
                        : null,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Campaña activa'),
                    value: _isActive,
                    onChanged: widget.canManage
                        ? (value) => setState(() => _isActive = value)
                        : null,
                  ),
                ),
                if (widget.canManage)
                  ElevatedButton.icon(
                    onPressed: widget.saving ? null : _save,
                    icon: widget.saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(widget.saving ? 'Guardando...' : 'Guardar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _changeYear(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 2000 || parsed > 2100) return;
    widget.onYearChanged(parsed);
  }

  void _save() {
    final parsedYear = int.tryParse(_yearController.text.trim());
    if (parsedYear == null || parsedYear < 2000 || parsedYear > 2100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un año válido.')),
      );
      return;
    }
    final amount = double.tryParse(_feeController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce una cuota anual válida.')),
      );
      return;
    }
    widget.onYearChanged(parsedYear);
    widget.onSave(
      TreasurySettings(
        id: widget.settings?.id ?? '$parsedYear',
        year: parsedYear,
        annualFeeAmount: amount,
        validationStartDate: _validationStart,
        validationEndDate: _validationEnd,
        remittanceDate: _remittanceDate,
        allowIbanEdition: _allowIbanEdition,
        isActive: _isActive,
        validationMessage: _messageController.text.trim(),
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final year = int.tryParse(_yearController.text.trim()) ?? widget.year;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(year),
      firstDate: DateTime(year - 1),
      lastDate: DateTime(year + 2),
    );
    if (picked != null) onPicked(picked);
  }

  String _fmt(DateTime? date) {
    if (date == null) return 'Sin definir';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _DateActionChip extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  const _DateActionChip({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.event, size: 18),
      label: Text('$label: $value'),
      onPressed: enabled ? onTap : null,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _FeeDraftsCard extends StatelessWidget {
  final List<TreasuryFeeDraft> drafts;
  final bool canManage;
  final ValueChanged<TreasuryFeeDraft> onReview;
  final ValueChanged<TreasuryFeeDraft> onEdit;
  final VoidCallback? onGenerate;
  final VoidCallback? onReviewAll;
  final bool generating;
  final bool reviewing;

  const _FeeDraftsCard({
    required this.drafts,
    required this.canManage,
    required this.onReview,
    required this.onEdit,
    this.onGenerate,
    this.onReviewAll,
    this.generating = false,
    this.reviewing = false,
  });

  @override
  Widget build(BuildContext context) {
    final draftCount = drafts.where((d) => d.status == 'draft').length;
    final approved = drafts.where((d) => d.status == 'approved').length;
    final cancelled = drafts.where((d) => d.status == 'cancelled').length;
    final pending = drafts.where((d) => d.validationStatus == 'pending').length;
    final bankDrafts = drafts.where((d) => _isBank(d.paymentMethod)).toList();
    final cashDrafts = drafts.where((d) => !_isBank(d.paymentMethod)).toList();
    final bankAmount =
        bankDrafts.fold<double>(0, (total, draft) => total + draft.amount);
    final cashAmount =
        cashDrafts.fold<double>(0, (total, draft) => total + draft.amount);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Precuotas',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (canManage) ...[
                  OutlinedButton.icon(
                    onPressed: generating ? null : onGenerate,
                    icon: generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.playlist_add),
                    label: Text(generating ? 'Generando...' : 'Generar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed:
                        reviewing || draftCount == 0 ? null : onReviewAll,
                    icon: reviewing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fact_check),
                    label: Text(reviewing ? 'Aprobando...' : 'Aprobar todas'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DraftMetric(label: 'Total', value: drafts.length),
                _DraftMetric(label: 'Pendientes de validar', value: pending),
                _DraftMetric(label: 'Borrador', value: draftCount),
                _DraftMetric(label: 'Aprobadas', value: approved),
                _DraftMetric(label: 'Canceladas', value: cancelled),
                _DraftMetric(label: 'Domiciliadas', value: bankDrafts.length),
                _DraftMetric(label: 'Efectivo', value: cashDrafts.length),
                _AmountMetric(label: 'Importe domiciliado', value: bankAmount),
                _AmountMetric(label: 'Importe efectivo', value: cashAmount),
              ],
            ),
            if (drafts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('No hay precuotas generadas para este año.'),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 560),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: drafts.length,
                    itemBuilder: (context, index) {
                      final draft = drafts[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          draft.initialPaymentMethod == 'cash'
                              ? Icons.payments
                              : Icons.account_balance,
                          color: draft.status == 'invoiced'
                              ? AppTheme.accentColor
                              : AppTheme.primaryColor,
                        ),
                        title: Text(draft.cofradeName),
                        subtitle: Text(
                          '${_status(draft.status)} · ${_validation(draft.validationStatus)}',
                        ),
                        trailing: SizedBox(
                          width:
                              canManage && draft.status == 'draft' ? 230 : 90,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${draft.amount.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              if (canManage && draft.status == 'draft') ...[
                                IconButton(
                                  tooltip: 'Editar precuota',
                                  onPressed: () => onEdit(draft),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  tooltip: 'Aprobar precuota',
                                  onPressed: () => onReview(draft),
                                  icon: const Icon(Icons.check_circle),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _status(String status) {
    switch (status) {
      case 'ready_for_invoice':
        return 'Lista para facturar';
      case 'approved':
        return 'Aprobada';
      case 'invoiced':
        return 'Facturada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Borrador';
    }
  }

  String _validation(String status) {
    switch (status) {
      case 'validated':
        return 'Validada';
      case 'modified':
        return 'IBAN modificado';
      case 'cash':
        return 'Efectivo';
      case 'locked':
        return 'Bloqueada';
      default:
        return 'Pendiente de validación';
    }
  }

  bool _isBank(String method) {
    final normalized = method.trim().toLowerCase();
    return normalized == 'bank_remittance' ||
        normalized == 'direct_debit' ||
        normalized == 'domiciliacion' ||
        normalized == 'domiciliación' ||
        normalized == 'bank';
  }
}

class _BankValidationStepCard extends StatelessWidget {
  final List<TreasuryBankValidation> validations;
  final bool canManage;
  final bool publishing;
  final bool closing;
  final VoidCallback onOpenDetail;
  final VoidCallback onPublish;
  final VoidCallback onClose;

  const _BankValidationStepCard({
    required this.validations,
    required this.canManage,
    required this.publishing,
    required this.closing,
    required this.onOpenDetail,
    required this.onPublish,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final pending = validations.where((v) => v.status == 'pending').length;
    final validated = validations.where((v) => v.status == 'validated').length;
    final modified = validations.where((v) => v.status == 'modified').length;
    final locked = validations.where((v) => v.status == 'locked').length;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Validación bancaria',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.visibility),
                  label: const Text('Ver detalle'),
                ),
                if (canManage) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: publishing ? null : onPublish,
                    icon: publishing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.campaign),
                    label: Text(publishing ? 'Publicando...' : 'Publicar'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: closing ? null : onClose,
                    icon: closing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock),
                    label: Text(closing ? 'Cerrando...' : 'Cerrar campaña'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DraftMetric(label: 'Pendientes', value: pending),
                _DraftMetric(label: 'Confirmadas', value: validated),
                _DraftMetric(label: 'Modificadas', value: modified),
                _DraftMetric(label: 'Bloqueadas', value: locked),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinalInvoicesStepCard extends StatelessWidget {
  final List<TreasuryInvoice> invoices;
  final bool loading;
  final bool canManage;
  final bool generating;
  final VoidCallback onGenerate;

  const _FinalInvoicesStepCard({
    required this.invoices,
    required this.loading,
    required this.canManage,
    required this.generating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final withPdf =
        invoices.where((invoice) => invoice.pdfUrl.isNotEmpty).length;
    final withUnvalidated =
        invoices.where((invoice) => invoice.hasUnvalidatedRecords).length;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Facturas definitivas PDF',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (canManage)
                  ElevatedButton.icon(
                    onPressed: generating ? null : onGenerate,
                    icon: generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label:
                        Text(generating ? 'Generando...' : 'Generar facturas'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DraftMetric(label: 'Facturas', value: invoices.length),
                _DraftMetric(label: 'Con PDF', value: withPdf),
                _DraftMetric(label: 'No validadas', value: withUnvalidated),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (invoices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No hay facturas definitivas para este filtro.'),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: invoices.length,
                  itemBuilder: (context, index) =>
                      _InvoiceTile(invoice: invoices[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RemittanceStepCard extends StatelessWidget {
  final List<TreasuryRemittance> remittances;
  final List<TreasuryRemittanceRow> rows;
  final bool canManage;
  final bool generating;
  final bool previewing;
  final VoidCallback onPreview;
  final VoidCallback onGenerate;
  final ValueChanged<String> onOpenUrl;

  const _RemittanceStepCard({
    required this.remittances,
    required this.rows,
    required this.canManage,
    required this.generating,
    required this.previewing,
    required this.onPreview,
    required this.onGenerate,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final remittedAmount =
        remittances.fold<double>(0, (total, item) => total + item.totalAmount);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_view, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Remesas',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                OutlinedButton.icon(
                  onPressed: previewing ? null : onPreview,
                  icon: previewing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.preview),
                  label: Text(previewing ? 'Cargando...' : 'Previsualizar'),
                ),
                if (canManage) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: generating ? null : onGenerate,
                    icon: generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(generating ? 'Generando...' : 'Generar remesa'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DraftMetric(label: 'Histórico', value: remittances.length),
                _DraftMetric(label: 'Preview', value: rows.length),
                _AmountMetric(label: 'Importe remesado', value: remittedAmount),
              ],
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 460),
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Factura')),
                        DataColumn(label: Text('Titular')),
                        DataColumn(label: Text('IBAN')),
                        DataColumn(label: Text('Importe')),
                        DataColumn(label: Text('Concepto')),
                      ],
                      rows: rows
                          .map(
                            (row) => DataRow(
                              cells: [
                                DataCell(Text(row.invoiceNumber)),
                                DataCell(Text(row.holderName)),
                                DataCell(Text(row.debtorIban)),
                                DataCell(
                                    Text('${row.amount.toStringAsFixed(2)} €')),
                                DataCell(Text(row.concept)),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ],
            if (remittances.isNotEmpty) ...[
              const Divider(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: remittances.length,
                  itemBuilder: (context, index) {
                    final item = remittances[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history),
                      title: Text(
                        '${item.invoiceIds.length} recibos · ${item.totalAmount.toStringAsFixed(2)} €',
                      ),
                      subtitle: Text(
                        item.unvalidatedCount > 0
                            ? '${item.unvalidatedCount} facturas con datos no validados'
                            : 'Sin avisos de validación',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: item.fileUrlCsv.isEmpty
                                ? null
                                : () => onOpenUrl(item.fileUrlCsv),
                            child: const Text('CSV'),
                          ),
                          TextButton(
                            onPressed: item.fileUrlXlsx.isEmpty
                                ? null
                                : () => onOpenUrl(item.fileUrlXlsx),
                            child: const Text('Excel'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RemittanceResultsCard extends StatelessWidget {
  final List<TreasuryPayment> payments;
  final bool canManage;
  final ValueChanged<TreasuryPayment> onMarkPaid;
  final ValueChanged<TreasuryPayment> onMarkRejected;
  final ValueChanged<TreasuryPayment> onRetry;
  final ValueChanged<TreasuryPayment> onManualPending;

  const _RemittanceResultsCard({
    required this.payments,
    required this.canManage,
    required this.onMarkPaid,
    required this.onMarkRejected,
    required this.onRetry,
    required this.onManualPending,
  });

  @override
  Widget build(BuildContext context) {
    final remittancePayments = payments
        .where((payment) =>
            payment.method == 'bank_remittance' ||
            payment.remittanceId.isNotEmpty)
        .toList();
    final pending = remittancePayments
        .where((payment) => payment.status == 'pending')
        .length;
    final paid =
        remittancePayments.where((payment) => payment.status == 'paid').length;
    final rejected = remittancePayments
        .where((payment) => payment.status == 'rejected')
        .length;
    final retry = remittancePayments
        .where((payment) => payment.status == 'retry_pending')
        .length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Resultado de remesas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'La remesa registra el intento de cobro; el dinero solo se considera cobrado cuando se marca el resultado.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DraftMetric(label: 'Pendientes', value: pending),
                _DraftMetric(label: 'Cobrados', value: paid),
                _DraftMetric(label: 'Rechazados', value: rejected),
                _DraftMetric(label: 'Para reintento', value: retry),
              ],
            ),
            if (remittancePayments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('Aún no hay recibos incluidos en remesas.'),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 560),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: remittancePayments.length,
                    itemBuilder: (context, index) {
                      final payment = remittancePayments[index];
                      return _PaymentAttemptTile(
                        payment: payment,
                        canManage: canManage,
                        onMarkPaid: onMarkPaid,
                        onMarkRejected: onMarkRejected,
                        onRetry: onRetry,
                        onManualPending: onManualPending,
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManualCollectionsCard extends StatelessWidget {
  final List<TreasuryInvoice> invoices;
  final List<TreasuryPayment> payments;
  final bool canManage;
  final ValueChanged<TreasuryInvoice> onCollect;

  const _ManualCollectionsCard({
    required this.invoices,
    required this.payments,
    required this.canManage,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final pendingInvoices = invoices
        .where((invoice) =>
            invoice.status != 'paid' &&
            invoice.status != 'cancelled' &&
            (invoice.paymentMethod == 'cash' ||
                invoice.paymentMethod == 'manual' ||
                invoice.status == 'returned' ||
                invoice.status == 'manual_pending'))
        .toList();
    final manualPayments = payments
        .where((payment) =>
            payment.status == 'paid' &&
            (payment.method == 'cash' ||
                payment.method == 'bizum' ||
                payment.method == 'transfer'))
        .toList();
    final totalPending = pendingInvoices.fold<double>(
      0,
      (total, invoice) => total + invoice.totalAmount,
    );
    final totalCollected = manualPayments.fold<double>(
      0,
      (total, payment) => total + payment.amount,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cobros manuales',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Registra recuperaciones por efectivo, Bizum o transferencia sobre facturas existentes.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DraftMetric(
                    label: 'Pendientes', value: pendingInvoices.length),
                _AmountMetric(label: 'Importe pendiente', value: totalPending),
                _DraftMetric(label: 'Cobrados', value: manualPayments.length),
                _AmountMetric(label: 'Importe cobrado', value: totalCollected),
              ],
            ),
            if (pendingInvoices.isEmpty && manualPayments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('No hay facturas pendientes de cobro manual.'),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 560),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: pendingInvoices.length + manualPayments.length,
                    itemBuilder: (context, index) {
                      if (index >= pendingInvoices.length) {
                        final payment =
                            manualPayments[index - pendingInvoices.length];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check_circle,
                              color: AppTheme.accentColor),
                          title: Text(payment.invoiceNumber.isEmpty
                              ? payment.invoiceId
                              : payment.invoiceNumber),
                          subtitle: Text(
                            '${payment.cofradeName} · COBRADO · ${_paymentMethod(payment.method)}${payment.reference.isEmpty ? '' : ' · ${payment.reference}'}',
                          ),
                          trailing: Text(
                            '${payment.amount.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentColor,
                            ),
                          ),
                        );
                      }
                      final invoice = pendingInvoices[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.receipt),
                        title: Text(invoice.invoiceNumber),
                        subtitle: Text(
                          '${invoice.holderName} · ${_invoiceStatus(invoice.status)} · ${_paymentMethod(invoice.paymentMethod)}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${invoice.totalAmount.toStringAsFixed(2)} €',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (canManage)
                              ElevatedButton.icon(
                                onPressed: () => onCollect(invoice),
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Cobrar'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _invoiceStatus(String status) {
    switch (status) {
      case 'pending_collection':
        return 'Pendiente de resultado';
      case 'manual_pending':
        return 'Cobro manual';
      case 'returned':
        return 'Impagada';
      case 'approved':
        return 'Pendiente';
      default:
        return status;
    }
  }

  String _paymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Efectivo';
      case 'bank_remittance':
        return 'Domiciliación';
      default:
        return method;
    }
  }
}

class _PaymentAttemptTile extends StatelessWidget {
  final TreasuryPayment payment;
  final bool canManage;
  final ValueChanged<TreasuryPayment> onMarkPaid;
  final ValueChanged<TreasuryPayment> onMarkRejected;
  final ValueChanged<TreasuryPayment> onRetry;
  final ValueChanged<TreasuryPayment> onManualPending;

  const _PaymentAttemptTile({
    required this.payment,
    required this.canManage,
    required this.onMarkPaid,
    required this.onMarkRejected,
    required this.onRetry,
    required this.onManualPending,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (payment.status) {
      'paid' => AppTheme.accentColor,
      'rejected' => Colors.red.shade700,
      'retry_pending' => Colors.amber.shade800,
      'manual_pending' => Colors.blueGrey.shade700,
      _ => Colors.amber.shade800,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.account_balance_wallet, color: color),
      title: Text(payment.invoiceNumber.isEmpty
          ? payment.invoiceId
          : payment.invoiceNumber),
      subtitle: Text(
        [
          payment.cofradeName,
          _status(payment.status),
          if (payment.resultDate != null) _fmt(payment.resultDate!),
          if (payment.rejectionReason.isNotEmpty) payment.rejectionReason,
        ].where((item) => item.isNotEmpty).join(' · '),
      ),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${payment.amount.toStringAsFixed(2)} €',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          if (canManage && payment.status != 'paid') ...[
            IconButton(
              tooltip: 'Marcar cobrado',
              onPressed: () => onMarkPaid(payment),
              icon: const Icon(Icons.check_circle),
            ),
            IconButton(
              tooltip: 'Marcar rechazado',
              onPressed: () => onMarkRejected(payment),
              icon: const Icon(Icons.cancel),
            ),
            if (payment.status == 'rejected')
              IconButton(
                tooltip: 'Reintentar en próxima remesa',
                onPressed: () => onRetry(payment),
                icon: const Icon(Icons.replay),
              ),
            IconButton(
              tooltip: 'Pasar a cobro manual',
              onPressed: () => onManualPending(payment),
              icon: const Icon(Icons.payments),
            ),
          ],
        ],
      ),
    );
  }

  String _status(String status) {
    switch (status) {
      case 'paid':
        return 'Cobrado';
      case 'rejected':
        return 'Rechazado';
      case 'retry_pending':
        return 'Pendiente de reintento';
      case 'manual_pending':
        return 'Cobro manual';
      default:
        return 'Pendiente';
    }
  }

  String _fmt(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _AmountMetric extends StatelessWidget {
  final String label;
  final double value;

  const _AmountMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text('${value.toStringAsFixed(2)} €',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DraftMetric extends StatelessWidget {
  final String label;
  final int value;

  const _DraftMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text('$value',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
