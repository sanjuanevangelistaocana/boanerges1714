import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/cofradia_event.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/events_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';

// ---------------------------------------------------------------------------
//  EventsHomeScreen — unified events view (grid → detail)
// ---------------------------------------------------------------------------

class EventsHomeScreen extends StatelessWidget {
  const EventsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final focusedType = uri.queryParameters['type'];
    final focusedCampaignId = uri.queryParameters['campaignId'];
    final showDetail = focusedType != null;

    return Column(
      children: [
        _EventsHeader(showBack: showDetail),
        Expanded(
          child: showDetail
              ? _EventDetailPanel(
                  type: focusedType!,
                  focusCampaignId: focusedCampaignId,
                )
              : const _UnifiedEventsGrid(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Personal status helpers for cofrade
// ---------------------------------------------------------------------------

String _personalStatusLabel({
  required _EventItem item,
}) {
  if (item.type == 'festividad_27_diciembre') {
    if (item.festInscripcion != null) return 'Ya inscrito';
    final estado = '${item.festEdicion?['estado'] ?? ''}';
    if (estado == 'abierto') return 'Pendiente de inscripción';
    return 'Sin inscripción';
  }
  final campaign = item.campaign;
  final reg = item.registration;
  if (campaign == null) return '';
  if (campaign.type == 'junta_general_ordinaria') {
    if (reg == null) return 'Pendiente de respuesta';
    if (reg.status == 'not_attending') return 'No asistirás';
    if (reg.status == 'attending' ||
        reg.status == 'confirmed' ||
        reg.status == 'confirmada') {
      return 'Asistencia confirmada';
    }
    return _registrationStatusLabel(reg.status);
  }
  if (campaign.type == 'palmas') {
    if (reg == null) {
      return campaign.isOpen ? 'No solicitada' : 'Sin solicitud';
    }
    return 'Solicitud: ${_registrationStatusLabel(reg.status)}';
  }
  if (campaign.type == 'sanjuandereta') {
    if (reg == null) {
      return campaign.isOpen ? 'Pendiente de inscripción' : 'Sin inscripción';
    }
    if (reg.status == 'confirmed' || reg.status == 'confirmada') {
      final companionCount = reg.participants.length - 1;
      return companionCount > 0
          ? 'Inscrito · $companionCount acompañante${companionCount > 1 ? 's' : ''}'
          : 'Inscrito';
    }
    return _registrationStatusLabel(reg.status);
  }
  if (reg != null) return _registrationStatusLabel(reg.status);
  if (campaign.isOpen) return 'Pendiente de inscripción';
  return 'Sin inscripción';
}

Color _personalStatusColor(_EventItem item) {
  if (item.type == 'festividad_27_diciembre') {
    return item.festInscripcion != null
        ? AppTheme.accentColor
        : Colors.orange.shade700;
  }
  final reg = item.registration;
  if (reg == null) return Colors.orange.shade700;
  switch (reg.status) {
    case 'attending':
    case 'confirmed':
    case 'confirmada':
    case 'solicitada':
    case 'requested':
    case 'entregada':
    case 'delivered':
      return AppTheme.accentColor;
    case 'rechazada':
    case 'rejected':
    case 'cancelada':
    case 'cancelled':
      return Colors.red.shade700;
    case 'not_attending':
      return AppTheme.textSecondary;
    default:
      return Colors.orange.shade700;
  }
}

IconData _personalStatusIcon(_EventItem item) {
  if (item.type == 'festividad_27_diciembre') {
    return item.festInscripcion != null
        ? Icons.check_circle
        : Icons.pending_actions;
  }
  final reg = item.registration;
  if (reg == null) return Icons.pending_actions;
  switch (reg.status) {
    case 'attending':
    case 'confirmed':
    case 'confirmada':
    case 'entregada':
    case 'delivered':
      return Icons.check_circle;
    case 'solicitada':
    case 'requested':
    case 'pending':
    case 'pendiente':
      return Icons.hourglass_top;
    case 'rechazada':
    case 'rejected':
      return Icons.cancel;
    case 'not_attending':
      return Icons.block;
    case 'cancelada':
    case 'cancelled':
      return Icons.cancel_outlined;
    default:
      return Icons.info_outline;
  }
}

bool _isDeadlineUrgent(_EventItem item) {
  if (item.type == 'festividad_27_diciembre') {
    final raw = item.festEdicion?['fecha_limite'];
    final limit =
        raw is Timestamp ? raw.toDate() : (raw is DateTime ? raw : null);
    if (limit != null) {
      return limit.difference(DateTime.now()).inDays <= 3;
    }
    return false;
  }
  final endDate = item.campaign?.endDate;
  if (endDate != null && (item.campaign?.isOpen ?? false)) {
    return endDate.difference(DateTime.now()).inDays <= 3;
  }
  return false;
}

// ---------------------------------------------------------------------------
//  Header
// ---------------------------------------------------------------------------

class _EventsHeader extends StatelessWidget {
  final bool showBack;
  const _EventsHeader({this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primaryColor],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Volver a eventos',
                  onPressed: () => context.go('/eventos'),
                ),
              const Icon(Icons.event_available, color: Colors.white, size: 30),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Eventos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Unified events grid (replaces old TabBar)
// ---------------------------------------------------------------------------

enum _EventCategory { actionRequired, activeInscribed, upcoming, historical }

class _EventItem {
  final String type;
  final String title;
  final String? subtitle;
  final _EventCategory category;
  final EventCampaign? campaign;
  final EventRegistration? registration;
  final Map<String, dynamic>? festEdicion;
  final Map<String, dynamic>? festInscripcion;

  const _EventItem({
    required this.type,
    required this.title,
    this.subtitle,
    required this.category,
    this.campaign,
    this.registration,
    this.festEdicion,
    this.festInscripcion,
  });

  String get routePath {
    if (type == 'festividad_27_diciembre') return '/festividad';
    if (campaign != null) return EventsService.routeForCampaign(campaign!);
    return '/eventos';
  }
}

class _UnifiedEventsGrid extends StatefulWidget {
  const _UnifiedEventsGrid();

  @override
  State<_UnifiedEventsGrid> createState() => _UnifiedEventsGridState();
}

class _UnifiedEventsGridState extends State<_UnifiedEventsGrid> {
  Map<String, dynamic>? _festEdicion;
  Map<String, dynamic>? _festInscripcion;
  bool _festLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFestividad();
  }

  Future<void> _loadFestividad() async {
    final firestoreService = context.read<FirestoreService>();
    final auth = context.read<AuthService>();
    final cofrade = auth.cofrade;
    try {
      final edicion = await firestoreService.getFestividadEdicionActiva();
      if (edicion != null && cofrade != null) {
        final inscripcion =
            await firestoreService.getInscripcionFestividadParaCofrade(
                edicion['id'] as String, cofrade.id);
        if (mounted) {
          setState(() {
            _festEdicion = edicion;
            _festInscripcion = inscripcion;
            _festLoaded = true;
          });
        }
      } else {
        if (mounted) setState(() => _festLoaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _festLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final cofrade = auth.cofrade;
    final eventsService = context.read<EventsService>();

    if (cofrade == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<EventCampaign>>(
      stream: eventsService.watchCampaigns(),
      builder: (context, campaignSnap) {
        return StreamBuilder<List<EventRegistration>>(
          stream: eventsService.watchMyRegistrations(cofrade.id),
          builder: (context, regSnap) {
            if (!campaignSnap.hasData || !_festLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            final allCampaigns = campaignSnap.data!
                .where((campaign) =>
                    !campaign.deleted && campaign.status != 'archived')
                .toList();
            final myRegistrations = regSnap.data ?? [];
            final items = <_EventItem>[];

            // --- Festividad card ---
            if (_festEdicion != null) {
              final estado = '${_festEdicion!['estado'] ?? 'borrador'}';
              final isOpen = estado == 'abierto';
              final hasInscripcion = _festInscripcion != null;
              _EventCategory category;
              if (isOpen && !hasInscripcion) {
                category = _EventCategory.actionRequired;
              } else if (hasInscripcion) {
                category = _EventCategory.activeInscribed;
              } else if (estado == 'finalizada' || estado == 'cerrado') {
                category = _EventCategory.historical;
              } else {
                category = _EventCategory.upcoming;
              }
              items.add(_EventItem(
                type: 'festividad_27_diciembre',
                title:
                    '${_festEdicion!['nombre'] ?? 'Festividad San Juan Evangelista'}',
                subtitle: _festEdicion!['descripcion'] as String?,
                category: category,
                festEdicion: _festEdicion,
                festInscripcion: _festInscripcion,
              ));
            }

            // --- Configurable event campaigns ---
            for (final campaign in allCampaigns) {
              if (!campaign.isVisibleToCofrade &&
                  campaign.status != 'finished') {
                continue;
              }
              final campaignRegs = myRegistrations
                  .where((reg) => reg.campaignId == campaign.id)
                  .toList();
              final hasRegistration = campaignRegs.isNotEmpty;
              _EventCategory category;
              if (campaign.isHistorical) {
                category = _EventCategory.historical;
              } else if (hasRegistration) {
                category = _EventCategory.activeInscribed;
              } else if (campaign.isOpen) {
                category = _EventCategory.actionRequired;
              } else if (campaign.isUpcoming || campaign.status == 'published') {
                category = _EventCategory.upcoming;
              } else {
                category = _EventCategory.upcoming;
              }
              items.add(_EventItem(
                type: campaign.type,
                title: campaign.name,
                subtitle: campaign.description.isEmpty
                    ? null
                    : campaign.description,
                category: category,
                campaign: campaign,
                registration: hasRegistration ? campaignRegs.first : null,
              ));
            }

            final actionRequired = items
                .where(
                    (item) => item.category == _EventCategory.actionRequired)
                .toList();
            final activeInscribed = items
                .where(
                    (item) => item.category == _EventCategory.activeInscribed)
                .toList();
            final upcoming = items
                .where((item) => item.category == _EventCategory.upcoming)
                .toList();
            final historical = items
                .where((item) => item.category == _EventCategory.historical)
                .toList();

            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay eventos disponibles en este momento.',
                      style: TextStyle(
                          fontSize: 16, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (actionRequired.isNotEmpty)
                        _buildSection(
                          context,
                          'Requiere tu acción',
                          actionRequired,
                          Colors.orange.shade700,
                          Icons.notifications_active,
                        ),
                      if (activeInscribed.isNotEmpty)
                        _buildSection(
                          context,
                          'Tus inscripciones activas',
                          activeInscribed,
                          AppTheme.accentColor,
                          Icons.check_circle_outline,
                        ),
                      if (upcoming.isNotEmpty)
                        _buildSection(
                          context,
                          'Próximos eventos',
                          upcoming,
                          AppTheme.primaryColor,
                          Icons.upcoming,
                        ),
                      if (historical.isNotEmpty)
                        _buildSection(
                          context,
                          'Eventos pasados',
                          historical,
                          AppTheme.textSecondary,
                          Icons.history,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<_EventItem> items,
    Color color,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => _UnifiedEventCard(item: item)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Unified event card
// ---------------------------------------------------------------------------

class _UnifiedEventCard extends StatelessWidget {
  final _EventItem item;
  const _UnifiedEventCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final campaign = item.campaign;
    final registration = item.registration;

    final imageUrl =
        item.type == 'festividad_27_diciembre'
            ? null
            : (campaign?.coverImageUrl ?? '');
    final icon = _iconForType(item.type);
    final typeLabel = _typeLabelFor(item.type);
    final ctaLabel = _ctaLabelForItem(item);
    final dateText = _dateTextForItem(item);
    final deadlineText = _deadlineTextForItem(item);
    final personalLabel = _personalStatusLabel(item: item);
    final personalColor = _personalStatusColor(item);
    final personalIcon = _personalStatusIcon(item);
    final isActionRequired =
        item.category == _EventCategory.actionRequired;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      elevation: isActionRequired ? 2 : 0,
      shadowColor: isActionRequired
          ? Colors.orange.withAlpha(60)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isActionRequired
              ? Colors.orange.withAlpha(100)
              : Colors.grey.shade200,
          width: isActionRequired ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(item.routePath),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              Stack(
                children: [
                  Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 170,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _SmallBadge(
                      label: _statusLabelForItem(item),
                      color: _statusColorForItem(item),
                      filled: true,
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: AppTheme.primaryColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        typeLabel,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      if (!hasImage)
                        _SmallBadge(
                          label: _statusLabelForItem(item),
                          color: _statusColorForItem(item),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (item.subtitle != null &&
                      item.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle!.length > 120
                          ? '${item.subtitle!.substring(0, 120)}...'
                          : item.subtitle!,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: personalColor.withAlpha(12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: personalColor.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        Icon(personalIcon,
                            size: 18, color: personalColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            personalLabel,
                            style: TextStyle(
                              color: personalColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (registration != null &&
                            campaign?.type != 'junta_general_ordinaria' &&
                            campaign?.requiresPayment == true)
                          _SmallBadge(
                            label:
                                'Pago: ${_paymentStatusLabel(registration.paymentStatus)}',
                            color: _paymentStatusColor(registration),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (dateText != null)
                        _SmallIconText(
                            icon: Icons.calendar_today, text: dateText),
                      if (deadlineText != null)
                        _SmallIconText(
                            icon: Icons.timer_outlined,
                            text: deadlineText,
                            urgent: _isDeadlineUrgent(item)),
                      if (campaign != null &&
                          campaign.location.isNotEmpty)
                        _SmallIconText(
                            icon: Icons.place_outlined,
                            text: campaign.location),
                      if (registration != null &&
                          registration.participants.length > 1)
                        _SmallIconText(
                            icon: Icons.group,
                            text:
                                '${registration.participants.length - 1} acompa\u00f1ante${registration.participants.length > 2 ? 's' : ''}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go(item.routePath),
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: isActionRequired
                            ? AppTheme.primaryColor
                            : null,
                      ),
                      child: Text(ctaLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Small UI helpers for cards
// ---------------------------------------------------------------------------

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _SmallBadge({
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: filled ? Colors.white : color,
            fontWeight: FontWeight.w700,
            fontSize: 11),
      ),
    );
  }
}

class _SmallIconText extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool urgent;
  const _SmallIconText({
    required this.icon,
    required this.text,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        urgent ? Colors.red.shade700 : AppTheme.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: urgent ? FontWeight.w700 : FontWeight.normal)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Helper functions for card display
// ---------------------------------------------------------------------------

IconData _iconForType(String type) {
  switch (type) {
    case 'festividad_27_diciembre':
      return Icons.celebration;
    case 'palmas':
      return Icons.park;
    case 'sanjuandereta':
      return Icons.restaurant;
    case 'junta_general_ordinaria':
      return Icons.groups;
    default:
      return Icons.event;
  }
}

String _typeLabelFor(String type) {
  return EventsService.definitionFor(type).shortTitle;
}

String _statusLabelForItem(_EventItem item) {
  if (item.type == 'festividad_27_diciembre') {
    if (item.festInscripcion != null) return 'Inscrito';
    final estado = '${item.festEdicion?['estado'] ?? ''}';
    if (estado == 'abierto') return 'Abierto';
    if (estado == 'cerrado' || estado == 'finalizada') return 'Cerrado';
    return 'Publicado';
  }
  final campaign = item.campaign!;
  final reg = item.registration;
  if (reg != null) return _registrationStatusLabel(reg.status);
  return _eventStatusLabel(campaign);
}

Color _statusColorForItem(_EventItem item) {
  if (item.category == _EventCategory.actionRequired) {
    return Colors.orange.shade700;
  }
  if (item.registration != null || item.festInscripcion != null) {
    return AppTheme.accentColor;
  }
  if (item.category == _EventCategory.historical) {
    return AppTheme.textSecondary;
  }
  return AppTheme.primaryColor;
}

String _ctaLabelForItem(_EventItem item) {
  if (item.type == 'festividad_27_diciembre') {
    if (item.festInscripcion != null) return 'Ver inscripción';
    final estado = '${item.festEdicion?['estado'] ?? ''}';
    if (estado == 'abierto') return 'Inscribirme';
    return 'Ver detalles';
  }
  final campaign = item.campaign!;
  final reg = item.registration;
  if (campaign.type == 'junta_general_ordinaria') {
    if (reg == null) return 'Responder asistencia';
    if (reg.status == 'not_attending') return 'Delegar voto';
    return 'Ver convocatoria';
  }
  if (campaign.type == 'palmas') {
    if (reg != null) return 'Ver mi petición';
    if (campaign.isOpen) return 'Solicitar palma';
    return 'Ver detalles';
  }
  if (reg != null) {
    if (campaign.isOpen) return 'Modificar inscripción';
    return 'Ver inscripción';
  }
  if (campaign.isOpen) return 'Inscribirme';
  return 'Ver detalles';
}

String? _dateTextForItem(_EventItem item) {
  if (item.type == 'festividad_27_diciembre') {
    final raw = item.festEdicion?['fecha'];
    final fecha =
        raw is Timestamp ? raw.toDate() : (raw is DateTime ? raw : null);
    if (fecha != null) return _fmtDate(fecha);
    return null;
  }
  final date = item.campaign?.eventDate;
  if (date != null) return _fmtDate(date);
  return null;
}

String? _deadlineTextForItem(_EventItem item) {
  if (item.type == 'festividad_27_diciembre') {
    final raw = item.festEdicion?['fecha_limite'];
    final limit =
        raw is Timestamp ? raw.toDate() : (raw is DateTime ? raw : null);
    if (limit != null) return 'Límite: ${_fmtDate(limit)}';
    return null;
  }
  final endDate = item.campaign?.endDate;
  if (endDate != null && (item.campaign?.isOpen ?? false)) {
    final remaining = endDate.difference(DateTime.now()).inDays;
    if (remaining >= 0) {
      return remaining == 0
          ? 'Último día'
          : remaining == 1
              ? 'Queda 1 día'
              : 'Quedan $remaining días';
    }
  }
  return null;
}

String _fmtDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

// ---------------------------------------------------------------------------
//  Event detail panel (shown when a card is tapped)
// ---------------------------------------------------------------------------

class _EventDetailPanel extends StatefulWidget {
  final String type;
  final String? focusCampaignId;

  const _EventDetailPanel({
    required this.type,
    this.focusCampaignId,
  });

  @override
  State<_EventDetailPanel> createState() => _EventDetailPanelState();
}

class _EventDetailPanelState extends State<_EventDetailPanel> {
  List<Cofrade> _cofrades = const [];
  Cofrade? _selectedCofrade;
  bool _loadingCofrades = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    // Festividad has its own dedicated screen
    if (widget.type == 'festividad_27_diciembre') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/festividad');
      });
      return const Center(child: CircularProgressIndicator());
    }

    final auth = context.watch<AuthService>();
    final current = auth.cofrade;
    final eventsService = context.read<EventsService>();
    final definition = EventsService.definitionFor(widget.type);
    if (current == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _ModulePadding(
      child: StreamBuilder<List<EventCampaign>>(
        stream: eventsService.watchVisibleCampaigns(widget.type),
        builder: (context, campaignSnap) {
          final campaigns = campaignSnap.data ?? const <EventCampaign>[];
          if (campaigns.isEmpty) {
            return _EmptySpecialCard(
              title: definition.title,
              message: 'No hay eventos visibles en este momento.',
            );
          }
          return StreamBuilder<List<EventRegistration>>(
            stream: eventsService.watchMyRegistrations(current.id),
            builder: (context, regSnap) {
              final allMyRegs = (regSnap.data ?? const <EventRegistration>[])
                  .where((reg) => reg.type == widget.type)
                  .toList();
              final orderedCampaigns = [...campaigns]..sort((a, b) {
                  if (a.id == widget.focusCampaignId) return -1;
                  if (b.id == widget.focusCampaignId) return 1;
                  return 0;
                });
              final primary = orderedCampaigns.firstWhere(
                (campaign) => campaign.isOpen,
                orElse: () => orderedCampaigns.first,
              );
              final openCampaigns =
                  campaigns.where((campaign) => campaign.isOpen).toList();
              final upcomingCampaigns = campaigns
                  .where((campaign) =>
                      !campaign.isOpen && !campaign.isHistorical)
                  .toList();
              final historicalCampaigns = campaigns
                  .where((campaign) => campaign.isHistorical)
                  .toList();
              final myPrimaryRegs = allMyRegs
                  .where((reg) => reg.campaignId == primary.id)
                  .toList();
              final noun =
                  widget.type == 'palmas' ? 'petición' : 'inscripción';

              if (widget.type == 'palmas') {
                return _PalmasCampaignsView(
                  campaigns: orderedCampaigns,
                  registrations: allMyRegs,
                  current: current,
                  events: eventsService,
                  focusCampaignId: widget.focusCampaignId,
                  saving: _saving,
                  onRegisterSelf: (campaign, input) => _register(
                      eventsService, campaign, current, current, input),
                  onSavingChanged: (value) {
                    if (mounted) setState(() => _saving = value);
                  },
                );
              }
              if (widget.type == 'junta_general_ordinaria') {
                return _JuntaCampaignsView(
                  campaigns: orderedCampaigns,
                  registrations: allMyRegs,
                  current: current,
                  events: eventsService,
                  focusCampaignId: widget.focusCampaignId,
                  saving: _saving,
                  onSavingChanged: (value) {
                    if (mounted) setState(() => _saving = value);
                  },
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (openCampaigns.isNotEmpty)
                    _EventSection(
                      title: 'Eventos abiertos',
                      campaigns: openCampaigns,
                      registrations: allMyRegs,
                    ),
                  if (allMyRegs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _RegistrationListSection(
                        registrations: allMyRegs, noun: noun),
                  ],
                  if (upcomingCampaigns.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _EventSection(
                      title: 'Próximos eventos',
                      campaigns: upcomingCampaigns,
                      registrations: allMyRegs,
                    ),
                  ],
                  if (historicalCampaigns.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _EventSection(
                      title: 'Histórico',
                      campaigns: historicalCampaigns,
                      registrations: allMyRegs,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _CampaignHeader(campaign: primary),
                  const SizedBox(height: 16),
                  if (myPrimaryRegs.isNotEmpty)
                    ...myPrimaryRegs.map(
                        (reg) => _RegistrationStatusCard(reg: reg, noun: noun)),
                  const SizedBox(height: 16),
                  if (primary.isOpen && myPrimaryRegs.isEmpty)
                    _GenericRegistrationCard(
                      campaign: primary,
                      noun: noun,
                      cofrades: _cofrades,
                      selected: _selectedCofrade,
                      loading: _loadingCofrades,
                      saving: _saving,
                      onLoadCofrades: _loadCofrades,
                      onSelected: (value) =>
                          setState(() => _selectedCofrade = value),
                      onRegisterSelf: (input) => _register(
                          eventsService, primary, current, current, input),
                      onRegisterOther: _selectedCofrade == null
                          ? null
                          : (input) => _register(
                                eventsService,
                                primary,
                                _selectedCofrade!,
                                current,
                                input,
                              ),
                    )
                  else if (!primary.isOpen && myPrimaryRegs.isEmpty)
                    const _ClosedCampaignNotice(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _loadCofrades() async {
    setState(() => _loadingCofrades = true);
    try {
      final list = await context.read<FirestoreService>().searchCofrades('');
      if (mounted) setState(() => _cofrades = list);
    } finally {
      if (mounted) setState(() => _loadingCofrades = false);
    }
  }

  Future<void> _register(
    EventsService eventsService,
    EventCampaign campaign,
    Cofrade cofrade,
    Cofrade addedBy,
    _RegistrationInput input,
  ) async {
    setState(() => _saving = true);
    try {
      await eventsService.registerCofrade(
        campaign: campaign,
        cofrade: cofrade,
        addedBy: addedBy,
        menu: input.menu,
        answers: input.answers,
        participantAnswers: input.participantAnswers,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${cofrade.nombreCompleto} inscrito.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('$error'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _JuntaCampaignsView extends StatelessWidget {
  final List<EventCampaign> campaigns;
  final List<EventRegistration> registrations;
  final Cofrade current;
  final EventsService events;
  final String? focusCampaignId;
  final bool saving;
  final ValueChanged<bool> onSavingChanged;

  const _JuntaCampaignsView({
    required this.campaigns,
    required this.registrations,
    required this.current,
    required this.events,
    required this.focusCampaignId,
    required this.saving,
    required this.onSavingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final visible = campaigns
        .where((campaign) => !campaign.deleted && campaign.status != 'archived')
        .toList();
    final focused = focusCampaignId == null
        ? null
        : visible.where((campaign) => campaign.id == focusCampaignId).toList();
    final open = visible
        .where((campaign) =>
            campaign.isOpen ||
            registrations.any((reg) => reg.campaignId == campaign.id))
        .toList();
    final shown = focused != null && focused.isNotEmpty ? focused : open;
    if (shown.isEmpty) {
      return const _EmptySpecialCard(
        title: 'Junta General Ordinaria',
        message: 'No hay encuestas visibles en este momento.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final campaign in shown) ...[
          _CampaignHeader(campaign: campaign),
          const SizedBox(height: 12),
          _JuntaAttendanceCard(
            campaign: campaign,
            registration: _preferredJuntaRegistration(campaign),
            relatedRegistrations: _juntaRegistrations(campaign),
            current: current,
            events: events,
            saving: saving,
            onSavingChanged: onSavingChanged,
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  EventRegistration? _preferredJuntaRegistration(EventCampaign campaign) {
    final regs = _juntaRegistrations(campaign);
    final own = regs.where((reg) => reg.cofradeId == current.id).toList();
    if (own.isNotEmpty) return own.first;
    return regs.cast<EventRegistration?>().firstWhere(
          (reg) => reg != null,
          orElse: () => null,
        );
  }

  List<EventRegistration> _juntaRegistrations(EventCampaign campaign) =>
      registrations.where((reg) => reg.campaignId == campaign.id).toList();
}

class _JuntaAttendanceCard extends StatefulWidget {
  final EventCampaign campaign;
  final EventRegistration? registration;
  final List<EventRegistration> relatedRegistrations;
  final Cofrade current;
  final EventsService events;
  final bool saving;
  final ValueChanged<bool> onSavingChanged;

  const _JuntaAttendanceCard({
    required this.campaign,
    required this.registration,
    required this.relatedRegistrations,
    required this.current,
    required this.events,
    required this.saving,
    required this.onSavingChanged,
  });

  @override
  State<_JuntaAttendanceCard> createState() => _JuntaAttendanceCardState();
}

class _JuntaAttendanceCardState extends State<_JuntaAttendanceCard> {
  final _searchCtrl = TextEditingController();
  List<Cofrade> _results = const [];
  bool _searching = false;
  bool _showOwnDelegationSelector = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final relatedReg = widget.registration;
    final ownRegistration = widget.relatedRegistrations
        .cast<EventRegistration?>()
        .firstWhere((reg) => reg?.cofradeId == widget.current.id,
            orElse: () => null);
    final reg = ownRegistration ?? relatedReg;
    final isNotAttending = ownRegistration?.status == 'not_attending';
    final allRelatedVotes = widget.relatedRegistrations
        .expand((registration) => registration.delegatedVotes)
        .map((vote) => Map<String, dynamic>.from(vote))
        .toList();
    final pendingRequests = allRelatedVotes
        .where((vote) =>
            '${vote['delegatingCofradeId'] ?? ''}' == widget.current.id &&
            '${vote['status'] ?? 'requested'}' == 'requested')
        .toList();
    final acceptedOwnDelegations = allRelatedVotes
        .where((vote) =>
            '${vote['delegatingCofradeId'] ?? ''}' == widget.current.id &&
            '${vote['status'] ?? ''}' == 'accepted')
        .toList();
    final rejectedOwnDelegations = allRelatedVotes
        .where((vote) =>
            '${vote['delegatingCofradeId'] ?? ''}' == widget.current.id &&
            '${vote['status'] ?? ''}' == 'rejected')
        .toList();
    final ownResponsePending = ownRegistration == null;
    final editable = widget.campaign.isOpen && ownRegistration != null;
    final carriedVotes = ownRegistration?.delegatedVotes ?? const [];
    final statusText = ownResponsePending
        ? 'Pendiente de respuesta'
        : pendingRequests.isNotEmpty
            ? 'Solicitud de delegaci\u00f3n pendiente'
            : isNotAttending
                ? 'No asistir\u00e1s'
                : 'Asistencia confirmada';
    final statusColor = ownResponsePending
        ? Colors.orange.shade700
        : pendingRequests.isNotEmpty
            ? Colors.blue.shade700
            : isNotAttending
                ? AppTheme.textSecondary
                : AppTheme.accentColor;
    final statusIcon = ownResponsePending
        ? Icons.pending_actions
        : pendingRequests.isNotEmpty
            ? Icons.how_to_vote
            : isNotAttending
                ? Icons.block
                : Icons.check_circle;
    return Card(
      elevation: ownResponsePending ? 2 : 0,
      shadowColor: ownResponsePending
          ? Colors.orange.withAlpha(60)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: ownResponsePending
              ? Colors.orange.withAlpha(100)
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: statusColor.withAlpha(40)),
              ),
              child: Row(
                children: [
                  Icon(statusIcon,
                      size: 18, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (ownRegistration != null && !isNotAttending)
                    _InfoBadge(
                      text:
                          '${_countVotes(ownRegistration, 'accepted')} delegado(s)',
                      color: AppTheme.primaryColor,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              ownResponsePending
                  ? 'Confirma tu asistencia'
                  : pendingRequests.isNotEmpty
                      ? 'Tienes solicitudes pendientes'
                      : isNotAttending
                          ? 'No vas a asistir a esta junta'
                          : 'Tu asistencia est\u00e1 confirmada',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _JuntaDetails(campaign: widget.campaign),
            const SizedBox(height: 14),
            if (pendingRequests.isNotEmpty) ...[
              const Text(
                'Solicitudes pendientes recibidas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final vote in pendingRequests)
                Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.how_to_vote),
                    title: Text(
                        '${vote['delegatedToCofradeName'] ?? 'Un cofrade'} solicita que delegues tu voto en él.'),
                    subtitle: const Text(
                        'Hasta que aceptes, este voto no cuenta como confirmado.'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _respondVote(
                              _registrationIdForVote(vote) ?? reg?.id ?? '',
                              false),
                          child: const Text('Rechazar'),
                        ),
                        ElevatedButton(
                          onPressed: () => _respondVote(
                              _registrationIdForVote(vote) ?? reg?.id ?? '',
                              true),
                          child: const Text('Aceptar'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            if (ownResponsePending) ...[
              const Text(
                'Elige cómo quieres responder a esta Junta General.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: widget.saving || !widget.campaign.isOpen
                        ? null
                        : _confirmAttendance,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Voy a asistir'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.saving || !widget.campaign.isOpen
                        ? null
                        : _markNotAttending,
                    icon: const Icon(Icons.block),
                    label: const Text('No voy a asistir'),
                  ),
                ],
              ),
              if (rejectedOwnDelegations.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final vote in rejectedOwnDelegations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.cancel_outlined, color: Colors.red),
                    title: Text(
                        '${vote['delegatedToCofradeName'] ?? 'Un cofrade'} solicitó tu voto delegado.'),
                    subtitle: const Text(
                        'Solicitud rechazada. Tu asistencia sigue pendiente hasta que elijas una respuesta.'),
                  ),
              ],
              if (!widget.campaign.isOpen)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'La convocatoria está cerrada y no permite nuevas confirmaciones.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
            ] else if (isNotAttending) ...[
              if (widget.campaign.isOpen) ...[
                ElevatedButton.icon(
                  onPressed: widget.saving ? null : _confirmAttendance,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar asistencia'),
                ),
                const SizedBox(height: 12),
              ],
              if (acceptedOwnDelegations.isNotEmpty)
                for (final vote in acceptedOwnDelegations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline,
                        color: Colors.green),
                    title: Text(
                        'Has delegado tu voto en ${vote['delegatedToCofradeName'] ?? ''}.'),
                    subtitle: const Text('Delegación confirmada'),
                  )
              else if (widget.campaign.isOpen) ...[
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _showOwnDelegationSelector = !_showOwnDelegationSelector;
                    if (!_showOwnDelegationSelector) {
                      _searchCtrl.clear();
                      _results = const [];
                    }
                  }),
                  icon: const Icon(Icons.how_to_vote_outlined),
                  label: const Text('Delegar mi voto'),
                ),
                if (_showOwnDelegationSelector) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Elige un cofrade que ya haya confirmado asistencia.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  _searchBox('Buscar asistente receptor'),
                  const SizedBox(height: 8),
                  if (_searching) const LinearProgressIndicator(),
                  for (final cofrade in _results.take(6))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_search),
                      title: Text(cofrade.nombreCompleto),
                      subtitle: Text(
                          'Nº ${cofrade.numero ?? '-'}${(cofrade.dni ?? '').isEmpty ? '' : ' · DNI ${cofrade.dni}'}'),
                      trailing: TextButton(
                        onPressed: () => _delegateOwnVoteTo(cofrade),
                        child: const Text('Delegar'),
                      ),
                    ),
                ],
              ],
            ] else ...[
              if (widget.campaign.isOpen) ...[
                OutlinedButton.icon(
                  onPressed: widget.saving ? null : _markNotAttending,
                  icon: const Icon(Icons.block),
                  label: const Text('Cambiar a No voy a asistir'),
                ),
                const SizedBox(height: 12),
              ],
              _DelegatedVotesList(
                votes: carriedVotes,
                canEdit: editable,
                onRemove: _removeVote,
              ),
              const SizedBox(height: 12),
              if (editable) ...[
                _searchBox('Buscar cofrade que delega su voto'),
                const SizedBox(height: 8),
                if (_searching) const LinearProgressIndicator(),
                for (final cofrade in _results.take(6))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_add_alt_1),
                    title: Text(cofrade.nombreCompleto),
                    subtitle: Text(
                        'Nº ${cofrade.numero ?? '-'}${(cofrade.dni ?? '').isEmpty ? '' : ' · DNI ${cofrade.dni}'}'),
                    trailing: TextButton(
                      onPressed: () => _addVote(cofrade),
                      child: const Text('Añadir'),
                    ),
                  ),
              ] else
                const Text(
                  'La Junta está cerrada o finalizada. Las delegaciones ya no se pueden editar desde la zona privada.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
            ],
          ],
        ),
      ),
    );
  }

  int _countVotes(EventRegistration reg, String status) => reg.delegatedVotes
      .where((vote) => '${vote['status'] ?? 'requested'}' == status)
      .length;

  String? _registrationIdForVote(Map<String, dynamic> vote) {
    final delegatingId = '${vote['delegatingCofradeId'] ?? ''}';
    for (final registration in widget.relatedRegistrations) {
      final found = registration.delegatedVotes.any((item) =>
          '${item['delegatingCofradeId'] ?? ''}' == delegatingId &&
          '${item['delegatedToCofradeId'] ?? ''}' ==
              '${vote['delegatedToCofradeId'] ?? ''}' &&
          '${item['status'] ?? 'requested'}' ==
              '${vote['status'] ?? 'requested'}');
      if (found) return registration.id;
    }
    return null;
  }

  Widget _searchBox(String label) {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Busca por nombre, apellidos, nº cofrade o DNI.',
        suffixIcon: IconButton(
          icon: const Icon(Icons.search),
          onPressed: _search,
        ),
      ),
      onSubmitted: (_) => _search(),
    );
  }

  Future<void> _confirmAttendance() async {
    widget.onSavingChanged(true);
    try {
      await widget.events.confirmJuntaAttendance(
        campaign: widget.campaign,
        cofrade: widget.current,
        changedBy: widget.current.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asistencia confirmada.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      widget.onSavingChanged(false);
    }
  }

  Future<void> _markNotAttending() async {
    widget.onSavingChanged(true);
    try {
      await widget.events.markJuntaNotAttending(
        campaign: widget.campaign,
        cofrade: widget.current,
        changedBy: widget.current.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respuesta registrada.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      widget.onSavingChanged(false);
    }
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.length < 2) return;
    setState(() => _searching = true);
    try {
      final found =
          await context.read<FirestoreService>().searchCofrades(query);
      if (mounted) {
        var filtered =
            found.where((cofrade) => cofrade.id != widget.current.id).toList();
        if (widget.registration?.status == 'not_attending') {
          final valid = <Cofrade>[];
          for (final cofrade in filtered) {
            final registration = await widget.events.getRegistrationForCofrade(
              campaignId: widget.campaign.id,
              cofradeId: cofrade.id,
            );
            if (registration != null &&
                registration.status != 'not_attending' &&
                registration.status != 'cancelled') {
              valid.add(cofrade);
            }
          }
          filtered = valid;
        }
        setState(() => _results = filtered);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addVote(Cofrade delegatingCofrade) async {
    final reg = widget.registration;
    if (reg == null) return;
    try {
      await widget.events.addDelegatedVote(
        campaign: widget.campaign,
        registrationId: reg.id,
        delegatingCofrade: delegatingCofrade,
        delegatedTo: widget.current,
        registeredBy: widget.current.id,
        source: 'private',
        status: 'requested',
      );
      if (mounted) {
        _searchCtrl.clear();
        setState(() => _results = const []);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voto delegado añadido.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _delegateOwnVoteTo(Cofrade attendee) async {
    try {
      final attendeeRegistration =
          await widget.events.getRegistrationForCofrade(
        campaignId: widget.campaign.id,
        cofradeId: attendee.id,
      );
      if (attendeeRegistration == null ||
          attendeeRegistration.status == 'not_attending') {
        throw Exception(
            '${attendee.nombreCompleto} no figura como asistente confirmado.');
      }
      await widget.events.delegateOwnVoteToAttendee(
        campaign: widget.campaign,
        delegatingCofrade: widget.current,
        attendeeRegistration: attendeeRegistration,
        changedBy: widget.current.id,
      );
      if (mounted) {
        _searchCtrl.clear();
        setState(() => _results = const []);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voto delegado registrado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _respondVote(String registrationId, bool accept) async {
    if (registrationId.isEmpty) return;
    widget.onSavingChanged(true);
    try {
      await widget.events.respondDelegatedVote(
        registrationId: registrationId,
        delegatingCofradeId: widget.current.id,
        changedBy: widget.current.id,
        accept: accept,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(accept ? 'Delegación aceptada.' : 'Delegación rechazada.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      widget.onSavingChanged(false);
    }
  }

  Future<void> _removeVote(String cofradeId) async {
    final reg = widget.registration;
    if (reg == null) return;
    await widget.events.removeDelegatedVote(
      registrationId: reg.id,
      delegatingCofradeId: cofradeId,
      changedBy: widget.current.id,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voto delegado eliminado.')),
      );
    }
  }
}

class _JuntaDetails extends StatelessWidget {
  final EventCampaign campaign;

  const _JuntaDetails({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final firstCall =
        '${campaign.registrationConfig['firstCallTime'] ?? campaign.registrationConfig['horaPrimeraConvocatoria'] ?? campaign.registrationConfig['firstCall'] ?? ''}'
            .trim();
    final secondCall =
        '${campaign.registrationConfig['secondCallTime'] ?? campaign.registrationConfig['horaSegundaConvocatoria'] ?? campaign.registrationConfig['secondCall'] ?? ''}'
            .trim();
    final eventDate = campaign.eventDate;
    final dateText = eventDate == null
        ? 'Fecha pendiente'
        : '${eventDate.day.toString().padLeft(2, '0')}/${eventDate.month.toString().padLeft(2, '0')}/${eventDate.year}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryColor.withAlpha(35)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _InlineInfo(icon: Icons.event, text: dateText),
          if (campaign.location.trim().isNotEmpty)
            _InlineInfo(icon: Icons.place_outlined, text: campaign.location),
          if (firstCall.isNotEmpty)
            _InlineInfo(icon: Icons.schedule, text: '1ª conv. $firstCall'),
          if (secondCall.isNotEmpty)
            _InlineInfo(
                icon: Icons.schedule_outlined, text: '2ª conv. $secondCall'),
        ],
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DelegatedVotesList extends StatelessWidget {
  final List<Map<String, dynamic>> votes;
  final bool canEdit;
  final ValueChanged<String> onRemove;

  const _DelegatedVotesList({
    required this.votes,
    required this.canEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (votes.isEmpty) {
      return const Text(
        'No hay votos delegados registrados.',
        style: TextStyle(color: AppTheme.textSecondary),
      );
    }
    return Column(
      children: votes
          .map((vote) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.how_to_vote_outlined),
                title: Text('${vote['delegatingCofradeName'] ?? ''}'),
                subtitle: Text(
                    '${_voteStatusLabel('${vote['status'] ?? 'requested'}')} · Nº ${vote['delegatingCofradeNumber'] ?? '-'}${('${vote['delegatingCofradeDni'] ?? ''}').isEmpty ? '' : ' · DNI ${vote['delegatingCofradeDni']}'}'),
                trailing: canEdit
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            onRemove('${vote['delegatingCofradeId'] ?? ''}'),
                      )
                    : null,
              ))
          .toList(),
    );
  }

  String _voteStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Aceptado';
      case 'rejected':
        return 'Rechazado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Pendiente';
    }
  }
}

class _PalmasCampaignsView extends StatelessWidget {
  final List<EventCampaign> campaigns;
  final List<EventRegistration> registrations;
  final Cofrade current;
  final EventsService events;
  final String? focusCampaignId;
  final bool saving;
  final void Function(EventCampaign campaign, _RegistrationInput input)
      onRegisterSelf;
  final ValueChanged<bool> onSavingChanged;

  const _PalmasCampaignsView({
    required this.campaigns,
    required this.registrations,
    required this.current,
    required this.events,
    required this.focusCampaignId,
    required this.saving,
    required this.onRegisterSelf,
    required this.onSavingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final visible = campaigns
        .where((campaign) => !campaign.deleted && campaign.status != 'archived')
        .toList();
    final focused = focusCampaignId == null
        ? null
        : visible.where((campaign) => campaign.id == focusCampaignId).toList();
    final open = visible
        .where((campaign) =>
            campaign.isOpen ||
            registrations.any((reg) => reg.campaignId == campaign.id))
        .toList();
    final shown = focused != null && focused.isNotEmpty ? focused : open;
    final history = visible
        .where((campaign) =>
            campaign.status == 'finished' &&
            registrations.any((reg) => reg.campaignId == campaign.id))
        .toList();
    if (shown.isEmpty && history.isEmpty) {
      return const _EmptySpecialCard(
        title: 'Petición de Palmas',
        message: 'No hay campañas de palmas visibles en este momento.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shown.isNotEmpty) ...[
          Text('Petición de Palmas',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ...shown.map((campaign) {
            final reg = _registrationFor(campaign);
            return _PalmasCampaignCard(
              campaign: campaign,
              registration: reg,
              current: current,
              events: events,
              saving: saving,
              onRegisterSelf: (input) => onRegisterSelf(campaign, input),
              onSavingChanged: onSavingChanged,
              expanded: focusCampaignId == campaign.id ||
                  reg != null ||
                  shown.length == 1,
            );
          }),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...history.map((campaign) => _PalmasCampaignCard(
                campaign: campaign,
                registration: _registrationFor(campaign),
                current: current,
                events: events,
                saving: saving,
                onRegisterSelf: (input) => onRegisterSelf(campaign, input),
                onSavingChanged: onSavingChanged,
                expanded: focusCampaignId == campaign.id,
              )),
        ],
      ],
    );
  }

  EventRegistration? _registrationFor(EventCampaign campaign) {
    final matches =
        registrations.where((reg) => reg.campaignId == campaign.id).toList();
    return matches.isEmpty ? null : matches.first;
  }
}

class _PalmasCampaignCard extends StatelessWidget {
  final EventCampaign campaign;
  final EventRegistration? registration;
  final Cofrade current;
  final EventsService events;
  final bool saving;
  final ValueChanged<_RegistrationInput> onRegisterSelf;
  final ValueChanged<bool> onSavingChanged;
  final bool expanded;

  const _PalmasCampaignCard({
    required this.campaign,
    required this.registration,
    required this.current,
    required this.events,
    required this.saving,
    required this.onRegisterSelf,
    required this.onSavingChanged,
    this.expanded = false,
  });

  String _palmasCta() {
    if (registration != null) {
      if (campaign.isOpen && registration!.status != 'cancelada') {
        return 'Modificar solicitud';
      }
      return 'Ver mi solicitud';
    }
    return campaign.isOpen ? 'Solicitar palma' : 'Ver evento';
  }

  String _palmasStatusText() {
    if (registration == null) {
      return campaign.isOpen ? 'No solicitada' : 'Sin solicitud';
    }
    return 'Solicitud: ${_registrationStatusLabel(registration!.status)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasRegistration = registration != null;
    final statusColor = hasRegistration
        ? _palmasStatusColor(registration!.status)
        : (campaign.isOpen ? Colors.orange.shade700 : AppTheme.textSecondary);
    final statusIcon = hasRegistration
        ? (registration!.status == 'confirmada' ||
                registration!.status == 'confirmed'
            ? Icons.check_circle
            : registration!.status == 'rechazada' ||
                    registration!.status == 'rejected'
                ? Icons.cancel
                : registration!.status == 'entregada' ||
                        registration!.status == 'delivered'
                    ? Icons.local_shipping
                    : Icons.hourglass_top)
        : Icons.pending_actions;
    final participantCount = hasRegistration
        ? registration!.participants.length
        : 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      elevation: campaign.isOpen && !hasRegistration ? 2 : 0,
      shadowColor: campaign.isOpen && !hasRegistration
          ? Colors.orange.withAlpha(60)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: campaign.isOpen && !hasRegistration
              ? Colors.orange.withAlpha(100)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (campaign.coverImageUrl.isNotEmpty)
            Stack(
              children: [
                Image.network(
                  campaign.coverImageUrl,
                  width: double.infinity,
                  height: 170,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: campaign.isOpen
                          ? AppTheme.accentColor
                          : AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _eventStatusLabel(campaign),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.park,
                        color: AppTheme.primaryColor, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'Petici\u00f3n de Palmas',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    if (campaign.coverImageUrl.isEmpty)
                      _InfoBadge(
                        text: _eventStatusLabel(campaign),
                        color: campaign.isOpen
                            ? AppTheme.accentColor
                            : AppTheme.primaryColor,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(campaign.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                if (campaign.description.isNotEmpty &&
                    !hasRegistration) ...[
                  const SizedBox(height: 4),
                  Text(
                    campaign.description.length > 100
                        ? '${campaign.description.substring(0, 100)}...'
                        : campaign.description,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(12),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: statusColor.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon,
                          size: 18, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _palmasStatusText(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (hasRegistration && campaign.requiresPayment)
                        _InfoBadge(
                        text:
                            'Pago: ${_paymentStatusLabel(registration!.paymentStatus)}',
                        color: _paymentStatusColor(registration!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (campaign.endDate != null && campaign.isOpen)
                      _SmallIconText(
                        icon: Icons.timer_outlined,
                        text: _deadlineLabel(campaign.endDate!),
                        urgent: campaign.endDate!
                                .difference(DateTime.now())
                                .inDays <=
                            3,
                      ),
                    if (campaign.eventDate != null)
                      _SmallIconText(
                        icon: Icons.calendar_today,
                        text:
                            '${campaign.eventDate!.day}/${campaign.eventDate!.month}/${campaign.eventDate!.year}',
                      ),
                    if (campaign.location.isNotEmpty)
                      _SmallIconText(
                        icon: Icons.place_outlined,
                        text: campaign.location,
                      ),
                    if (participantCount > 1)
                      _SmallIconText(
                        icon: Icons.group,
                        text:
                            '${participantCount - 1} persona${participantCount > 2 ? 's' : ''} a\u00f1adida${participantCount > 2 ? 's' : ''}',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context
                          .go(EventsService.routeForCampaign(campaign));
                    },
                    style: ElevatedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor:
                          campaign.isOpen && !hasRegistration
                              ? AppTheme.primaryColor
                              : null,
                    ),
                    child: Text(_palmasCta()),
                  ),
                ),
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: _PalmasCampaignDetail(
                campaign: campaign,
                registration: registration,
                current: current,
                events: events,
                saving: saving,
                onRegisterSelf: onRegisterSelf,
                onSavingChanged: onSavingChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _PalmasCampaignDetail extends StatelessWidget {
  final EventCampaign campaign;
  final EventRegistration? registration;
  final Cofrade current;
  final EventsService events;
  final bool saving;
  final ValueChanged<_RegistrationInput> onRegisterSelf;
  final ValueChanged<bool> onSavingChanged;

  const _PalmasCampaignDetail({
    required this.campaign,
    required this.registration,
    required this.current,
    required this.events,
    required this.saving,
    required this.onRegisterSelf,
    required this.onSavingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CampaignHeader(campaign: campaign),
        const SizedBox(height: 14),
        if (registration != null) ...[
          _RegistrationStatusCard(reg: registration!, noun: 'petición'),
          const SizedBox(height: 14),
          _PalmasEditRegistrationCard(
            campaign: campaign,
            registration: registration!,
            current: current,
            events: events,
            enabled: campaign.isOpen && registration!.status != 'cancelada',
            onSavingChanged: onSavingChanged,
          ),
        ] else if (campaign.isOpen)
          _GenericRegistrationCard(
            campaign: campaign,
            noun: 'petición',
            cofrades: const [],
            selected: null,
            loading: false,
            saving: saving,
            onLoadCofrades: () {},
            onSelected: (_) {},
            onRegisterSelf: onRegisterSelf,
            onRegisterOther: null,
          )
        else
          const _ClosedCampaignNotice(),
      ],
    );
  }
}

class _PalmasEditRegistrationCard extends StatefulWidget {
  final EventCampaign campaign;
  final EventRegistration registration;
  final Cofrade current;
  final EventsService events;
  final bool enabled;
  final ValueChanged<bool> onSavingChanged;

  const _PalmasEditRegistrationCard({
    required this.campaign,
    required this.registration,
    required this.current,
    required this.events,
    required this.enabled,
    required this.onSavingChanged,
  });

  @override
  State<_PalmasEditRegistrationCard> createState() =>
      _PalmasEditRegistrationCardState();
}

class _PalmasEditRegistrationCardState
    extends State<_PalmasEditRegistrationCard> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _externalNameCtrl = TextEditingController();
  final TextEditingController _externalDniCtrl = TextEditingController();
  List<Cofrade> _results = const [];
  Cofrade? _selected;
  bool _searching = false;
  bool _saving = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _externalNameCtrl.dispose();
    _externalDniCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final participants = widget.registration.participants;
    return _ActionPanel(
      title: 'Gestionar petición',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.enabled)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_clock, color: AppTheme.textSecondary),
              title: Text('La edición está cerrada.'),
              subtitle: Text('El evento ya no admite cambios en la petición.'),
            )
          else ...[
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Buscar cofrade por nombre, DNI, teléfono o email',
                border: const OutlineInputBorder(),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
              ),
              onChanged: _search,
            ),
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final cofrade = _results[index];
                    final alreadyHere = participants.any(
                      (participant) => participant['cofradeId'] == cofrade.id,
                    );
                    return ListTile(
                      dense: true,
                      title: Text(cofrade.nombreCompleto),
                      subtitle: Text([
                        if (cofrade.numero != null) 'Nº ${cofrade.numero}',
                        if ((cofrade.dni ?? '').isNotEmpty) cofrade.dni!,
                        if (cofrade.email.isNotEmpty) cofrade.email,
                      ].join(' · ')),
                      trailing: alreadyHere
                          ? const Text('Ya incluido')
                          : _selected?.id == cofrade.id
                              ? const Icon(Icons.check_circle,
                                  color: AppTheme.accentColor)
                              : null,
                      onTap: alreadyHere
                          ? null
                          : () => setState(() => _selected = cofrade),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _saving || _selected == null ? null : _addSelected,
                icon: const Icon(Icons.group_add),
                label: const Text('Añadir cofrade a la petición'),
              ),
            ),
            if (widget.campaign.allowExternalGuests) ...[
              const Divider(height: 28),
              const Text('Añadir persona externa',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _externalNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _externalDniCtrl,
                      decoration: const InputDecoration(
                        labelText: 'DNI opcional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _addExternal,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Añadir'),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 12),
          const Text('Cofrades incluidos',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final participant in participants)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text('${participant['name'] ?? 'Cofrade'}'),
              subtitle: Text(
                [
                  if ('${participant['menuName'] ?? ''}'.isNotEmpty)
                    'Menú ${participant['menuName']}',
                  if ((participant['price'] as num?) != null)
                    '${((participant['price'] as num).toDouble()).toStringAsFixed(2)} €',
                ].join(' · '),
              ),
              trailing: widget.enabled &&
                      participant['cofradeId'] != widget.registration.cofradeId
                  ? IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () =>
                          _removeParticipant('${participant['cofradeId']}'),
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _selected = null;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final found =
          await context.read<FirestoreService>().searchCofrades(query);
      if (!mounted) return;
      setState(() {
        _results = found
            .where((cofrade) => cofrade.id != widget.registration.cofradeId)
            .take(8)
            .toList();
      });
    } catch (e) {
      debugPrint('[Eventos] Error buscando cofrades: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addSelected() async {
    final cofrade = _selected;
    if (cofrade == null) return;
    setState(() => _saving = true);
    widget.onSavingChanged(true);
    try {
      await widget.events.addCofradeToRegistration(
        registrationId: widget.registration.id,
        campaign: widget.campaign,
        cofrade: cofrade,
        addedBy: widget.current,
      );
      if (!mounted) return;
      setState(() {
        _selected = null;
        _results = const [];
        _searchCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${cofrade.nombreCompleto} añadido.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
      widget.onSavingChanged(false);
    }
  }

  Future<void> _addExternal() async {
    setState(() => _saving = true);
    try {
      await widget.events.addExternalParticipantToRegistration(
        registrationId: widget.registration.id,
        campaign: widget.campaign,
        name: _externalNameCtrl.text,
        dni: _externalDniCtrl.text,
        changedBy: widget.current.id,
      );
      if (!mounted) return;
      _externalNameCtrl.clear();
      _externalDniCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persona externa añadida.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeParticipant(String cofradeId) async {
    setState(() => _saving = true);
    try {
      await widget.events.removeCofradeFromRegistration(
        registrationId: widget.registration.id,
        campaign: widget.campaign,
        cofradeId: cofradeId,
        changedBy: widget.current.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CampaignHeader extends StatelessWidget {
  final EventCampaign campaign;

  const _CampaignHeader({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final events = context.read<EventsService>();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(campaign.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(campaign.description),
            if (campaign.coverImageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  campaign.coverImageUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('Año ${campaign.year}')),
                Chip(
                    label: Text(
                        campaign.isOpen ? 'Inscripción abierta' : 'Cerrada')),
                if (campaign.type != 'junta_general_ordinaria' &&
                    campaign.cost > 0)
                  Chip(label: Text('${campaign.cost.toStringAsFixed(2)} €')),
              ],
            ),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: events.watchAttachments(campaign.id),
              builder: (context, snap) {
                final attachments = (snap.data ?? const [])
                    .where((attachment) =>
                        attachment['status'] != 'deleted' &&
                        attachment['visibleToUsers'] == true)
                    .toList();
                if (attachments.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: attachments.map((attachment) {
                      final fileName = '${attachment['fileName'] ?? 'Archivo'}';
                      final url = '${attachment['downloadUrl'] ?? ''}';
                      final contentType = '${attachment['contentType'] ?? ''}';
                      final isImage = contentType.startsWith('image/');
                      return OutlinedButton.icon(
                        onPressed: url.isEmpty
                            ? null
                            : () => launchUrl(
                                  Uri.parse(url),
                                  mode: LaunchMode.externalApplication,
                                ),
                        icon: Icon(isImage
                            ? Icons.image_outlined
                            : Icons.picture_as_pdf_outlined),
                        label: Text(isImage ? 'Ver imagen' : fileName),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _InfoBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

String _eventStatusLabel(EventCampaign campaign) {
  if (campaign.isOpen) return 'Abierta';
  switch (campaign.status) {
    case 'draft':
      return 'Borrador';
    case 'published':
      return 'Publicada';
    case 'closed':
      return 'Cerrada';
    case 'finished':
      return 'Finalizada';
    case 'archived':
      return 'Archivada';
    default:
      return campaign.status;
  }
}

String _registrationStatusLabel(String status) {
  switch (status) {
    case 'pending_response':
      return 'Pendiente de respuesta';
    case 'attending':
      return 'Asistiré';
    case 'not_attending':
      return 'No asistiré';
    case 'delegated':
      return 'Voto delegado';
    case 'solicitada':
    case 'requested':
      return 'Solicitada';
    case 'confirmada':
    case 'confirmed':
      return 'Confirmada';
    case 'cancelada':
    case 'cancelled':
      return 'Cancelada';
    case 'rechazada':
    case 'rejected':
      return 'Rechazada';
    case 'entregada':
    case 'delivered':
      return 'Entregada';
    case 'en_espera':
    case 'waitlisted':
      return 'En espera';
    case 'pending':
    case 'pendiente':
      return 'Pendiente';
    default:
      return status;
  }
}

String _paymentStatusLabel(String status) {
  switch (status) {
    case 'paid':
    case 'pagado':
      return 'Pagado';
    case 'partial':
    case 'parcial':
      return 'Parcial';
    case 'not_required':
    case 'exento':
      return 'No requerido';
    case 'refunded':
    case 'devuelto':
      return 'Devuelto';
    default:
      return 'Pendiente';
  }
}

Color _paymentStatusColor(EventRegistration reg) {
  switch (reg.paymentStatus) {
    case 'paid':
    case 'pagado':
    case 'not_required':
      return AppTheme.accentColor;
    case 'partial':
    case 'parcial':
    case 'pending':
      return Colors.orange.shade700;
    case 'refunded':
    case 'devuelto':
    case 'rejected':
      return Colors.red.shade700;
    default:
      return Colors.orange.shade700;
  }
}

Color _palmasStatusColor(String status) {
  switch (status) {
    case 'confirmada':
    case 'confirmed':
      return AppTheme.accentColor;
    case 'rechazada':
    case 'rejected':
      return Colors.red.shade700;
    case 'entregada':
    case 'delivered':
      return Colors.blue.shade700;
    case 'cancelada':
    case 'cancelled':
      return AppTheme.textSecondary;
    default:
      return Colors.orange.shade700;
  }
}

String _deadlineLabel(DateTime deadline) {
  final remaining = deadline.difference(DateTime.now()).inDays;
  if (remaining < 0) return 'Plazo cerrado';
  if (remaining == 0) return 'Último día';
  if (remaining == 1) return 'Queda 1 día';
  return 'Quedan $remaining días';
}

class _RegistrationStatusCard extends StatelessWidget {
  final EventRegistration reg;
  final String noun;

  const _RegistrationStatusCard({required this.reg, this.noun = 'inscripción'});

  @override
  Widget build(BuildContext context) {
    final companionCount =
        reg.participants.length > 1 ? reg.participants.length - 1 : 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.accentColor,
                  child: Icon(Icons.check, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_capitalize(noun)}: ${_registrationStatusLabel(reg.status)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _SmallIconText(
                  icon: Icons.payments_outlined,
                  text: 'Pago: ${_paymentLabel(reg.paymentStatus)}'
                      '${reg.paymentStatus == 'partial' ? ' (${reg.paidAmount.toStringAsFixed(2)} €)' : ''}'
                      '${reg.totalAmount > 0 ? ' · Total: ${reg.totalAmount.toStringAsFixed(2)} €' : ''}',
                ),
                if (companionCount > 0)
                  _SmallIconText(
                    icon: Icons.group,
                    text: '$companionCount acompañante${companionCount > 1 ? 's' : ''}',
                  ),
                if (reg.addedByName.isNotEmpty &&
                    reg.addedById != reg.cofradeId)
                  _SmallIconText(
                    icon: Icons.person_add_alt,
                    text: 'Añadido por ${reg.addedByName}',
                  ),
                if (reg.heightCm != null)
                  _SmallIconText(
                    icon: Icons.height,
                    text: '${reg.heightCm} cm',
                  ),
                if (reg.turnName.isNotEmpty)
                  _SmallIconText(
                    icon: Icons.schedule,
                    text: 'Turno: ${reg.turnName}',
                  ),
              ],
            ),
            if (_registrationDetails(reg).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _registrationDetails(reg).join(' · '),
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _registrationDetails(EventRegistration reg) {
    final lines = <String>[];
    if (reg.answers.isNotEmpty) {
      for (final entry in reg.answers.entries) {
        lines.add('${entry.key}: ${entry.value}');
      }
    }
    for (final participant in reg.participants) {
      final menu = '${participant['menuName'] ?? ''}'.trim();
      if (menu.isNotEmpty) lines.add('Menú: $menu');
      final answers = participant['answers'];
      if (answers is Map) {
        for (final entry in answers.entries) {
          lines.add('${entry.key}: ${entry.value}');
        }
      }
    }
    return lines;
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  String _paymentLabel(String status) {
    switch (status) {
      case 'paid':
      case 'pagado':
        return 'pagado';
      case 'partial':
      case 'parcial':
        return 'parcial';
      case 'not_required':
      case 'exento':
        return 'no requerido';
      default:
        return 'pendiente';
    }
  }
}

class _EventSection extends StatelessWidget {
  final String title;
  final List<EventCampaign> campaigns;
  final List<EventRegistration> registrations;

  const _EventSection({
    required this.title,
    required this.campaigns,
    required this.registrations,
  });

  @override
  Widget build(BuildContext context) {
    return _ActionPanel(
      title: title,
      child: Column(
        children: campaigns.map((campaign) {
          final reg = registrations
              .where((item) => item.campaignId == campaign.id)
              .toList();
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              campaign.isOpen ? Icons.event_available : Icons.event_note,
              color: campaign.isOpen
                  ? AppTheme.accentColor
                  : AppTheme.primaryColor,
            ),
            title: Text(campaign.name),
            subtitle: Text(
              [
                'Año ${campaign.year}',
                campaign.status,
                if (campaign.location.isNotEmpty) campaign.location,
                if (reg.isNotEmpty) 'Ya inscrito',
              ].join(' · '),
            ),
            trailing: Text(campaign.isOpen
                ? (reg.isEmpty ? 'Inscripción abierta' : 'Ver inscripción')
                : 'Ver evento'),
          );
        }).toList(),
      ),
    );
  }
}

class _RegistrationListSection extends StatelessWidget {
  final List<EventRegistration> registrations;
  final String noun;

  const _RegistrationListSection({
    required this.registrations,
    this.noun = 'inscripción',
  });

  @override
  Widget build(BuildContext context) {
    return _ActionPanel(
      title: noun == 'petición' ? 'Mis peticiones' : 'Mis inscripciones',
      child: Column(
        children: registrations
            .map((reg) => _RegistrationStatusCard(reg: reg, noun: noun))
            .toList(),
      ),
    );
  }
}

class _RegistrationInput {
  final Map<String, dynamic>? menu;
  final Map<String, dynamic> answers;
  final Map<String, dynamic> participantAnswers;

  const _RegistrationInput({
    this.menu,
    this.answers = const {},
    this.participantAnswers = const {},
  });
}

class _GenericRegistrationCard extends StatefulWidget {
  final EventCampaign campaign;
  final String noun;
  final List<Cofrade> cofrades;
  final Cofrade? selected;
  final bool loading;
  final bool saving;
  final VoidCallback onLoadCofrades;
  final ValueChanged<Cofrade?> onSelected;
  final ValueChanged<_RegistrationInput> onRegisterSelf;
  final ValueChanged<_RegistrationInput>? onRegisterOther;

  const _GenericRegistrationCard({
    required this.campaign,
    this.noun = 'inscripción',
    required this.cofrades,
    required this.selected,
    required this.loading,
    required this.saving,
    required this.onLoadCofrades,
    required this.onSelected,
    required this.onRegisterSelf,
    required this.onRegisterOther,
  });

  @override
  State<_GenericRegistrationCard> createState() =>
      _GenericRegistrationCardState();
}

class _GenericRegistrationCardState extends State<_GenericRegistrationCard> {
  String? _menuId;
  final Map<String, TextEditingController> _registrationControllers = {};
  final Map<String, TextEditingController> _participantControllers = {};
  final Map<String, bool> _registrationBoolAnswers = {};
  final Map<String, bool> _participantBoolAnswers = {};

  @override
  void dispose() {
    for (final controller in [
      ..._registrationControllers.values,
      ..._participantControllers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAddOther =
        widget.campaign.allowOtherCofrades && widget.onRegisterOther != null;
    final isPeticion = widget.noun == 'petición';
    final activeMenus = widget.campaign.menus
        .where((menu) => menu['active'] != false)
        .toList()
      ..sort((a, b) => ((a['order'] as num?)?.toInt() ?? 0)
          .compareTo((b['order'] as num?)?.toInt() ?? 0));
    final registrationFields = _activeFields('registration');
    final participantFields = _activeFields('participant');
    return _ActionPanel(
      title: isPeticion
          ? 'Solicitar palma'
          : widget.campaign.requiresRegistration
              ? 'Inscripción'
              : 'Confirmación de asistencia',
      child: Column(
        children: [
          if (widget.campaign.menusEnabled && activeMenus.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _menuId,
              decoration: InputDecoration(
                labelText: widget.campaign.menuRequired
                    ? 'Menú por participante *'
                    : 'Menú por participante',
                border: const OutlineInputBorder(),
              ),
              items: activeMenus
                  .map((menu) => DropdownMenuItem(
                        value: '${menu['id']}',
                        child: Text(
                          '${menu['name'] ?? 'Menú'} · ${((menu['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} €',
                        ),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _menuId = value),
            ),
            const SizedBox(height: 12),
          ],
          if (registrationFields.isNotEmpty) ...[
            _FieldsBlock(
              title: 'Preguntas de la inscripción',
              fields: registrationFields,
              controllers: _registrationControllers,
              boolAnswers: _registrationBoolAnswers,
              onBoolChanged: (key, value) =>
                  setState(() => _registrationBoolAnswers[key] = value),
            ),
            const SizedBox(height: 12),
          ],
          if (participantFields.isNotEmpty) ...[
            _FieldsBlock(
              title: 'Preguntas por participante',
              fields: participantFields,
              controllers: _participantControllers,
              boolAnswers: _participantBoolAnswers,
              onBoolChanged: (key, value) =>
                  setState(() => _participantBoolAnswers[key] = value),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.saving
                      ? null
                      : () => _submit(context, widget.onRegisterSelf),
                  icon: const Icon(Icons.person_add),
                  label: Text(isPeticion
                      ? 'Solicitar palma para mí'
                      : widget.campaign.requiresRegistration
                          ? 'Inscribirme'
                          : 'Confirmar asistencia'),
                ),
              ),
              if (canAddOther) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: widget.loading ? null : widget.onLoadCofrades,
                  icon: widget.loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label:
                      Text(isPeticion ? 'Añadir cofrade' : 'Cargar cofrades'),
                ),
              ],
            ],
          ),
          if (canAddOther) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<Cofrade>(
              initialValue: widget.selected,
              decoration:
                  const InputDecoration(labelText: 'Añadir otro cofrade'),
              items: widget.cofrades
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.nombreCompleto),
                      ))
                  .toList(),
              onChanged: widget.onSelected,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: widget.saving || widget.onRegisterOther == null
                    ? null
                    : () => _submit(context, widget.onRegisterOther!),
                icon: const Icon(Icons.group_add),
                label: Text(isPeticion
                    ? 'Añadir a la petición'
                    : 'Añadir seleccionado'),
              ),
            ),
          ],
          if (widget.campaign.requiresPayment &&
              (isPeticion
                      ? widget.campaign.palmMemberPrice
                      : widget.campaign.memberPrice) >
                  0) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.payments_outlined, size: 18),
                label: Text(isPeticion
                    ? 'Importe palma cofrade: ${widget.campaign.palmMemberPrice.toStringAsFixed(2)} €'
                    : 'Importe cofrade: ${widget.campaign.memberPrice.toStringAsFixed(2)} €'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _activeFields(String scope) {
    return widget.campaign.customFields
        .where((field) =>
            field['active'] != false &&
            field['visible'] != false &&
            '${field['scope'] ?? 'registration'}' == scope)
        .toList()
      ..sort((a, b) => ((a['order'] as num?)?.toInt() ?? 0)
          .compareTo((b['order'] as num?)?.toInt() ?? 0));
  }

  void _submit(
    BuildContext context,
    ValueChanged<_RegistrationInput> callback,
  ) {
    if (widget.campaign.menuRequired && _selectedMenu() == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un menú para continuar.')),
      );
      return;
    }
    final missing = <String>[];
    final registrationAnswers = _collectAnswers(_activeFields('registration'),
        _registrationControllers, _registrationBoolAnswers, missing);
    final participantAnswers = _collectAnswers(_activeFields('participant'),
        _participantControllers, _participantBoolAnswers, missing);
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Faltan campos obligatorios: ${missing.join(', ')}')),
      );
      return;
    }
    callback(_RegistrationInput(
      menu: _selectedMenu(),
      answers: registrationAnswers,
      participantAnswers: participantAnswers,
    ));
  }

  Map<String, dynamic>? _selectedMenu() {
    if (_menuId == null) return null;
    for (final menu in widget.campaign.menus) {
      if ('${menu['id']}' == _menuId) return Map<String, dynamic>.from(menu);
    }
    return null;
  }

  Map<String, dynamic> _collectAnswers(
    List<Map<String, dynamic>> fields,
    Map<String, TextEditingController> controllers,
    Map<String, bool> boolAnswers,
    List<String> missing,
  ) {
    final answers = <String, dynamic>{};
    for (final field in fields) {
      final key = '${field['key']}';
      final label = '${field['label'] ?? key}';
      final type = '${field['type'] ?? 'short_text'}';
      final required = field['required'] == true;
      dynamic value;
      if (type == 'boolean') {
        value = boolAnswers[key] ?? false;
      } else {
        value = controllers[key]?.text.trim() ?? '';
      }
      if (required && (value == null || value == '')) missing.add(label);
      answers[label] = value;
    }
    return answers;
  }
}

class _ActionPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _ActionPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _FieldsBlock extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> fields;
  final Map<String, TextEditingController> controllers;
  final Map<String, bool> boolAnswers;
  final void Function(String key, bool value) onBoolChanged;

  const _FieldsBlock({
    required this.title,
    required this.fields,
    required this.controllers,
    required this.boolAnswers,
    required this.onBoolChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final field in fields) ...[
            _fieldWidget(field),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _fieldWidget(Map<String, dynamic> field) {
    final key = '${field['key']}';
    final label =
        '${field['label'] ?? key}${field['required'] == true ? ' *' : ''}';
    final helpText = '${field['helpText'] ?? ''}';
    final type = '${field['type'] ?? 'short_text'}';
    if (type == 'boolean') {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: helpText.isEmpty ? null : Text(helpText),
        value: boolAnswers[key] ?? false,
        onChanged: (value) => onBoolChanged(key, value),
      );
    }
    final controller = controllers.putIfAbsent(key, TextEditingController.new);
    if (type == 'single_select') {
      final options = (field['options'] as List<dynamic>? ?? [])
          .map((option) => '$option')
          .where((option) => option.isNotEmpty)
          .toList();
      return DropdownButtonFormField<String>(
        initialValue:
            options.contains(controller.text) ? controller.text : null,
        decoration: InputDecoration(
          labelText: label,
          helperText: helpText.isEmpty ? null : helpText,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map((option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ))
            .toList(),
        onChanged: (value) => controller.text = value ?? '',
      );
    }
    final maxLines = type == 'long_text' ? 4 : 1;
    final keyboardType = type == 'number'
        ? TextInputType.number
        : type == 'date'
            ? TextInputType.datetime
            : TextInputType.text;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: type == 'multi_select'
            ? 'Separa varias opciones con comas'
            : type == 'date'
                ? 'dd/mm/aaaa'
                : null,
        helperText: helpText.isEmpty ? null : helpText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _ClosedCampaignNotice extends StatelessWidget {
  const _ClosedCampaignNotice();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.lock_clock, color: AppTheme.textSecondary),
        title: Text('La inscripción no está abierta.'),
      ),
    );
  }
}

class _EmptySpecialCard extends StatelessWidget {
  final String title;
  final String message;

  const _EmptySpecialCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return _ActionCard(
      icon: Icons.event_busy,
      title: title,
      subtitle: message,
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: action == null
            ? null
            : TextButton(onPressed: onTap, child: Text(action!)),
      ),
    );
  }
}

class _ModulePadding extends StatelessWidget {
  final Widget child;

  const _ModulePadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: child,
        ),
      ),
    );
  }
}
