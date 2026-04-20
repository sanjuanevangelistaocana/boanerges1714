import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/cuota.dart';

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
            StreamBuilder<List<Cuota>>(
              stream: firestoreService.getCuotasCofrade(cofrade.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final cuotas = snapshot.data ?? [];
                if (cuotas.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long,
                              size: 64, color: AppTheme.textSecondary),
                          SizedBox(height: 16),
                          Text('No hay cuotas registradas.',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: cuotas.map((cuota) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              cuota.isPagada ? Colors.green : Colors.orange,
                          child: Icon(
                            cuota.isPagada ? Icons.check : Icons.pending,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          cuota.concepto ?? 'Cuota ${cuota.anio}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          cuota.isPagada && cuota.fechaPago != null
                              ? 'Pagada el ${cuota.fechaPago!.day}/${cuota.fechaPago!.month}/${cuota.fechaPago!.year}'
                              : 'Pendiente de pago',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${cuota.importe.toStringAsFixed(2)} €',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cuota.isPagada
                                    ? Colors.green[50]
                                    : Colors.orange[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                cuota.isPagada ? 'PAGADA' : 'PENDIENTE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: cuota.isPagada
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
