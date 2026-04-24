import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/proveedor.dart';

class TunicasScreen extends StatelessWidget {
  const TunicasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primaryDark, AppTheme.primaryColor]),
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.checkroom, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Túnicas', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 0,
                      color: AppTheme.primaryColor.withAlpha(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppTheme.primaryColor.withAlpha(30)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppTheme.primaryColor),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Aquí encontrarás los proveedores autorizados para la confección de túnicas. '
                                'Contacta directamente con ellos para solicitar presupuesto.',
                                style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(width: 4, height: 24, decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 10),
                        Text('Proveedores Autorizados', style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<Proveedor>>(
                      stream: fs.getProveedores(soloActivos: true),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Card(
                            elevation: 0,
                            color: Colors.red.shade50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 36),
                                  const SizedBox(height: 8),
                                  Text('Error al cargar proveedores: ${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red, fontSize: 13)),
                                ],
                              ),
                            ),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final proveedores = snapshot.data ?? [];
                        if (proveedores.isEmpty) {
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                            child: const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('No hay proveedores registrados aún.')),
                            ),
                          );
                        }
                        return Column(
                          children: proveedores.map((p) => _ProveedorCard(proveedor: p)).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProveedorCard extends StatelessWidget {
  final Proveedor proveedor;
  const _ProveedorCard({required this.proveedor});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                  child: const Icon(Icons.store, color: AppTheme.primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(proveedor.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            if (proveedor.descripcion.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(proveedor.descripcion, style: const TextStyle(color: AppTheme.textSecondary, height: 1.4)),
            ],
            if (proveedor.precios.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.euro, size: 14, color: AppTheme.accentColor),
                    const SizedBox(width: 4),
                    Text(proveedor.precios, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentColor)),
                  ],
                ),
              ),
            ],
            const Divider(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (proveedor.telefono.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.phone, size: 16),
                    label: Text(proveedor.telefono),
                    onPressed: () => launchUrl(Uri.parse('tel:${proveedor.telefono}')),
                  ),
                if (proveedor.email.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.email, size: 16),
                    label: Text(proveedor.email),
                    onPressed: () => launchUrl(Uri.parse('mailto:${proveedor.email}')),
                  ),
                if (proveedor.web.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.language, size: 16),
                    label: const Text('Web'),
                    onPressed: () => launchUrl(Uri.parse(proveedor.web), mode: LaunchMode.externalApplication),
                  ),
              ],
            ),
            if (proveedor.direccion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(child: Text(proveedor.direccion, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
