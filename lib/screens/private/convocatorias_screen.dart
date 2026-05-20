import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/convocatoria.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class ConvocatoriasScreen extends StatelessWidget {
  const ConvocatoriasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Encuestas',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Responde con un clic a las encuestas activas de la Cofradía.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Convocatoria>>(
              stream: firestoreService.getConvocatoriasActivas(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final encuestas = snapshot.data ?? [];
                if (encuestas.isEmpty) {
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.poll_outlined,
                                size: 56, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No hay encuestas activas en este momento.',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: encuestas
                      .map((survey) => _SurveyCard(survey: survey))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SurveyCard extends StatefulWidget {
  final Convocatoria survey;

  const _SurveyCard({required this.survey});

  @override
  State<_SurveyCard> createState() => _SurveyCardState();
}

class _SurveyCardState extends State<_SurveyCard> {
  RespuestaConvocatoria? _myResponse;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMyResponse();
  }

  @override
  void didUpdateWidget(covariant _SurveyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.survey.id != widget.survey.id) {
      _loadMyResponse();
    }
  }

  Future<void> _loadMyResponse() async {
    final cofrade = context.read<AuthService>().cofrade;
    if (cofrade == null) return;
    setState(() => _loading = true);
    final response = await context
        .read<FirestoreService>()
        .getMiRespuesta(widget.survey.id, cofrade.id);
    if (!mounted) return;
    setState(() {
      _myResponse = response;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final survey = widget.survey;
    final fmt = DateFormat('dd/MM/yyyy');
    final selectedId = _myResponse?.selectedOptionId;
    final selectedText =
        _myResponse?.selectedOptionText ?? _myResponse?.respuesta;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((survey.coverImageUrl ?? '').isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(
                survey.coverImageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(12),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Center(
                child: Icon(Icons.poll_outlined,
                    color: AppTheme.primaryColor, size: 46),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: _myResponse == null ? 'Pendiente' : 'Respondida',
                      color: _myResponse == null
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                    ),
                    _StatusChip(
                      label: 'Límite ${fmt.format(survey.fechaLimite)}',
                      color: AppTheme.primaryColor,
                    ),
                    if (survey.adjuntos.isNotEmpty)
                      _StatusChip(
                        label: '${survey.adjuntos.length} adjunto(s)',
                        color: AppTheme.textSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(survey.titulo,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(survey.descripcion,
                    style: const TextStyle(color: AppTheme.textSecondary)),
                if (survey.adjuntos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final adj in survey.adjuntos)
                        OutlinedButton.icon(
                          onPressed: () {
                            final url = adj['url'];
                            if (url != null && url.isNotEmpty) {
                              launchUrl(Uri.parse(url),
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Descargar PDF'),
                        ),
                    ],
                  ),
                ],
                const Divider(height: 28),
                if (_loading)
                  const LinearProgressIndicator()
                else ...[
                  const Text('Elige una opción',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final option in survey.surveyOptions)
                        ChoiceChip(
                          label: Text(option.text),
                          selected: selectedId == option.id ||
                              ((selectedId == null || selectedId.isEmpty) &&
                                  selectedText == option.text),
                          onSelected:
                              _saving ? null : (_) => _saveResponse(option),
                          selectedColor: AppTheme.primaryColor.withAlpha(38),
                          labelStyle: TextStyle(
                            color: selectedId == option.id ||
                                    ((selectedId == null ||
                                            selectedId.isEmpty) &&
                                        selectedText == option.text)
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  if (_myResponse != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _saving
                              ? 'Guardando respuesta...'
                              : 'Respuesta registrada correctamente.',
                          style: const TextStyle(
                              color: Colors.green, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ],
                if (survey.mostrarResultados) ...[
                  const Divider(height: 28),
                  const Text('Resultados actuales de la encuesta',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  FutureBuilder<Map<String, int>>(
                    future: context
                        .read<FirestoreService>()
                        .getSurveyResults(survey.id),
                    builder: (context, resultSnap) {
                      final counts = resultSnap.data ?? const <String, int>{};
                      final total = counts.values.fold<int>(0, (a, b) => a + b);
                      return Column(
                        children: [
                          for (final option in survey.surveyOptions)
                            _ResultBar(
                              label: option.text,
                              count:
                                  counts[option.id] ?? counts[option.text] ?? 0,
                              total: total,
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text('Total respuestas: $total',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary)),
                          ),
                        ],
                      );
                    },
                  ),
                ] else if (_myResponse != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Los resultados de esta encuesta no están visibles para los cofrades.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveResponse(SurveyOption option) async {
    final current = _myResponse;
    if (current?.selectedOptionId == option.id ||
        (current?.selectedOptionId.isEmpty == true &&
            current?.selectedOptionText == option.text)) {
      return;
    }
    final cofrade = context.read<AuthService>().cofrade;
    if (cofrade == null) return;
    setState(() => _saving = true);
    try {
      await context.read<FirestoreService>().responderConvocatoria(
            convocatoriaId: widget.survey.id,
            cofradeId: cofrade.id,
            cofradeNombre: cofrade.nombreCompleto,
            selectedOptionId: option.id,
            respuesta: option.text,
          );
      if (!mounted) return;
      setState(() {
        _myResponse = RespuestaConvocatoria(
          id: cofrade.id,
          cofradeId: cofrade.id,
          cofradeNombre: cofrade.nombreCompleto,
          respuesta: option.text,
          selectedOptionId: option.id,
          selectedOptionText: option.text,
          fechaRespuesta: current?.fechaRespuesta ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(current == null
              ? 'Respuesta registrada correctamente.'
              : 'Respuesta actualizada.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar la respuesta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ResultBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;

  const _ResultBar({
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text('$count · ${(pct * 100).toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}
