import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/treasury/treasury_invoice_service.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';
import 'package:boanerges1714/models/cuota.dart';
import 'package:boanerges1714/models/treasury.dart';
import 'package:url_launcher/url_launcher.dart';

class CuotasScreen extends StatelessWidget {
  const CuotasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final cofrade = authService.cofrade;

    if (cofrade == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mis Cuotas',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Historial de cuotas y pagos',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<TreasuryInvoice>>(
              stream: context
                  .read<TreasuryInvoiceService>()
                  .getInvoicesForAuthUid(authService.userId ?? ''),
              builder: (context, snapshot) {
                final invoices = snapshot.data ?? [];
                return StreamBuilder<List<Cuota>>(
                  stream: firestoreService.getCuotasCofrade(cofrade.id),
                  builder: (context, cuotaSnapshot) {
                    return StreamBuilder<List<TreasuryAccountingMovement>>(
                      stream: context
                          .read<TreasuryRepository>()
                          .getAccountingMovementsForPerson(
                              personId: cofrade.id),
                      builder: (context, movementSnapshot) {
                        if (cuotaSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            snapshot.connectionState ==
                                ConnectionState.waiting &&
                            movementSnapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final cuotas = cuotaSnapshot.data ?? [];
                        final movements = movementSnapshot.data ?? [];
                        if (invoices.isEmpty &&
                            cuotas.isEmpty &&
                            movements.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(48),
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long,
                                      size: 64, color: AppTheme.textSecondary),
                                  SizedBox(height: 16),
                                  Text('No hay cuotas registradas.',
                                      style: TextStyle(
                                          color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (invoices.isNotEmpty) ...[
                              Text('Facturas y cuotas',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              ...invoices.map((invoice) => Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: AppTheme.primaryColor,
                                        child: Icon(Icons.receipt_long,
                                            color: Colors.white),
                                      ),
                                      title: Text(invoice.invoiceNumber,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                          '${invoice.year} · ${_status(invoice.status)}'),
                                      trailing: Wrap(
                                        spacing: 10,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            '${invoice.totalAmount.toStringAsFixed(2)} €',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: invoice.pdfUrl.isEmpty
                                                ? null
                                                : () => launchUrl(
                                                      Uri.parse(invoice.pdfUrl),
                                                      mode: LaunchMode
                                                          .externalApplication,
                                                    ),
                                            icon: const Icon(
                                                Icons.picture_as_pdf),
                                            label: const Text('Ver factura'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),
                              const SizedBox(height: 24),
                            ],
                            if (movements.isNotEmpty) ...[
                              Text('Movimientos económicos asociados',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              ...movements.map((movement) => Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            movement.type == 'income'
                                                ? AppTheme.accentColor
                                                : Colors.red.shade700,
                                        child: Icon(
                                          movement.type == 'income'
                                              ? Icons.south_west
                                              : Icons.north_east,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: Text(
                                        movement.concept.isEmpty
                                            ? _movementLabel(movement)
                                            : movement.concept,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        '${_fmt(movement.date)} · ${_status(movement.status)}'
                                        '${movement.paymentMethod.isEmpty ? '' : ' · ${_method(movement.paymentMethod)}'}',
                                      ),
                                      trailing: Text(
                                        '${movement.amount.toStringAsFixed(2)} €',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  )),
                              const SizedBox(height: 24),
                            ],
                            ...cuotas.map((cuota) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: cuota.isPagada
                                        ? Colors.green
                                        : Colors.orange,
                                    child: Icon(
                                      cuota.isPagada
                                          ? Icons.check
                                          : Icons.pending,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    cuota.concepto ?? 'Cuota ${cuota.anio}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    cuota.isPagada && cuota.fechaPago != null
                                        ? 'Pagada el ${cuota.fechaPago!.day}/${cuota.fechaPago!.month}/${cuota.fechaPago!.year}'
                                        : 'Pendiente de pago',
                                  ),
                                  trailing: Text(
                                    '${cuota.importe.toStringAsFixed(2)} €',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            }),
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
    );
  }

  String _status(String status) {
    switch (status) {
      case 'approved':
        return 'Aprobada';
      case 'paid':
        return 'Pagada';
      case 'cancelled':
        return 'Cancelada';
      case 'pending':
        return 'Pendiente';
      case 'confirmed':
        return 'Confirmado';
      case 'returned':
        return 'Devuelto';
      default:
        return 'Pendiente';
    }
  }

  String _method(String method) {
    switch (method) {
      case 'bank_remittance':
        return 'Domiciliación';
      case 'cash':
        return 'Efectivo';
      case 'bizum':
        return 'Bizum';
      case 'transfer':
        return 'Transferencia';
      case 'card':
        return 'Tarjeta';
      default:
        return method;
    }
  }

  String _movementLabel(TreasuryAccountingMovement movement) {
    if (movement.origin == 'facturacion') return 'Factura generada';
    if (movement.origin == 'remesa') return 'Movimiento de remesa';
    if (movement.origin == 'manual') return 'Cobro manual';
    return movement.type == 'income' ? 'Ingreso' : 'Gasto';
  }

  String _fmt(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
