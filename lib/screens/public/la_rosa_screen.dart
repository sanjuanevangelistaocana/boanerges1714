import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class LaRosaScreen extends StatelessWidget {
  const LaRosaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryDark,
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withAlpha(200),
                ],
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_florist, size: 56, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'La Rosa',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pétalo a Pétalo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: StreamBuilder<Map<String, dynamic>?>(
                  stream: firestoreService.getPaginaEstatica('la-rosa'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final data = snapshot.data;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(28),
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
                                      child: const Icon(Icons.local_florist, color: AppTheme.primaryColor, size: 28),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        data?['titulo'] ?? 'La Rosa · Pétalo a Pétalo',
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  data?['contenido'] ??
                                      'La iniciativa "Pétalo a Pétalo" es un proyecto solidario de la '
                                          'Cofradía de San Juan Evangelista de Ocaña. A través de esta iniciativa, '
                                          'cada cofrade puede contribuir con su pequeño gesto — como un pétalo — '
                                          'para formar juntos una gran rosa de solidaridad y compromiso con '
                                          'nuestra comunidad.\n\n'
                                          'Cada año, durante la Semana Santa, la cofradía organiza diversas '
                                          'actividades benéficas y de recogida de alimentos, ropa y otros recursos '
                                          'para las familias más necesitadas de Ocaña y alrededores.\n\n'
                                          'Si deseas participar en esta bonita iniciativa o hacer una donación, '
                                          'no dudes en ponerte en contacto con nosotros.',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        height: 1.7,
                                        color: AppTheme.textPrimary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (data?['secciones'] != null)
                          ...((data!['secciones'] as List<dynamic>).map((seccion) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Card(
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
                                      Text(
                                        seccion['titulo'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        seccion['contenido'] ?? '',
                                        style: const TextStyle(height: 1.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          })),
                        Card(
                          elevation: 0,
                          color: AppTheme.accentColor.withAlpha(15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppTheme.accentColor.withAlpha(40)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              children: [
                                const Icon(Icons.volunteer_activism, size: 32, color: AppTheme.accentColor),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '¿Quieres colaborar?',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Contacta con nosotros para participar en La Rosa.',
                                        style: TextStyle(color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
