import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/encuesta.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/encuesta_service.dart';

class EncuestasScreen extends StatelessWidget {
  const EncuestasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final encuestaService = context.read<EncuestaService>();
    final cofrade = authService.cofrade;

    if (cofrade == null) {
      return const Center(child: Text('Inicia sesión para ver encuestas.'));
    }

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
              'Participa en las encuestas activas de la Cofradía.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<Encuesta>>(
              stream: encuestaService.getEncuestasParaCofrade(cofrade),
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
                            Text(
                                'No hay encuestas activas para ti en este momento.',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: encuestas
                      .map((e) => _EncuestaCard(encuesta: e, cofrade: cofrade))
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

// =============================================================================
// ENCUESTA CARD
// =============================================================================

class _EncuestaCard extends StatefulWidget {
  final Encuesta encuesta;
  final Cofrade cofrade;
  const _EncuestaCard({required this.encuesta, required this.cofrade});

  @override
  State<_EncuestaCard> createState() => _EncuestaCardState();
}

class _EncuestaCardState extends State<_EncuestaCard> {
  RespuestaEncuesta? _myResponse;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMyResponse();
  }

  @override
  void didUpdateWidget(covariant _EncuestaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.encuesta.id != widget.encuesta.id) _loadMyResponse();
  }

  Future<void> _loadMyResponse() async {
    setState(() => _loading = true);
    final resp = await context
        .read<EncuestaService>()
        .getMiRespuesta(widget.encuesta.id, widget.cofrade.id);
    if (!mounted) return;
    setState(() {
      _myResponse = resp;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enc = widget.encuesta;
    final fmt = DateFormat('dd/MM/yyyy');

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
          // Cover image
          if ((enc.coverImageUrl ?? '').isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(enc.coverImageUrl!,
                  width: double.infinity, height: 200, fit: BoxFit.cover),
            )
          else
            Container(
              height: 100,
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
                // Status chips
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
                    if (enc.fechaLimite != null)
                      _StatusChip(
                        label: 'Límite ${fmt.format(enc.fechaLimite!)}',
                        color: AppTheme.primaryColor,
                      ),
                    _StatusChip(
                      label: enc.tipoRespuestaLabel,
                      color: Colors.blue.shade700,
                    ),
                    if (enc.esAnonima)
                      _StatusChip(
                        label: 'Anónima',
                        color: Colors.purple.shade700,
                      ),
                    if (enc.adjuntos.isNotEmpty)
                      _StatusChip(
                        label: '${enc.adjuntos.length} adjunto(s)',
                        color: AppTheme.textSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(enc.titulo,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(enc.descripcion,
                    style: const TextStyle(color: AppTheme.textSecondary)),

                // Attachments
                if (enc.adjuntos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: enc.adjuntos.map((adj) {
                      return OutlinedButton.icon(
                        onPressed: () {
                          final url = adj['url'];
                          if (url != null && url.isNotEmpty) {
                            launchUrl(Uri.parse(url),
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(adj['nombre'] ?? 'Descargar PDF'),
                      );
                    }).toList(),
                  ),
                ],

                const Divider(height: 28),

                if (_loading)
                  const LinearProgressIndicator()
                else ...[
                  // Response area — varies by type
                  _buildResponseArea(enc),

                  // Current response indicator
                  if (_myResponse != null) ...[
                    const SizedBox(height: 12),
                    _CurrentResponseIndicator(
                      encuesta: enc,
                      response: _myResponse!,
                    ),
                  ],
                ],

                // Results (if visible)
                if (enc.mostrarResultados && _myResponse != null) ...[
                  const SizedBox(height: 16),
                  _InlineResults(encuesta: enc),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseArea(Encuesta enc) {
    switch (enc.tipoRespuesta) {
      case EncuestaTipoRespuesta.unica:
        return _SingleChoiceArea(
          encuesta: enc,
          myResponse: _myResponse,
          saving: _saving,
          onSelect: (option) => _saveSingleChoice(option),
        );
      case EncuestaTipoRespuesta.multiple:
        return _MultiChoiceArea(
          encuesta: enc,
          myResponse: _myResponse,
          saving: _saving,
          onSubmit: (ids, texts) => _saveMultiChoice(ids, texts),
        );
      case EncuestaTipoRespuesta.abierta:
        return _OpenTextArea(
          myResponse: _myResponse,
          saving: _saving,
          onSubmit: (text) => _saveOpenText(text),
        );
      case EncuestaTipoRespuesta.reaccion:
        return _ReactionArea(
          encuesta: enc,
          myResponse: _myResponse,
          saving: _saving,
          onSelect: (emoji) => _saveReaction(emoji),
        );
    }
  }

  Future<void> _saveSingleChoice(EncuestaOpcion option) async {
    setState(() => _saving = true);
    final resp = RespuestaEncuesta(
      id: widget.cofrade.id,
      cofradeId: widget.cofrade.id,
      cofradeNombre: widget.cofrade.nombreCompleto,
      selectedOptionId: option.id,
      selectedOptionText: option.text,
      fechaRespuesta: DateTime.now(),
    );
    await context
        .read<EncuestaService>()
        .responder(widget.encuesta.id, widget.cofrade, resp);
    await _loadMyResponse();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveMultiChoice(
      List<String> ids, List<String> texts) async {
    setState(() => _saving = true);
    final resp = RespuestaEncuesta(
      id: widget.cofrade.id,
      cofradeId: widget.cofrade.id,
      cofradeNombre: widget.cofrade.nombreCompleto,
      selectedOptionIds: ids,
      selectedOptionTexts: texts,
      fechaRespuesta: DateTime.now(),
    );
    await context
        .read<EncuestaService>()
        .responder(widget.encuesta.id, widget.cofrade, resp);
    await _loadMyResponse();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveOpenText(String text) async {
    setState(() => _saving = true);
    final resp = RespuestaEncuesta(
      id: widget.cofrade.id,
      cofradeId: widget.cofrade.id,
      cofradeNombre: widget.cofrade.nombreCompleto,
      textoAbierto: text,
      fechaRespuesta: DateTime.now(),
    );
    await context
        .read<EncuestaService>()
        .responder(widget.encuesta.id, widget.cofrade, resp);
    await _loadMyResponse();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveReaction(String emoji) async {
    setState(() => _saving = true);
    final resp = RespuestaEncuesta(
      id: widget.cofrade.id,
      cofradeId: widget.cofrade.id,
      cofradeNombre: widget.cofrade.nombreCompleto,
      reaccion: emoji,
      fechaRespuesta: DateTime.now(),
    );
    await context
        .read<EncuestaService>()
        .responder(widget.encuesta.id, widget.cofrade, resp);
    await _loadMyResponse();
    if (mounted) setState(() => _saving = false);
  }
}

// =============================================================================
// SINGLE CHOICE
// =============================================================================

class _SingleChoiceArea extends StatelessWidget {
  final Encuesta encuesta;
  final RespuestaEncuesta? myResponse;
  final bool saving;
  final ValueChanged<EncuestaOpcion> onSelect;

  const _SingleChoiceArea({
    required this.encuesta,
    required this.myResponse,
    required this.saving,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final selectedId = myResponse?.selectedOptionId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Elige una opción',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: encuesta.opciones.map((option) {
            final isSelected = selectedId == option.id;
            return ChoiceChip(
              label: Text(option.text),
              selected: isSelected,
              onSelected: saving ? null : (_) => onSelect(option),
              selectedColor: AppTheme.primaryColor.withAlpha(38),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// =============================================================================
// MULTI CHOICE
// =============================================================================

class _MultiChoiceArea extends StatefulWidget {
  final Encuesta encuesta;
  final RespuestaEncuesta? myResponse;
  final bool saving;
  final void Function(List<String> ids, List<String> texts) onSubmit;

  const _MultiChoiceArea({
    required this.encuesta,
    required this.myResponse,
    required this.saving,
    required this.onSubmit,
  });

  @override
  State<_MultiChoiceArea> createState() => _MultiChoiceAreaState();
}

class _MultiChoiceAreaState extends State<_MultiChoiceArea> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.myResponse?.selectedOptionIds ?? []);
  }

  @override
  void didUpdateWidget(covariant _MultiChoiceArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.myResponse != widget.myResponse) {
      _selected = Set.from(widget.myResponse?.selectedOptionIds ?? []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selecciona una o varias opciones',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: widget.encuesta.opciones.map((option) {
            final isSelected = _selected.contains(option.id);
            return FilterChip(
              label: Text(option.text),
              selected: isSelected,
              selectedColor: AppTheme.primaryColor.withAlpha(38),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              onSelected: widget.saving
                  ? null
                  : (sel) {
                      setState(() {
                        if (sel) {
                          _selected.add(option.id);
                        } else {
                          _selected.remove(option.id);
                        }
                      });
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: widget.saving || _selected.isEmpty
              ? null
              : () {
                  final ids = _selected.toList();
                  final texts = ids
                      .map((id) => widget.encuesta.opciones
                          .firstWhere((o) => o.id == id,
                              orElse: () => const EncuestaOpcion(
                                  id: '', text: '', order: 0))
                          .text)
                      .toList();
                  widget.onSubmit(ids, texts);
                },
          child: widget.saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enviar selección'),
        ),
      ],
    );
  }
}

// =============================================================================
// OPEN TEXT
// =============================================================================

class _OpenTextArea extends StatefulWidget {
  final RespuestaEncuesta? myResponse;
  final bool saving;
  final ValueChanged<String> onSubmit;

  const _OpenTextArea({
    required this.myResponse,
    required this.saving,
    required this.onSubmit,
  });

  @override
  State<_OpenTextArea> createState() => _OpenTextAreaState();
}

class _OpenTextAreaState extends State<_OpenTextArea> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.myResponse?.textoAbierto ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Escribe tu respuesta',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextFormField(
          controller: _controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Tu respuesta...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: widget.saving || _controller.text.trim().isEmpty
              ? null
              : () => widget.onSubmit(_controller.text.trim()),
          child: widget.saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enviar respuesta'),
        ),
      ],
    );
  }
}

// =============================================================================
// REACTION
// =============================================================================

class _ReactionArea extends StatelessWidget {
  final Encuesta encuesta;
  final RespuestaEncuesta? myResponse;
  final bool saving;
  final ValueChanged<String> onSelect;

  const _ReactionArea({
    required this.encuesta,
    required this.myResponse,
    required this.saving,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final selected = myResponse?.reaccion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reacciona',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: encuesta.reactionEmojis.map((emoji) {
            final isSelected = selected == emoji;
            return InkWell(
              onTap: saving ? null : () => onSelect(emoji),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withAlpha(25)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isSelected ? AppTheme.primaryColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(emoji,
                    style: TextStyle(fontSize: isSelected ? 36 : 28)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// =============================================================================
// CURRENT RESPONSE INDICATOR
// =============================================================================

class _CurrentResponseIndicator extends StatelessWidget {
  final Encuesta encuesta;
  final RespuestaEncuesta response;
  const _CurrentResponseIndicator(
      {required this.encuesta, required this.response});

  @override
  Widget build(BuildContext context) {
    String text;
    switch (encuesta.tipoRespuesta) {
      case EncuestaTipoRespuesta.unica:
        text = response.selectedOptionText ?? response.selectedOptionId ?? '';
        break;
      case EncuestaTipoRespuesta.multiple:
        text = response.selectedOptionTexts.join(', ');
        break;
      case EncuestaTipoRespuesta.abierta:
        final t = response.textoAbierto ?? '';
        text = t.length > 80 ? '${t.substring(0, 80)}...' : t;
        break;
      case EncuestaTipoRespuesta.reaccion:
        text = response.reaccion ?? '';
        break;
    }
    if (text.isEmpty) text = 'Respuesta registrada';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Tu respuesta actual: ',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: text,
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// INLINE RESULTS (for cofrades when mostrarResultados is true)
// =============================================================================

class _InlineResults extends StatelessWidget {
  final Encuesta encuesta;
  const _InlineResults({required this.encuesta});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EncuestaService>();
    return FutureBuilder<Map<String, int>>(
      future: service.getResultCounts(encuesta.id),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final counts = snap.data!;
        final total = counts.values.fold<int>(0, (a, b) => a + b);
        if (total == 0) return const SizedBox.shrink();

        List<MapEntry<String, String>> items;
        if (encuesta.tipoRespuesta == EncuestaTipoRespuesta.reaccion) {
          items =
              encuesta.reactionEmojis.map((e) => MapEntry(e, e)).toList();
        } else {
          items = encuesta.opciones
              .map((o) => MapEntry(o.id, o.text))
              .toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resultados actuales',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...items.map((entry) {
              final count = counts[entry.key] ?? 0;
              final pct = total > 0 ? count / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(entry.value,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: pct),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (_, val, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: val,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation(
                                AppTheme.primaryColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$count (${(pct * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// =============================================================================
// STATUS CHIP
// =============================================================================

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
