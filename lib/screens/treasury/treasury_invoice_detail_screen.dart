import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/treasury/treasury_invoice_service.dart';
import 'package:boanerges1714/services/treasury/treasury_pdf_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TreasuryInvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  const TreasuryInvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<TreasuryInvoiceDetailScreen> createState() =>
      _TreasuryInvoiceDetailScreenState();
}

class _TreasuryInvoiceDetailScreenState
    extends State<TreasuryInvoiceDetailScreen> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final service = context.read<TreasuryInvoiceService>();
    final auth = context.watch<AuthService>();
    return FutureBuilder<TreasuryInvoice?>(
      future: service.getInvoice(widget.invoiceId),
      builder: (context, snap) {
        final invoice = snap.data;
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (invoice == null) {
          return const Center(child: Text('Factura no encontrada.'));
        }
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
                      const Icon(Icons.receipt_long,
                          color: Colors.white70, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (auth.canManageTreasury && invoice.status == 'draft')
                        ElevatedButton.icon(
                          onPressed: _processing
                              ? null
                              : () => _confirmApprove(invoice),
                          icon: const Icon(Icons.verified),
                          label: const Text('Aprobar factura'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                          ),
                        ),
                      if (invoice.pdfUrl.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(invoice.pdfUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Ver PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                          ),
                        ),
                      if (auth.canManageTreasury &&
                          invoice.status == 'approved' &&
                          invoice.pdfUrl.isEmpty)
                        ElevatedButton.icon(
                          onPressed:
                              _processing ? null : () => _generatePdf(invoice),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Generar PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (auth.canManageTreasury &&
                          invoice.status != 'cancelled')
                        OutlinedButton.icon(
                          onPressed: _processing
                              ? null
                              : () => _confirmCancel(invoice),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancelar'),
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
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _InfoRow(
                                  label: 'Titular', value: invoice.holderName),
                              _InfoRow(
                                  label: 'Estado',
                                  value: _status(invoice.status)),
                              _InfoRow(
                                  label: 'Tipo',
                                  value: invoice.paymentMethod == 'cash'
                                      ? 'Efectivo'
                                      : 'Domiciliación'),
                              if (invoice.ibanMasked.isNotEmpty)
                                _InfoRow(
                                    label: 'IBAN', value: invoice.ibanMasked),
                              _InfoRow(
                                  label: 'Importe',
                                  value:
                                      '${invoice.totalAmount.toStringAsFixed(2)} €'),
                              _InfoRow(
                                  label: 'Versión',
                                  value: '${invoice.version}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<List<TreasuryInvoiceLine>>(
                        stream: service.getInvoiceLines(invoice.id),
                        builder: (context, linesSnap) {
                          final lines = linesSnap.data ?? [];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Líneas',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  const Divider(height: 24),
                                  if (lines.isEmpty)
                                    const Text('No hay líneas asociadas.')
                                  else
                                    ...lines.map((line) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(line.cofradeName),
                                          subtitle: Text(line.concept),
                                          trailing: Text(
                                            '${line.amount.toStringAsFixed(2)} €',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        )),
                                ],
                              ),
                            ),
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
      },
    );
  }

  String _status(String status) {
    switch (status) {
      case 'approved':
        return 'Aprobada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Borrador';
    }
  }

  Future<void> _confirmApprove(TreasuryInvoice invoice) async {
    final service = context.read<TreasuryInvoiceService>();
    final auth = context.read<AuthService>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar factura'),
        content: Text(
          'Se aprobará la factura ${invoice.invoiceNumber}. A partir de ese momento podrá entrar en validación bancaria.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aprobar factura'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await service.approveInvoice(
        invoice.id,
        auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura aprobada correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _confirmCancel(TreasuryInvoice invoice) async {
    final service = context.read<TreasuryInvoiceService>();
    final auth = context.read<AuthService>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar factura'),
        content: Text('Se cancelará la factura ${invoice.invoiceNumber}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar factura'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await service.cancelInvoice(
        invoice.id,
        auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura cancelada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _generatePdf(TreasuryInvoice invoice) async {
    setState(() => _processing = true);
    final pdfService = context.read<TreasuryPdfService>();
    final auth = context.read<AuthService>();
    try {
      await pdfService.generateAndUploadInvoicePdf(
        invoiceId: invoice.id,
        generatedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF generado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
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
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
