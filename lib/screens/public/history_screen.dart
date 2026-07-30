import 'package:flutter/material.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/widgets/aztecofrade_support.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  'Nuestra Historia',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Más de 300 años de fe y tradición',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimelineEntry(
                    context,
                    year: '1714',
                    title: 'Fundación',
                    description:
                        'La Cofradía de San Juan Evangelista de Ocaña fue fundada en el año 1714, '
                        'en un momento de gran fervor religioso en la villa toledana. Desde sus orígenes, '
                        'la hermandad ha estado vinculada a la devoción y culto del apóstol amado de Cristo.',
                  ),
                  _buildTimelineEntry(
                    context,
                    year: 'Siglo XVIII',
                    title: 'Consolidación',
                    description:
                        'Durante el siglo XVIII, la Cofradía se consolidó como una de las hermandades '
                        'más importantes de Ocaña, participando activamente en la vida religiosa '
                        'y social de la villa.',
                  ),
                  _buildTimelineEntry(
                    context,
                    year: 'Siglo XIX-XX',
                    title: 'Pervivencia',
                    description:
                        'A pesar de los difíciles momentos históricos, la Cofradía ha mantenido '
                        'viva la llama de la devoción a San Juan Evangelista, adaptándose a los '
                        'tiempos sin perder su esencia.',
                  ),
                  _buildTimelineEntry(
                    context,
                    year: 'Actualidad',
                    title: 'Siglo XXI',
                    description:
                        'Hoy en día, la Cofradía sigue siendo un pilar fundamental de la Semana Santa '
                        'de Ocaña y de la vida parroquial, con una comunidad de cofrades comprometidos '
                        'con la tradición y la fe.',
                    isLast: true,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'San Juan Evangelista',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'San Juan Evangelista, también conocido como "el discípulo amado", fue uno de los '
                    'doce apóstoles de Jesús. Junto con su hermano Santiago, fueron llamados por Jesús '
                    '"Boanerges", que significa "Hijos del Trueno". Es el autor del cuarto Evangelio, '
                    'tres epístolas y el Apocalipsis. Su fiesta se celebra el 27 de diciembre.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: AppTheme.primaryColor.withAlpha(25),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(Icons.format_quote,
                              color: AppTheme.primaryColor, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '"Boanerges" - Hijos del Trueno\nMarcos 3:17',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: AppTheme.primaryColor,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const AztecofradeSupport(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildTimelineEntry(
    BuildContext context, {
    required String year,
    required String title,
    required String description,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              year,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
                fontSize: 14,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentColor, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppTheme.primaryLight),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(description,
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
