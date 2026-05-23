import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/encuesta.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/encuesta_service.dart';

class EncuestasScreen extends StatefulWidget {
  final String? highlightSurveyId;
  const EncuestasScreen({super.key, this.highlightSurveyId});

  @override
  State<EncuestasScreen> createState() => _EncuestasScreenState();
}

class _EncuestasScreenState extends State<EncuestasScreen> {
  final Map<String, GlobalKey> _cardKeys = {};
  bool _scrolled = false;

  void _scrollToHighlighted(List<Encuesta> encuestas) {
    if (_scrolled || widget.highlightSurveyId == null) return;
    _scrolled = true;
    final key = _cardKeys[widget.highlightSurveyId];
    if (key?.currentContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

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
            // Results banner (real-time)
            _EncuestaResultsBanner(cofrade: cofrade),
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

                // Sort: put highlighted survey first if present
                final sorted = [...encuestas];
                if (widget.highlightSurveyId != null) {
                  final idx = sorted.indexWhere(
                      (e) => e.id == widget.highlightSurveyId);
                  if (idx > 0) {
                    final item = sorted.removeAt(idx);
                    sorted.insert(0, item);
                  }
                }

                // Ensure keys exist for scroll
                for (final e in sorted) {
                  _cardKeys.putIfAbsent(e.id, () => GlobalKey());
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToHighlighted(sorted);
                });

                return Column(
                  children: sorted.map((e) => _EncuestaCard(
                    key: _cardKeys[e.id],
                    encuesta: e,
                    cofrade: cofrade,
                    highlight: e.id == widget.highlightSurveyId,
                  )).toList(),
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
  final bool highlight;
  const _EncuestaCard({
    super.key,
    required this.encuesta,
    required this.cofrade,
    this.highlight = false,
  });

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
      elevation: widget.highlight ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: widget.highlight
              ? AppTheme.primaryColor
              : Colors.grey.shade200,
          width: widget.highlight ? 2 : 1,
        ),
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

                // Results (if mostrarResultados is enabled, show always)
                if (enc.mostrarResultados) ...[
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
      case EncuestaTipoRespuesta.votacionImagen:
        return _ImageVoteArea(
          encuesta: enc,
          myResponse: _myResponse,
          saving: _saving,
          onSelect: (option) => _saveSingleChoice(option),
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
// IMAGE VOTE AREA
// =============================================================================

class _ImageVoteArea extends StatelessWidget {
  final Encuesta encuesta;
  final RespuestaEncuesta? myResponse;
  final bool saving;
  final ValueChanged<EncuestaOpcion> onSelect;

  const _ImageVoteArea({
    required this.encuesta,
    required this.myResponse,
    required this.saving,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final selectedId = myResponse?.selectedOptionId;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 3 : width > 500 ? 2 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selecciona una imagen',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: encuesta.opciones.length,
          itemBuilder: (context, i) {
            final option = encuesta.opciones[i];
            final isSelected = selectedId == option.id;
            return InkWell(
              onTap: saving ? null : () => onSelect(option),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.grey.shade200,
                    width: isSelected ? 3 : 1,
                  ),
                  color: isSelected
                      ? AppTheme.primaryColor.withAlpha(15)
                      : Colors.white,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(11)),
                        child: (option.imageUrl ?? '').isNotEmpty
                            ? Image.network(
                                option.imageUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                      child: Icon(Icons.broken_image,
                                          size: 40, color: Colors.grey)),
                                ),
                              )
                            : Container(
                                color: Colors.grey.shade100,
                                child: const Center(
                                    child: Icon(Icons.image,
                                        size: 40, color: Colors.grey)),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: AppTheme.primaryColor, size: 18),
                          if (isSelected) const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              option.text,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
      case EncuestaTipoRespuesta.votacionImagen:
        text = response.selectedOptionText ?? response.selectedOptionId ?? '';
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
    return StreamBuilder<Map<String, int>>(
      stream: service.getResultCountsStream(encuesta.id),
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
            ...items.asMap().entries.map((mapEntry) {
              final i = mapEntry.key;
              final entry = mapEntry.value;
              final count = counts[entry.key] ?? 0;
              final pct = total > 0 ? count / total : 0.0;
              final isWinner = count > 0 &&
                  count == counts.values.reduce((a, b) => a > b ? a : b);
              // Get image URL for votacionImagen type
              final hasImage = encuesta.tipoRespuesta ==
                      EncuestaTipoRespuesta.votacionImagen &&
                  i < encuesta.opciones.length &&
                  (encuesta.opciones[i].imageUrl ?? '').isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    if (hasImage) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          encuesta.opciones[i].imageUrl!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(Icons.broken_image, size: 16)),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    SizedBox(
                      width: hasImage ? 74 : 110,
                      child: Text(entry.value,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isWinner ? FontWeight.w700 : FontWeight.w400,
                          )),
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
                            valueColor: AlwaysStoppedAnimation(
                              isWinner
                                  ? Colors.green.shade600
                                  : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$count (${(pct * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isWinner ? FontWeight.w700 : FontWeight.w400,
                        )),
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
// RESULTS BANNER (real-time, only when showResultsToMembers=true)
// =============================================================================

class _EncuestaResultsBanner extends StatelessWidget {
  final Cofrade cofrade;
  const _EncuestaResultsBanner({required this.cofrade});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EncuestaService>();
    return StreamBuilder<List<Encuesta>>(
      stream: service.getEncuestasConResultadosVisibles(cofrade),
      builder: (context, snapshot) {
        final encuestas = snapshot.data ?? [];
        if (encuestas.isEmpty) return const SizedBox.shrink();
        // Show up to 3, then "Ver todas" link
        return Column(
          children: [
            ...encuestas.take(3).map((enc) {
              return _SingleResultBanner(encuesta: enc, cofrade: cofrade);
            }),
            if (encuestas.length > 3)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/encuestas'),
                  child: const Text('Ver todas las encuestas'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SingleResultBanner extends StatelessWidget {
  final Encuesta encuesta;
  final Cofrade cofrade;
  const _SingleResultBanner(
      {required this.encuesta, required this.cofrade});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EncuestaService>();
    return StreamBuilder<Map<String, int>>(
      stream: service.getResultCountsStream(encuesta.id),
      builder: (context, countsSnap) {
        final counts = countsSnap.data ?? {};
        final total = counts.values.fold<int>(0, (a, b) => a + b);
        if (total == 0) return const SizedBox.shrink();

        // Find the winning option
        String winnerLabel = '';
        int winnerCount = 0;
        if (encuesta.tipoRespuesta == EncuestaTipoRespuesta.reaccion) {
          for (final emoji in encuesta.reactionEmojis) {
            final count = counts[emoji] ?? 0;
            if (count > winnerCount) {
              winnerCount = count;
              winnerLabel = emoji;
            }
          }
        } else {
          for (final opt in encuesta.opciones) {
            final count = counts[opt.id] ?? 0;
            if (count > winnerCount) {
              winnerCount = count;
              winnerLabel = opt.text;
            }
          }
        }
        final winnerPct =
            total > 0 ? (winnerCount / total * 100).toStringAsFixed(0) : '0';

        return FutureBuilder<RespuestaEncuesta?>(
          future: service.getMiRespuesta(encuesta.id, cofrade.id),
          builder: (context, respSnap) {
            final myResp = respSnap.data;
            final hasPending = myResp == null;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: AppTheme.primaryColor.withAlpha(80),
                ),
              ),
              color: AppTheme.primaryColor.withAlpha(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bar_chart_rounded,
                            color: AppTheme.primaryColor, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Resultados en directo',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '$total respuestas',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      encuesta.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$winnerLabel lidera con $winnerPct%',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Top 3 mini bars
                    _buildMiniBars(counts, total),
                    const SizedBox(height: 10),
                    // My response or CTA
                    if (myResp != null) ...[
                      _buildMyResponseChip(myResp),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            context.go(
                              '/encuestas?surveyId=${encuesta.id}',
                            );
                          },
                          icon: Icon(
                            hasPending
                                ? Icons.how_to_vote
                                : Icons.visibility_outlined,
                            size: 16,
                          ),
                          label: Text(hasPending
                              ? 'Responder ahora'
                              : 'Ver encuesta'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMiniBars(Map<String, int> counts, int total) {
    final items = <MapEntry<String, int>>[];
    if (encuesta.tipoRespuesta == EncuestaTipoRespuesta.reaccion) {
      for (final emoji in encuesta.reactionEmojis) {
        items.add(MapEntry(emoji, counts[emoji] ?? 0));
      }
    } else {
      for (final opt in encuesta.opciones) {
        items.add(MapEntry(opt.text, counts[opt.id] ?? 0));
      }
    }
    items.sort((a, b) => b.value.compareTo(a.value));
    final top = items.take(3);

    return Column(
      children: top.map((entry) {
        final pct = total > 0 ? entry.value / total : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  entry.key,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (_, val, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: val,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          const AlwaysStoppedAnimation(AppTheme.primaryColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMyResponseChip(RespuestaEncuesta resp) {
    String text;
    switch (encuesta.tipoRespuesta) {
      case EncuestaTipoRespuesta.unica:
        text = resp.selectedOptionText ?? resp.selectedOptionId ?? '';
        break;
      case EncuestaTipoRespuesta.multiple:
        text = resp.selectedOptionTexts.join(', ');
        break;
      case EncuestaTipoRespuesta.abierta:
        final t = resp.textoAbierto ?? '';
        text = t.length > 40 ? '${t.substring(0, 40)}...' : t;
        break;
      case EncuestaTipoRespuesta.reaccion:
        text = resp.reaccion ?? '';
        break;
      case EncuestaTipoRespuesta.votacionImagen:
        text = resp.selectedOptionText ?? resp.selectedOptionId ?? '';
        break;
    }
    if (text.isEmpty) text = 'Respondida';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 6),
          Text(
            'Tu respuesta: $text',
            style: const TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
