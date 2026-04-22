import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/evento.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primaryColor],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Eventos',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Calendario de actos y celebraciones',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppTheme.accentColor),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: StreamBuilder<List<Evento>>(
                stream: firestoreService.getEventos(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final eventos = snapshot.data ?? [];
                  if (eventos.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy,
                              size: 64, color: AppTheme.textSecondary),
                          SizedBox(height: 16),
                          Text('No hay eventos programados por el momento.',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: eventos.length,
                    itemBuilder: (context, index) {
                      final evento = eventos[index];
                      final isPast = evento.fecha.isBefore(DateTime.now());
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 60,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isPast
                                      ? Colors.grey[300]
                                      : AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${evento.fecha.day}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: isPast
                                            ? Colors.grey
                                            : Colors.white,
                                      ),
                                    ),
                                    Text(
                                      _getMonthName(evento.fecha.month),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isPast
                                            ? Colors.grey
                                            : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      evento.titulo,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: isPast
                                                ? AppTheme.textSecondary
                                                : null,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (evento.hora != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time,
                                              size: 14,
                                              color: AppTheme.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(evento.hora!,
                                              style: const TextStyle(
                                                  color:
                                                      AppTheme.textSecondary)),
                                        ],
                                      ),
                                    if (evento.lugar != null) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              size: 14,
                                              color: AppTheme.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(evento.lugar!,
                                              style: const TextStyle(
                                                  color:
                                                      AppTheme.textSecondary)),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(evento.descripcion,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
    ];
    return months[month - 1];
  }
}
