import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/treasury/treasury_invoice_service.dart';

class BillingAndCollectionsScreen extends StatefulWidget {
  const BillingAndCollectionsScreen({super.key});

  @override
  State<BillingAndCollectionsScreen> createState() =>
      _BillingAndCollectionsScreenState();
}

class _BillingAndCollectionsScreenState
    extends State<BillingAndCollectionsScreen> {
  int _year = DateTime.now().year;
  String _statusFilter = 'all';
  bool _generating = false;

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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long,
                      color: Colors.white70, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Facturación y cobros',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (auth.canManageTreasury)
                    ElevatedButton.icon(
                      onPressed: _generating ? null : () => _generate(false),
                      icon: _generating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.playlist_add),
                      label:
                          Text(_generating ? 'Generando...' : 'Generar cuotas'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
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
                  Card(
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
                            width: 150,
                            child: TextFormField(
                              initialValue: '$_year',
                              decoration: const InputDecoration(
                                labelText: 'Año',
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final parsed = int.tryParse(v);
                                if (parsed != null) {
                                  setState(() => _year = parsed);
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              initialValue: _statusFilter,
                              decoration:
                                  const InputDecoration(labelText: 'Estado'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'all', child: Text('Todos')),
                                DropdownMenuItem(
                                    value: 'draft', child: Text('Borrador')),
                                DropdownMenuItem(
                                    value: 'approved',
                                    child: Text('Aprobadas')),
                                DropdownMenuItem(
                                    value: 'cancelled',
                                    child: Text('Canceladas')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _statusFilter = v ?? 'all'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<TreasuryInvoice>>(
                    stream: service.getInvoicesByYear(_year),
                    builder: (context, snap) {
                      final invoices = (snap.data ?? [])
                          .where((i) =>
                              _statusFilter == 'all' ||
                              i.status == _statusFilter)
                          .toList();
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (invoices.isEmpty) {
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text('No hay facturas para este filtro.'),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: invoices
                            .map((i) => _InvoiceTile(invoice: i))
                            .toList(),
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
      final message =
          'Generadas ${result.invoicesCreated} facturas y ${result.linesCreated} líneas.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      if (result.warnings.isNotEmpty) {
        _showWarnings(result.warnings);
      }
    } catch (e) {
      if (!mounted) return;
      final text = '$e';
      if (text.contains('Ya existen facturas')) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Regenerar facturación'),
            content: const Text(
              'Ya existen facturas activas para este año. Si continúas, se cancelarán las anteriores y se creará una nueva versión.',
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
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Borrador';
    }
  }
}
