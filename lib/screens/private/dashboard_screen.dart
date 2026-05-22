import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/cofrade_field_config.dart';
import 'package:boanerges1714/models/cuota.dart';
import 'package:boanerges1714/models/noticia.dart';
import 'package:boanerges1714/models/evento.dart';
import 'package:boanerges1714/models/sugerencia.dart';
import 'package:boanerges1714/models/loteria.dart';
import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/models/cofradia_event.dart';
import 'package:boanerges1714/services/events_service.dart';
import 'package:boanerges1714/services/encuesta_service.dart';
import 'package:boanerges1714/services/noticias_service.dart';
import 'package:boanerges1714/models/encuesta.dart';
import 'package:boanerges1714/services/treasury/treasury_bank_validation_service.dart';
import 'package:boanerges1714/services/treasury/treasury_invoice_service.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';
import 'package:boanerges1714/models/turno_andas.dart';
import 'package:boanerges1714/services/turnos_andas_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _popupShown = false;
  bool _treasuryPopupShown = false;
  bool _eventPopupShown = false;
  bool _newsPopupShown = false;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final cofrade = authService.cofrade;

    if (!_popupShown && cofrade != null) {
      _popupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkPendingEncuestas(context, cofrade);
      });
    }
    if (!_treasuryPopupShown && authService.userId != null) {
      _treasuryPopupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkPendingBankValidation(authService.userId!);
      });
    }
    if (!_eventPopupShown && cofrade != null) {
      _eventPopupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkEventPopup(context, context.read<EventsService>(), cofrade.id);
      });
    }
    if (!_newsPopupShown && cofrade != null) {
      _newsPopupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkNewsPopup(context, firestoreService, cofrade.id);
      });
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _DashboardHeader(cofrade: cofrade, authService: authService),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (authService.hasMultipleCofrades) ...[
                    _CofradeSelectorCard(
                      cofrades: authService.cofrades,
                      selectedCofrade: cofrade,
                      onSelect: (id) => authService.selectCofrade(id),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (cofrade?.estado == 'Pendiente' ||
                      cofrade?.estado == 'pendiente')
                    _PendingBanner(),
                  _FestividadBanner(
                    firestoreService: firestoreService,
                    cofrade: cofrade,
                  ),
                  if (cofrade != null)
                    _EventCampaignBanner(
                      eventsService: context.read<EventsService>(),
                      cofradeId: cofrade.id,
                      type: 'palmas',
                    ),
                  if (cofrade != null)
                    _EventCampaignBanner(
                      eventsService: context.read<EventsService>(),
                      cofradeId: cofrade.id,
                      type: 'junta_general_ordinaria',
                    ),
                  _LoteriaBanner(firestoreService: firestoreService),
                  if (authService.userId != null)
                    _TreasuryValidationBanner(
                      authUid: authService.userId!,
                      cofradeId: cofrade?.id,
                    ),
                  if (cofrade != null)
                    _MissingRequiredFieldsBanner(
                      firestoreService: firestoreService,
                      cofrade: cofrade,
                    ),
                  if (cofrade != null)
                    _PendingMessagesBanner(
                      firestoreService: firestoreService,
                      cofradeId: cofrade.id,
                    ),
                  if (cofrade != null)
                    _DashboardEncuestaResultsBanner(cofrade: cofrade),
                  if (cofrade != null)
                    _TurnosAndasCard(cofradeId: cofrade.id),
                  if (cofrade != null)
                    _UrgentNewsBanners(cofrade: cofrade),
                  _NovedadesSection(
                      firestoreService: firestoreService,
                      cofradeId: cofrade?.id),
                  const SizedBox(height: 24),
                  _BirthdaySection(
                      firestoreService: firestoreService,
                      currentCofrade: cofrade),
                  const SizedBox(height: 24),
                  _QuickActions(
                      authService: authService,
                      firestoreService: firestoreService),
                  const SizedBox(height: 28),
                  _CofradiaStatsSection(firestoreService: firestoreService),
                  const SizedBox(height: 28),
                  if (cofrade != null)
                    _ActiveEncuestasSection(cofrade: cofrade),
                  const SizedBox(height: 28),
                  _PrivateNewsSectionV2(cofrade: cofrade),
                  const SizedBox(height: 28),
                  if (cofrade != null)
                    _CuotasResumenSection(
                        firestoreService: firestoreService, cofrade: cofrade),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkEventPopup(
    BuildContext context,
    EventsService eventsService,
    String cofradeId,
  ) async {
    final campaigns = await eventsService.watchPopupCandidates(cofradeId).first;
    if (!mounted || campaigns.isEmpty) return;
    final campaign = campaigns.first;
    final requiresAction = campaign.type == 'junta_general_ordinaria' ||
        campaign.popupConfig['repeatUntilAction'] == true ||
        const {'requiere_inscripcion', 'requiere_confirmacion', 'urgente'}
            .contains('${campaign.popupConfig['type'] ?? ''}');
    await showDialog(
      context: context,
      barrierDismissible: !requiresAction,
      builder: (ctx) => _EventLoginPopup(
        campaign: campaign,
        onDismiss: (actionTaken) async {
          await eventsService.markPopupSeen(
            campaignId: campaign.id,
            cofradeId: cofradeId,
            actionTaken: actionTaken,
          );
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _checkNewsPopup(
    BuildContext context,
    FirestoreService firestoreService,
    String cofradeId,
  ) async {
    final noticia = await firestoreService.getLatestUnreadNewsForCofrade(
      cofradeId,
    );
    if (!mounted || noticia == null) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva noticia'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((noticia.coverImageUrl ?? '').isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    noticia.coverImageUrl!,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(noticia.title,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                noticia.shortDescription.isNotEmpty
                    ? noticia.shortDescription
                    : noticia.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await firestoreService.markNewsRead(cofradeId, noticia.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Marcar como leída'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await firestoreService.markNewsRead(cofradeId, noticia.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                final route = noticia.slug.isNotEmpty
                    ? '/noticias/${noticia.slug}'
                    : '/noticias';
                context.go(route);
              }
            },
            icon: const Icon(Icons.article_outlined),
            label: const Text('Ver noticia'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPendingEncuestas(
      BuildContext context, Cofrade cofrade) async {
    try {
      final encuestaService = context.read<EncuestaService>();
      final unanswered = await encuestaService.getPendingEncuestas(cofrade);
      if (!context.mounted || unanswered.isEmpty) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.how_to_vote, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Expanded(child: Text('Encuestas pendientes')),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tienes ${unanswered.length} encuesta${unanswered.length > 1 ? 's' : ''} sin responder:',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                ...unanswered.map((enc) {
                  final dias = enc.fechaLimite != null
                      ? enc.fechaLimite!.difference(DateTime.now()).inDays
                      : 999;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.go('/encuestas?surveyId=${enc.id}');
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.pending_actions,
                                size: 18, color: Colors.orange.shade700),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(enc.titulo,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                Text(
                                  dias <= 0
                                      ? '\u00a1\u00daltimo d\u00eda!'
                                      : dias > 900
                                          ? 'Sin fecha l\u00edmite'
                                          : 'Quedan $dias d\u00edas',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: dias <= 1
                                          ? Colors.red
                                          : AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              size: 14, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('M\u00e1s tarde'),
            ),
            if (unanswered.length == 1)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/encuestas?surveyId=${unanswered.first.id}');
                },
                child: const Text('Responder ahora'),
              ),
          ],
        ),
      );
    } catch (_) {}
  }

  Future<void> _checkPendingBankValidation(String authUid) async {
    try {
      final validationService = context.read<TreasuryBankValidationService>();
      final repository = context.read<TreasuryRepository>();
      final cofradeId = context.read<AuthService>().cofrade?.id;
      final validations = await validationService
          .watchMyBankValidations(authUid, cofradeId: cofradeId)
          .first;
      final pending = validations
          .where((v) =>
              v.status == 'pending' ||
              (v.status == 'modified' && v.validatedAt == null))
          .cast<TreasuryBankValidation?>()
          .firstWhere((v) => v != null, orElse: () => null);
      if (pending == null) return;
      final settings = await repository.getSettingsByYear(pending.year);
      if (!repository.isValidationCampaignOpen(settings) || !mounted) return;
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_balance, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Expanded(child: Text('Validación bancaria pendiente')),
            ],
          ),
          content: Text(settings?.validationMessage.trim().isNotEmpty == true
              ? settings!.validationMessage.trim()
              : 'Tienes pendiente la validación de tus datos de cobro para la cuota anual.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Más tarde'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/profile?editBank=1');
              },
              child: const Text('Modificar datos'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/bank-validation');
              },
              child: const Text('Validar ahora'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error checking treasury validation popup: $e');
    }
  }
}

class _DashboardHeader extends StatelessWidget {
  final Cofrade? cofrade;
  final AuthService authService;
  const _DashboardHeader({required this.cofrade, required this.authService});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryDark,
            AppTheme.primaryColor,
            AppTheme.primaryLight
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white24,
              child: Text(
                cofrade?.nombre.isNotEmpty == true
                    ? cofrade!.nombre[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenido, ${cofrade?.nombre ?? "Cofrade"}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  if (cofrade?.numero != null)
                    Text(
                      'Cofrade N\u00ba ${cofrade!.numero}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                ],
              ),
            ),
            if (authService.isAdmin)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings,
                        size: 16, color: Colors.white70),
                    SizedBox(width: 4),
                    Text('Admin',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top, color: Colors.amber.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tu cuenta est\u00e1 pendiente de aprobaci\u00f3n por la Junta Directiva.',
              style: TextStyle(
                  color: Colors.amber.shade900, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _FestividadBanner extends StatelessWidget {
  final FirestoreService firestoreService;
  final Cofrade? cofrade;

  const _FestividadBanner({
    required this.firestoreService,
    required this.cofrade,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: firestoreService.getFestividadEdicionActivaStream(),
      builder: (context, snap) {
        final edicion = snap.data;
        if (edicion == null) return const SizedBox.shrink();
        final estado = edicion['estado'] ?? 'borrador';
        final fechaLimite = (edicion['fecha_limite'] as Timestamp?)?.toDate();
        final fechaEvento = (edicion['fecha'] as Timestamp?)?.toDate();
        if (_isAfterEventDay(fechaEvento)) return const SizedBox.shrink();
        final registrationOpen = estado == 'abierto' &&
            (fechaLimite == null || !fechaLimite.isBefore(DateTime.now()));
        if (cofrade == null && !registrationOpen) {
          return const SizedBox.shrink();
        }

        final fmt = DateFormat('dd/MM/yyyy');
        final diasRestantes = fechaLimite?.difference(DateTime.now()).inDays;

        return FutureBuilder<Map<String, dynamic>?>(
          future: cofrade == null
              ? Future.value(null)
              : firestoreService.getInscripcionFestividadParaCofrade(
                  '${edicion['id'] ?? ''}',
                  cofrade!.id,
                ),
          builder: (context, inscSnap) {
            if (cofrade != null &&
                inscSnap.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            final inscripcion = inscSnap.data;
            final hasRegistration = inscripcion != null;
            if (!hasRegistration && !registrationOpen) {
              return const SizedBox.shrink();
            }
            final ownRegistration =
                '${inscripcion?['cofrade_id'] ?? ''}' == (cofrade?.id ?? '');
            final inscriptionStatus = '${inscripcion?['estado'] ?? ''}';
            final paymentStatus =
                '${inscripcion?['payment_status'] ?? inscripcion?['estado_pago'] ?? ''}';
            final totalAmount = (inscripcion?['total'] as num?)?.toDouble();
            final paidAmount =
                (inscripcion?['paid_amount'] as num?)?.toDouble() ?? 0;
            final pendingAmount =
                (inscripcion?['pending_amount'] as num?)?.toDouble() ??
                    ((totalAmount ?? 0) - paidAmount)
                        .clamp(0, totalAmount ?? 0)
                        .toDouble();
            final title =
                edicion['nombre'] ?? 'Festividad San Juan Evangelista';
            final message = hasRegistration
                ? ownRegistration
                    ? 'Ya estás inscrito en $title'
                    : 'Formas parte de una inscripción para $title'
                : diasRestantes != null && diasRestantes <= 3
                    ? (diasRestantes <= 0
                        ? '¡Último día para inscribirse!'
                        : '¡Quedan $diasRestantes día${diasRestantes == 1 ? '' : 's'}! Inscríbete antes del ${fmt.format(fechaLimite!)}')
                    : 'Inscripciones abiertas${fechaLimite != null ? ' hasta el ${fmt.format(fechaLimite)}' : ''}';
            final cta = hasRegistration ? 'Ver mi inscripción' : 'Inscribirme';

            return _FestividadBannerBody(
              title: title,
              message: message,
              cta: cta,
              urgent: !hasRegistration &&
                  diasRestantes != null &&
                  diasRestantes <= 3,
              registrationStatus: hasRegistration ? inscriptionStatus : null,
              paymentStatus: hasRegistration ? paymentStatus : null,
              totalAmount: totalAmount,
              pendingAmount: pendingAmount,
            );
          },
        );
      },
    );
  }
}

class _EventLoginPopup extends StatelessWidget {
  final EventCampaign campaign;
  final Future<void> Function(bool actionTaken) onDismiss;

  const _EventLoginPopup({
    required this.campaign,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final popup = campaign.popupConfig;
    final title = '${popup['title'] ?? campaign.name}'.trim();
    final body = '${popup['body'] ?? campaign.description}'.trim();
    final isJunta = campaign.type == 'junta_general_ordinaria';
    final button = isJunta
        ? 'Ver evento'
        : '${popup['primaryButton'] ?? 'Ver evento'}'.trim();
    final requiresAction = isJunta ||
        popup['repeatUntilAction'] == true ||
        const {'requiere_inscripcion', 'requiere_confirmacion', 'urgente'}
            .contains('${popup['type'] ?? ''}');
    return AlertDialog(
      title: Text(title.isEmpty ? campaign.name : title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (popup['showCover'] != false &&
                campaign.coverImageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  campaign.coverImageUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              body.isEmpty ? campaign.description : body,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        if (!requiresAction)
          TextButton(
            onPressed: () => onDismiss(false),
            child: const Text('Lo he leído'),
          ),
        ElevatedButton.icon(
          onPressed: () async {
            await onDismiss(true);
            if (context.mounted) {
              context.go(EventsService.routeForCampaign(campaign));
            }
          },
          icon: const Icon(Icons.open_in_new),
          label: Text(button.isEmpty ? 'Ver evento' : button),
        ),
      ],
    );
  }
}

class _EventCampaignBanner extends StatelessWidget {
  final EventsService eventsService;
  final String cofradeId;
  final String type;

  const _EventCampaignBanner({
    required this.eventsService,
    required this.cofradeId,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventCampaign>>(
      stream: eventsService.watchVisibleCampaigns(type),
      builder: (context, campaignSnap) {
        final campaigns = (campaignSnap.data ?? const <EventCampaign>[])
            .where((campaign) =>
                !campaign.deleted &&
                campaign.status != 'archived' &&
                !_isAfterEventDay(campaign.eventDate) &&
                (campaign.isOpen || campaign.status == 'published'))
            .toList();
        if (campaigns.isEmpty) return const SizedBox.shrink();
        return StreamBuilder<List<EventRegistration>>(
          stream: eventsService.watchMyRegistrations(cofradeId),
          builder: (context, regSnap) {
            final registrations = (regSnap.data ?? const <EventRegistration>[])
                .where((reg) => reg.type == type)
                .toList();
            EventCampaign? selected;
            EventRegistration? registration;
            for (final campaign in campaigns) {
              final regs = registrations
                  .where((reg) => reg.campaignId == campaign.id)
                  .toList();
              if (regs.isNotEmpty) {
                selected = campaign;
                registration = regs.first;
                break;
              }
            }
            selected ??= campaigns.firstWhere(
              (campaign) => campaign.isOpen,
              orElse: () => campaigns.first,
            );
            if (!selected.isOpen && registration == null) {
              return const SizedBox.shrink();
            }
            final hasRegistration = registration != null;
            final title = selected.name;
            final isJunta = type == 'junta_general_ordinaria';
            final message = hasRegistration
                ? 'Ya tienes una petición registrada para $title'
                : 'Petición de Palmas abierta';
            final cta = isJunta
                ? _juntaCta(registrations)
                : hasRegistration
                    ? 'Ver mi petición'
                    : 'Solicitar palma';
            if (isJunta) {
              return StreamBuilder<List<EventRegistration>>(
                stream: eventsService.watchRegistrations(selected.id),
                builder: (context, allSnap) {
                  final allRegs = allSnap.data ?? const <EventRegistration>[];
                  return _FestividadBannerBody(
                    title: title,
                    message: _juntaMessage(selected!, registrations, allRegs),
                    cta: cta,
                    urgent: _juntaNeedsAnswer(registrations),
                    route: EventsService.routeForCampaign(selected),
                    registrationStatus: _juntaStatus(registrations),
                    extraChips: [
                      '${_juntaAttendingCount(allRegs)} asistentes confirmados',
                      '${_juntaConfirmedVotesCount(allRegs)} votos delegados confirmados',
                    ],
                  );
                },
              );
            }
            return _FestividadBannerBody(
              title: title,
              message: message,
              cta: cta,
              urgent: false,
              route: EventsService.routeForCampaign(selected),
              registrationStatus: registration?.status,
              paymentStatus: registration?.paymentStatus,
              totalAmount: registration?.totalAmount,
              pendingAmount: registration == null
                  ? null
                  : (registration.totalAmount - registration.paidAmount)
                      .clamp(0, registration.totalAmount)
                      .toDouble(),
            );
          },
        );
      },
    );
  }

  bool _juntaNeedsAnswer(List<EventRegistration> registrations) =>
      !registrations.any((reg) => reg.cofradeId == cofradeId) ||
      _juntaPendingVotes(registrations) > 0;

  String _juntaStatus(List<EventRegistration> registrations) {
    final own = registrations
        .cast<EventRegistration?>()
        .firstWhere((reg) => reg?.cofradeId == cofradeId, orElse: () => null);
    if (own == null) return 'pending';
    if (own.status == 'not_attending') {
      final delegated = registrations.expand((reg) => reg.delegatedVotes).any(
          (vote) =>
              '${vote['delegatingCofradeId'] ?? ''}' == cofradeId &&
              '${vote['status'] ?? ''}' == 'accepted');
      return delegated ? 'delegated' : 'not_attending';
    }
    return 'attending';
  }

  String _juntaCta(List<EventRegistration> registrations) {
    if (_juntaPendingVotes(registrations) > 0) return 'Responder delegación';
    final status = _juntaStatus(registrations);
    if (status == 'pending') return 'Confirmar asistencia';
    if (status == 'not_attending') return 'Delegar voto';
    return 'Ver mi asistencia';
  }

  String _juntaMessage(
    EventCampaign campaign,
    List<EventRegistration> registrations,
    List<EventRegistration> allRegistrations,
  ) {
    final status = _juntaStatus(registrations);
    final pendingVotes = _juntaPendingVotes(registrations);
    final parts = <String>[];
    if (status == 'pending') {
      parts.add('Pendiente de confirmar asistencia');
    } else if (status == 'attending') {
      if (pendingVotes > 0) {
        parts.add('$pendingVotes solicitud(es) pendiente(s)');
      }
    } else if (status == 'delegated') {
      final delegatedTo = registrations
          .expand((reg) => reg.delegatedVotes)
          .cast<Map<String, dynamic>?>()
          .firstWhere(
              (vote) =>
                  '${vote?['delegatingCofradeId'] ?? ''}' == cofradeId &&
                  '${vote?['status'] ?? ''}' == 'accepted',
              orElse: () => null);
      parts.add(
          'Voto delegado en ${delegatedTo?['delegatedToCofradeName'] ?? 'otro cofrade'}');
    } else {
      parts.add('Has indicado que no asistirás');
    }
    if (status != 'attending' && pendingVotes > 0) {
      parts.add('$pendingVotes solicitud(es) pendiente(s)');
    }
    if (campaign.location.trim().isNotEmpty) parts.add(campaign.location);
    final days = campaign.eventDate?.difference(DateTime.now()).inDays;
    if (days != null && days >= 0) {
      parts.add(days == 0 ? 'Hoy' : 'Quedan $days día(s)');
    }
    return parts.join(' · ');
  }

  int _juntaAttendingCount(List<EventRegistration> registrations) =>
      registrations
          .where((reg) =>
              reg.status == 'attending' ||
              reg.status == 'confirmed' ||
              reg.status == 'confirmada')
          .length;

  int _juntaConfirmedVotesCount(List<EventRegistration> registrations) =>
      registrations
          .expand((reg) => reg.delegatedVotes)
          .where((vote) => '${vote['status'] ?? ''}' == 'accepted')
          .length;

  int _juntaPendingVotes(List<EventRegistration> registrations) => registrations
      .expand((reg) => reg.delegatedVotes)
      .where((vote) =>
          '${vote['delegatingCofradeId'] ?? ''}' == cofradeId &&
          '${vote['status'] ?? 'requested'}' == 'requested')
      .length;
}

bool _isAfterEventDay(DateTime? eventDate) {
  if (eventDate == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
  return today.isAfter(eventDay);
}

class _FestividadBannerBody extends StatelessWidget {
  final String title;
  final String message;
  final String cta;
  final bool urgent;
  final String? registrationStatus;
  final String? paymentStatus;
  final double? totalAmount;
  final double? pendingAmount;
  final String route;
  final List<String> extraChips;

  const _FestividadBannerBody({
    required this.title,
    required this.message,
    required this.cta,
    required this.urgent,
    this.registrationStatus,
    this.paymentStatus,
    this.totalAmount,
    this.pendingAmount,
    this.route = '/festividad',
    this.extraChips = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentColor.withAlpha(20),
            AppTheme.primaryColor.withAlpha(15)
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentColor.withAlpha(80)),
      ),
      child: InkWell(
        onTap: () => context.go(route),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.celebration,
                  color: AppTheme.accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color:
                          urgent ? Colors.red.shade700 : AppTheme.accentColor,
                    ),
                  ),
                  if (registrationStatus != null || paymentStatus != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (registrationStatus != null)
                          _SmallStatusChip(
                            label:
                                'Estado inscripción: ${_statusLabel(registrationStatus!)}',
                            color: _statusColor(registrationStatus!),
                          ),
                        if (paymentStatus != null)
                          _SmallStatusChip(
                            label: _paymentText(paymentStatus!),
                            color: _paymentColor(paymentStatus!),
                          ),
                        for (final chip in extraChips)
                          _SmallStatusChip(
                            label: chip,
                            color: AppTheme.primaryColor,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Text(
              cta,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'attending':
        return 'Asistencia confirmada';
      case 'not_attending':
        return 'No asistiré';
      case 'delegated':
        return 'Voto delegado';
      case 'pending':
        return 'Pendiente de respuesta';
      case 'confirmada':
        return 'Confirmada';
      case 'cancelada':
        return 'Cancelada';
      default:
        return 'Pendiente';
    }
  }

  String _paymentLabel(String status) {
    switch (status) {
      case 'pagado':
      case 'paid':
        return 'Pagado';
      case 'partial':
      case 'parcial':
        return 'Parcial';
      case 'not_required':
      case 'exento':
        return 'No requerido';
      default:
        return 'Pendiente';
    }
  }

  String _paymentText(String status) {
    final label = _paymentLabel(status);
    if (status == 'parcial' || status == 'partial') {
      return 'Pago: $label · Pendiente: ${(pendingAmount ?? 0).toStringAsFixed(2)} €';
    }
    if (status == 'pendiente' || status.isEmpty) {
      return 'Pago: $label · Total: ${(totalAmount ?? 0).toStringAsFixed(2)} €';
    }
    return 'Pago: $label';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'attending':
      case 'delegated':
      case 'confirmada':
        return AppTheme.accentColor;
      case 'not_attending':
      case 'cancelada':
      case 'rechazada':
        return Colors.red.shade700;
      default:
        return Colors.orange.shade800;
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'pagado':
      case 'paid':
      case 'exento':
      case 'not_required':
        return AppTheme.accentColor;
      case 'devuelto':
      case 'refunded':
      case 'rechazado':
      case 'no_pagado':
        return Colors.red.shade700;
      default:
        return Colors.orange.shade800;
    }
  }
}

class _SmallStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallStatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(180),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(85)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _MissingRequiredFieldsBanner extends StatelessWidget {
  final FirestoreService firestoreService;
  final Cofrade cofrade;

  const _MissingRequiredFieldsBanner({
    required this.firestoreService,
    required this.cofrade,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CofradeFieldConfig>>(
      stream: firestoreService.getCofradeFieldsConfig(),
      builder: (context, snapshot) {
        final fields = snapshot.data ?? const <CofradeFieldConfig>[];
        if (fields.isEmpty) return const SizedBox.shrink();
        final missing =
            firestoreService.getMissingRequiredFields(cofrade, fields);
        if (missing.isEmpty) return const SizedBox.shrink();
        final labels = missing.map((field) => field.label).join(', ');
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tienes datos obligatorios pendientes de completar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => context.go('/profile'),
                child: const Text('Completar mis datos'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoteriaBanner extends StatelessWidget {
  final FirestoreService firestoreService;
  const _LoteriaBanner({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CampanaLoteria?>(
      stream: firestoreService.getCampanaActiva(),
      builder: (context, snap) {
        final campana = snap.data;
        if (campana == null || !campana.isActiva) {
          return const SizedBox.shrink();
        }
        return StreamBuilder<Map<String, dynamic>>(
          stream: firestoreService.getLoteriaCampanaStats(campana.id),
          builder: (context, statsSnap) {
            final stats = statsSnap.data ?? const {};
            final fechaFin = campana.fechaFin;
            final dias =
                fechaFin?.difference(DateTime.now()).inDays.clamp(0, 999);
            final cofradeId = context.watch<AuthService>().cofrade?.id;
            return StreamBuilder<bool>(
              stream: cofradeId == null
                  ? Stream.value(false)
                  : firestoreService.hasLoteriaAsignadaForCofrade(cofradeId),
              builder: (context, hasSnap) {
                final hasAsignaciones = hasSnap.data == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: InkWell(
                    onTap: () => context.go(hasAsignaciones
                        ? '/loteria'
                        : '/loteria-disponibilidad'),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.confirmation_number,
                              color: Colors.amber.shade800),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Campaña de Lotería activa',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(
                                dias == null
                                    ? campana.nombre
                                    : '${campana.nombre} · Quedan $dias días para finalizar',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _BannerMetric(
                                      value:
                                          '${stats['vendedores_pendientes'] ?? 0}',
                                      label: 'vendedores con décimos'),
                                  _BannerMetric(
                                      value: '${stats['disponibles'] ?? 0}',
                                      label: 'disponibles'),
                                  _BannerMetric(
                                      value: '${stats['vendidos'] ?? 0}',
                                      label: 'vendidos'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            size: 16, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _BannerMetric extends StatelessWidget {
  final String value;
  final String label;
  const _BannerMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(190),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Text('$value $label',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _TreasuryValidationBanner extends StatelessWidget {
  final String authUid;
  final String? cofradeId;

  const _TreasuryValidationBanner({required this.authUid, this.cofradeId});

  @override
  Widget build(BuildContext context) {
    final validationService = context.read<TreasuryBankValidationService>();
    final repository = context.read<TreasuryRepository>();
    return StreamBuilder<List<TreasuryBankValidation>>(
      stream: validationService.watchMyBankValidations(authUid,
          cofradeId: cofradeId),
      builder: (context, validationSnap) {
        final pending = (validationSnap.data ?? const [])
            .where((validation) =>
                validation.status == 'pending' ||
                (validation.status == 'modified' &&
                    validation.validatedAt == null))
            .toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        final validation = pending.first;
        return StreamBuilder<TreasurySettings?>(
          stream: repository.watchSettingsByYear(validation.year),
          builder: (context, settingsSnap) {
            final settings = settingsSnap.data;
            if (!repository.isValidationCampaignOpen(settings)) {
              return const SizedBox.shrink();
            }
            final message = settings?.validationMessage.trim().isNotEmpty ==
                    true
                ? settings!.validationMessage.trim()
                : 'Tienes pendiente la validación de tus datos de cobro para la cuota anual.';
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF5F1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB7D0C4)),
              ),
              child: InkWell(
                onTap: () => context.go('/bank-validation'),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F3D2E).withAlpha(22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance,
                          color: Color(0xFF0F3D2E)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Validación bancaria obligatoria',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF0F3D2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 16, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PendingMessagesBanner extends StatelessWidget {
  final FirestoreService firestoreService;
  final String cofradeId;

  const _PendingMessagesBanner({
    required this.firestoreService,
    required this.cofradeId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestoreService.watchConversations(cofradeId),
      builder: (context, snapshot) {
        final pending = (snapshot.data ?? [])
            .where((conversation) =>
                conversation['status'] == 'pending_cofrade' &&
                conversation['unreadByCofrade'] == true)
            .toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        final count = pending.length;
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                child: Text('$count'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  count == 1
                      ? 'Tienes 1 mensaje de Administración pendiente de contestar.'
                      : 'Tienes $count mensajes de Administración pendientes de contestar.',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.go('/sugerencias'),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Ver mensaje'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NovedadesSection extends StatefulWidget {
  final FirestoreService firestoreService;
  final String? cofradeId;
  const _NovedadesSection({required this.firestoreService, this.cofradeId});

  @override
  State<_NovedadesSection> createState() => _NovedadesSectionState();
}

class _NovedadesSectionState extends State<_NovedadesSection> {
  Set<String> _leidas = {};
  bool _leidasLoaded = false;
  Set<String> _respondedSurveyIds = {};

  @override
  void initState() {
    super.initState();
    _loadLeidas();
    _loadRespondedSurveys();
  }

  @override
  void didUpdateWidget(covariant _NovedadesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cofradeId != widget.cofradeId) {
      _leidas = {};
      _leidasLoaded = false;
      _respondedSurveyIds = {};
      _loadLeidas();
      _loadRespondedSurveys();
    }
  }

  Future<void> _loadRespondedSurveys() async {
    if (widget.cofradeId == null) return;
    try {
      final service = context.read<EncuestaService>();
      final activas = await service.getEncuestasActivas().first;
      final responded = <String>{};
      for (final enc in activas) {
        if (enc.estado != EncuestaEstado.activa) continue;
        final resp = await service.getMiRespuesta(enc.id, widget.cofradeId!);
        if (resp != null) responded.add(enc.id);
      }
      if (mounted) setState(() => _respondedSurveyIds = responded);
    } catch (e) {
      debugPrint('Error loading responded surveys: $e');
    }
  }

  Future<void> _loadLeidas() async {
    if (widget.cofradeId == null) {
      if (mounted) setState(() => _leidasLoaded = true);
      return;
    }
    try {
      final leidas =
          await widget.firestoreService.getNovedadesLeidas(widget.cofradeId!);
      if (mounted) {
        setState(() {
          _leidas = leidas;
          _leidasLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading novedades leidas: $e');
      if (mounted) setState(() => _leidasLoaded = true);
    }
  }

  Future<void> _marcarLeida(String id) async {
    if (widget.cofradeId == null) return;
    setState(() => _leidas.add(id));
    try {
      await widget.firestoreService.marcarNovedadLeida(widget.cofradeId!, id);
    } catch (e) {
      debugPrint('Error marking novedad as read: $e');
    }
  }

  Future<void> _marcarTodasLeidas(List<String> ids) async {
    if (widget.cofradeId == null) return;
    setState(() => _leidas.addAll(ids));
    try {
      await widget.firestoreService
          .marcarTodasNovedadesLeidas(widget.cofradeId!, ids);
    } catch (e) {
      debugPrint('Error marking all novedades as read: $e');
    }
  }

  IconData _iconForNovedadTipo(String tipo) {
    switch (tipo) {
      case 'evento':
        return Icons.event;
      case 'convocatoria':
      case 'encuesta':
        return Icons.how_to_vote;
      case 'oferta':
        return Icons.sell;
      case 'demanda':
        return Icons.shopping_bag;
      case 'proveedor':
        return Icons.store;
      case 'anuncio':
        return Icons.campaign;
      case 'festividad':
        return Icons.celebration;
      case 'loteria':
        return Icons.confirmation_number;
      case 'tesoreria':
        return Icons.account_balance;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForNovedadTipo(String tipo) {
    switch (tipo) {
      case 'evento':
        return AppTheme.accentColor;
      case 'convocatoria':
      case 'encuesta':
        return Colors.orange.shade700;
      case 'oferta':
        return Colors.green.shade700;
      case 'demanda':
        return Colors.blue.shade700;
      case 'proveedor':
        return Colors.purple.shade700;
      case 'anuncio':
        return Colors.teal.shade700;
      case 'festividad':
        return AppTheme.primaryColor;
      case 'loteria':
        return Colors.amber.shade800;
      case 'tesoreria':
        return AppTheme.primaryColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.firestoreService.getNovedades(limit: 20),
      builder: (context, novedadesSnap) {
        return StreamBuilder<List<Evento>>(
          stream: widget.firestoreService.getProximosEventos(),
          builder: (context, eventSnap) {
            return StreamBuilder<List<Encuesta>>(
              stream: context.read<EncuestaService>().getEncuestasActivas(),
              builder: (context, convoSnap) {
                return StreamBuilder<List<Noticia>>(
                  stream: widget.firestoreService
                      .getUltimasNoticias(limit: 3, incluirSoloCofrades: true),
                  builder: (context, newsSnap) {
                    return StreamBuilder<List<Sugerencia>>(
                      stream: widget.cofradeId != null
                          ? widget.firestoreService
                              .getSugerenciasRespondidas(widget.cofradeId!)
                          : const Stream.empty(),
                      builder: (context, sugSnap) {
                        final now = DateTime.now();
                        final sevenDaysAgo =
                            now.subtract(const Duration(days: 7));
                        final List<_NovedadItem> items = [];

                        // Novedades from Firestore collection (centralized system)
                        for (final nov in (novedadesSnap.data ??
                            <Map<String, dynamic>>[])) {
                          final visiblePara =
                              nov['visible_para'] as String? ?? 'todos';
                          final targetCofradeId = nov['cofrade_id'] as String?;
                          if (visiblePara == 'cofrade' &&
                              targetCofradeId != widget.cofradeId) {
                            continue;
                          }
                          final tipo = nov['tipo'] as String? ?? '';
                          final ruta = nov['ruta'] as String? ?? '/dashboard';
                          items.add(_NovedadItem(
                            id: 'nov_${nov['id']}',
                            icon: _iconForNovedadTipo(tipo),
                            color: _colorForNovedadTipo(tipo),
                            title: nov['titulo'] as String? ?? '',
                            subtitle: nov['descripcion'] as String? ?? '',
                            route: ruta,
                          ));
                        }

                        for (final e in (eventSnap.data ?? <Evento>[])) {
                          if (!e.fecha.isBefore(now)) {
                            final dias = e.fecha.difference(now).inDays;
                            items.add(_NovedadItem(
                              id: 'evento_${e.id}',
                              icon: Icons.event,
                              color: AppTheme.accentColor,
                              title: e.titulo,
                              subtitle: dias == 0
                                  ? '\u00a1Hoy!'
                                  : dias == 1
                                      ? 'Ma\u00f1ana'
                                      : 'En $dias d\u00edas \u00b7 ${DateFormat("dd/MM").format(e.fecha)}',
                              route: '/eventos',
                            ));
                          }
                        }
                        for (final enc in (convoSnap.data ?? <Encuesta>[])) {
                          if (enc.estado == EncuestaEstado.activa &&
                              !enc.isDeleted &&
                              !_respondedSurveyIds.contains(enc.id)) {
                            final dias = enc.fechaLimite != null
                                ? enc.fechaLimite!.difference(now).inDays
                                : 999;
                            items.add(_NovedadItem(
                              id: 'convo_${enc.id}',
                              icon: Icons.how_to_vote,
                              color: Colors.orange.shade700,
                              title: enc.titulo,
                              subtitle: dias <= 0
                                  ? '\u00a1\u00daltimo d\u00eda para responder!'
                                  : dias > 900
                                      ? 'Encuesta activa'
                                      : 'Quedan $dias d\u00edas para responder',
                              route: '/encuestas?surveyId=${enc.id}',
                            ));
                          }
                        }
                        for (final n in (newsSnap.data ?? <Noticia>[])) {
                          if (n.fecha.isAfter(sevenDaysAgo)) {
                            items.add(_NovedadItem(
                              id: 'noticia_${n.id}',
                              icon: Icons.article,
                              color: AppTheme.primaryColor,
                              title: n.titulo,
                              subtitle:
                                  'Nueva noticia \u00b7 ${DateFormat("dd/MM").format(n.fecha)}',
                              route: '/news',
                            ));
                          }
                        }
                        for (final s in (sugSnap.data ?? <Sugerencia>[])) {
                          items.add(_NovedadItem(
                            id: 'sug_${s.id}',
                            icon: Icons.reply,
                            color: AppTheme.accentColor,
                            title: 'Respuesta: ${s.titulo}',
                            subtitle:
                                'Tu ${s.tipo} ha sido respondida por la Junta',
                            route: '/sugerencias',
                            isPriority: true,
                          ));
                        }

                        // Sort: priority items first (sugerencia responses), then rest
                        items.sort((a, b) {
                          if (a.isPriority && !b.isPriority) return -1;
                          if (!a.isPriority && b.isPriority) return 1;
                          return 0;
                        });

                        // Filter out read items
                        final unread = items
                            .where((i) => !_leidas.contains(i.id))
                            .toList();
                        final allIds = items.map((i) => i.id).toList();

                        if (items.isEmpty) return const SizedBox.shrink();

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accentColor.withAlpha(15),
                                AppTheme.primaryColor.withAlpha(10)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.accentColor.withAlpha(40)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.notifications_active,
                                      color: AppTheme.primaryColor, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Text('Novedades',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryColor)),
                                        if (unread.isNotEmpty &&
                                            _leidasLoaded) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${unread.length}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (unread.isNotEmpty && _leidasLoaded)
                                    TextButton.icon(
                                      onPressed: () =>
                                          _marcarTodasLeidas(allIds),
                                      icon:
                                          const Icon(Icons.done_all, size: 16),
                                      label: const Text(
                                          'Marcar todo le\u00eddo',
                                          style: TextStyle(fontSize: 12)),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                ],
                              ),
                              if (unread.isEmpty && _leidasLoaded) ...[
                                const SizedBox(height: 12),
                                const Text('No tienes novedades pendientes.',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13)),
                              ],
                              if (unread.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ...unread.take(8).map((item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        onTap: () => context.go(item.route),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6, horizontal: 4),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color:
                                                      item.color.withAlpha(20),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(item.icon,
                                                    size: 20,
                                                    color: item.color),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        if (item.isPriority)
                                                          Container(
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                                    right: 6),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        1),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: AppTheme
                                                                  .accentColor
                                                                  .withAlpha(
                                                                      30),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                            ),
                                                            child: const Text(
                                                                'Respuesta',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: AppTheme
                                                                        .accentColor)),
                                                          ),
                                                        Expanded(
                                                          child: Text(
                                                              item.title,
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 14),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis),
                                                        ),
                                                      ],
                                                    ),
                                                    Text(item.subtitle,
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: item.color,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500)),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                    Icons.check_circle_outline,
                                                    size: 20,
                                                    color:
                                                        Colors.grey.shade400),
                                                tooltip:
                                                    'Marcar como le\u00eddo',
                                                onPressed: () =>
                                                    _marcarLeida(item.id),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _NovedadItem {
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String route;
  final bool isPriority;
  const _NovedadItem(
      {required this.id,
      required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.route,
      this.isPriority = false});
}

class _BirthdaySection extends StatelessWidget {
  final FirestoreService firestoreService;
  final Cofrade? currentCofrade;
  const _BirthdaySection({required this.firestoreService, this.currentCofrade});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cofrade>>(
      stream: firestoreService.getAllCofradesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final allCofrades = snapshot.data ?? [];
        if (allCofrades.isEmpty) return const SizedBox.shrink();

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final birthdayToday = <Cofrade>[];
        final birthdayThisWeek = <Cofrade>[];

        for (final c in allCofrades) {
          if (!c.isActivo || c.fechaNacimiento == null) continue;
          final bday = DateTime(
              now.year, c.fechaNacimiento!.month, c.fechaNacimiento!.day);
          final diff = bday.difference(today).inDays;
          if (diff == 0) {
            birthdayToday.add(c);
          } else if (diff > 0 && diff <= 7) {
            birthdayThisWeek.add(c);
          }
        }

        if (birthdayToday.isEmpty && birthdayThisWeek.isEmpty) {
          return const SizedBox.shrink();
        }

        final isMine = birthdayToday.any((c) => c.id == currentCofrade?.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMine)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade100, Colors.amber.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Text('\u{1F382}', style: TextStyle(fontSize: 36)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\u00a1Feliz cumplea\u00f1os, ${currentCofrade?.nombre ?? "Cofrade"}!',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'La Cofrad\u00eda de San Juan Evangelista te desea un maravilloso d\u00eda.',
                            style: TextStyle(
                                color: Colors.amber.shade800, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withAlpha(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cake, color: Colors.amber.shade700, size: 22),
                      const SizedBox(width: 8),
                      Text('Cumplea\u00f1os',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800)),
                    ],
                  ),
                  if (birthdayToday.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('\u{1F389} Hoy cumplen a\u00f1os:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900)),
                    const SizedBox(height: 8),
                    ...birthdayToday.map((c) {
                      final age = c.fechaNacimiento != null
                          ? now.year - c.fechaNacimiento!.year
                          : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: Colors.amber.withAlpha(30),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Icon(Icons.cake,
                                  size: 16, color: Colors.amber.shade700),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${c.nombreCompleto}${age != null ? " ($age a\u00f1os)" : ""}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (birthdayThisWeek.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Pr\u00f3ximos 7 d\u00edas:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade800)),
                    const SizedBox(height: 8),
                    ...birthdayThisWeek.map((c) {
                      final bday = DateTime(now.year, c.fechaNacimiento!.month,
                          c.fechaNacimiento!.day);
                      final dias = bday.difference(today).inDays;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: Colors.amber.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Icon(Icons.event,
                                  size: 16, color: Colors.amber.shade600),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${c.nombreCompleto} \u00b7 en $dias d\u00eda${dias == 1 ? "" : "s"} (${DateFormat("dd/MM").format(bday)})',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  final AuthService authService;
  final FirestoreService firestoreService;
  const _QuickActions(
      {required this.authService, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return StreamBuilder<bool>(
      stream: authService.cofrade?.id == null
          ? Stream.value(false)
          : firestoreService
              .hasLoteriaAsignadaForCofrade(authService.cofrade!.id),
      builder: (context, lotterySnap) {
        final showMiLoteria = lotterySnap.data == true;
        final userId = authService.userId;
        final validationService = context.read<TreasuryBankValidationService>();
        final repository = context.read<TreasuryRepository>();
        return StreamBuilder<List<TreasuryBankValidation>>(
          stream: userId == null
              ? Stream.value(const [])
              : validationService.watchMyBankValidations(
                  userId,
                  cofradeId: authService.cofrade?.id,
                ),
          builder: (context, validationSnap) {
            final validations = validationSnap.data ?? const [];
            final openValidation = validations
                .where((v) =>
                    v.status == 'pending' ||
                    (v.status == 'modified' && v.validatedAt == null))
                .toList();
            final firstValidation =
                openValidation.isEmpty ? null : openValidation.first;
            return StreamBuilder<TreasurySettings?>(
              stream: firstValidation == null
                  ? Stream<TreasurySettings?>.value(null)
                  : repository.watchSettingsByYear(firstValidation.year),
              builder: (context, settingsSnap) {
                final showBankValidation = firstValidation != null &&
                    repository.isValidationCampaignOpen(settingsSnap.data);
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isWide ? 4 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isWide ? 1.6 : 1.4,
                  children: [
                    _ActionCard(
                        icon: Icons.person,
                        label: 'Mi Perfil',
                        subtitle: 'Datos personales',
                        onTap: () => context.go('/profile')),
                    _ActionCard(
                        icon: Icons.payment,
                        label: 'Mis Cuotas',
                        subtitle: 'Estado de pagos',
                        onTap: () => context.go('/cuotas')),
                    if (showBankValidation)
                      _ActionCard(
                          icon: Icons.account_balance,
                          label: 'Validación bancaria',
                          subtitle: 'Confirma tus datos',
                          onTap: () => context.go('/bank-validation')),
                    if (authService.cofrade != null)
                      StreamBuilder<int>(
                        stream: context
                            .read<EventsService>()
                            .watchPendingActionCount(authService.cofrade!.id),
                        builder: (context, eventPendingSnap) => _ActionCard(
                            icon: Icons.event,
                            label: 'Eventos',
                            subtitle: 'Actividades',
                            badgeText: (eventPendingSnap.data ?? 0) > 0
                                ? '+${eventPendingSnap.data}'
                                : null,
                            onTap: () => context.go('/eventos')),
                      )
                    else
                      _ActionCard(
                          icon: Icons.event,
                          label: 'Eventos',
                          subtitle: 'Actividades',
                          onTap: () => context.go('/eventos')),
                    _ActionCard(
                        icon: Icons.how_to_vote,
                        label: 'Encuestas',
                        subtitle: 'Opiniones y preferencias',
                        onTap: () => context.go('/encuestas')),
                    _ActionCard(
                        icon: Icons.folder,
                        label: 'Documentos',
                        subtitle: 'Actas y estatutos',
                        onTap: () => context.go('/documents')),
                    _ActionCard(
                        icon: Icons.checkroom,
                        label: 'T\u00fanicas',
                        subtitle: 'Proveedores',
                        onTap: () => context.go('/tunicas')),
                    _ActionCard(
                        icon: Icons.forum_outlined,
                        label: 'Mensajería',
                        subtitle: 'Sugerencias, peticiones y respuestas',
                        onTap: () => context.go('/sugerencias')),
                    _ActionCard(
                        icon: Icons.campaign,
                        label: 'Tabl\u00f3n',
                        subtitle: 'Anuncios cofrades',
                        onTap: () => context.go('/tablon')),
                    _ActionCard(
                        icon: Icons.confirmation_number,
                        label: 'Lotería Navidad',
                        subtitle: 'Campaña activa',
                        onTap: () => context.go('/loteria-disponibilidad')),
                    if (showMiLoteria)
                      _ActionCard(
                          icon: Icons.sell,
                          label: 'Mi Lotería',
                          subtitle: 'Ventas asignadas',
                          onTap: () => context.go('/loteria')),
                    if (authService.isAdmin)
                      _ActionCard(
                          icon: Icons.admin_panel_settings,
                          label: 'Admin',
                          subtitle: 'Panel de gesti\u00f3n',
                          onTap: () => context.go('/admin'),
                          isAdmin: true),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isAdmin;
  final String? badgeText;
  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.onTap,
      this.isAdmin = false,
      this.badgeText});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: isAdmin
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.primaryColor.withAlpha(60)),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? AppTheme.primaryColor.withAlpha(20)
                          : AppTheme.accentColor.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        size: 26,
                        color: isAdmin
                            ? AppTheme.primaryColor
                            : AppTheme.accentColor),
                  ),
                  if (badgeText != null)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badgeText!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _CofradiaStatsSection extends StatelessWidget {
  final FirestoreService firestoreService;
  const _CofradiaStatsSection({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('Tu Cofrad\u00eda en Cifras',
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<Cofrade>>(
          stream: firestoreService.getAllCofradesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator())));
            }
            final allCofrades = snapshot.data ?? [];
            if (allCofrades.isEmpty) {
              return const Card(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No hay datos de cofrades disponibles.')));
            }

            final activos = allCofrades.where((c) => c.isActivo).toList();
            final bajas = allCofrades.where((c) => c.isBaja).toList();
            final edades = activos
                .where((c) => c.edad != null && c.edad! > 0)
                .map((c) => c.edad!)
                .toList();
            final mediaEdad = edades.isNotEmpty
                ? (edades.reduce((a, b) => a + b) / edades.length)
                : 0.0;
            final hombres = activos
                .where((c) =>
                    c.genero?.toUpperCase() == 'H' ||
                    c.genero?.toUpperCase() == 'HOMBRE' ||
                    c.genero?.toUpperCase() == 'MASCULINO')
                .length;
            final mujeres = activos
                .where((c) =>
                    c.genero?.toUpperCase() == 'M' ||
                    c.genero?.toUpperCase() == 'MUJER' ||
                    c.genero?.toUpperCase() == 'F' ||
                    c.genero?.toUpperCase() == 'FEMENINO')
                .length;
            final aniosList = activos
                .where((c) => c.aniosHermandad != null && c.aniosHermandad! > 0)
                .map((c) => c.aniosHermandad!)
                .toList();
            final maxAnios =
                aniosList.isNotEmpty ? aniosList.reduce(math.max) : 0;
            final gdprPapel = activos.where((c) => c.gdprFirmado).length;
            final gdprDigital =
                activos.where((c) => c.gdprFirmadoDigital).length;
            final conTunica = activos.where((c) => c.tieneTunicaPropia).length;
            final conCuota = activos.where((c) => c.tieneCuota).length;

            final ageRanges = <String, int>{
              '0-9': 0,
              '10-19': 0,
              '20-29': 0,
              '30-39': 0,
              '40-49': 0,
              '50-59': 0,
              '60-69': 0,
              '70-79': 0,
              '80-89': 0,
              '90+': 0,
            };
            for (final edad in edades) {
              if (edad <= 9) {
                ageRanges['0-9'] = ageRanges['0-9']! + 1;
              } else if (edad <= 19) {
                ageRanges['10-19'] = ageRanges['10-19']! + 1;
              } else if (edad <= 29) {
                ageRanges['20-29'] = ageRanges['20-29']! + 1;
              } else if (edad <= 39) {
                ageRanges['30-39'] = ageRanges['30-39']! + 1;
              } else if (edad <= 49) {
                ageRanges['40-49'] = ageRanges['40-49']! + 1;
              } else if (edad <= 59) {
                ageRanges['50-59'] = ageRanges['50-59']! + 1;
              } else if (edad <= 69) {
                ageRanges['60-69'] = ageRanges['60-69']! + 1;
              } else if (edad <= 79) {
                ageRanges['70-79'] = ageRanges['70-79']! + 1;
              } else if (edad <= 89) {
                ageRanges['80-89'] = ageRanges['80-89']! + 1;
              } else {
                ageRanges['90+'] = ageRanges['90+']! + 1;
              }
            }

            return Column(
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MetricTile(
                            value: '${activos.length}',
                            label: 'Activos',
                            icon: Icons.people,
                            color: AppTheme.accentColor),
                        Container(
                            width: 1, height: 60, color: Colors.grey.shade200),
                        _MetricTile(
                            value: '${allCofrades.length}',
                            label: 'Total',
                            icon: Icons.groups,
                            color: AppTheme.primaryColor),
                        Container(
                            width: 1, height: 60, color: Colors.grey.shade200),
                        _MetricTile(
                            value: mediaEdad > 0
                                ? mediaEdad.toStringAsFixed(0)
                                : '-',
                            label: 'Media edad',
                            icon: Icons.cake,
                            color: Colors.brown.shade600),
                        Container(
                            width: 1, height: 60, color: Colors.grey.shade200),
                        _MetricTile(
                            value: maxAnios > 0 ? '$maxAnios' : '-',
                            label: 'M\u00e1x. a\u00f1os',
                            icon: Icons.emoji_events,
                            color: Colors.amber.shade800),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _GenderCard(
                              hombres: hombres,
                              mujeres: mujeres,
                              total: activos.length)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _StatusCard(
                              conCuota: conCuota,
                              gdprPapel: gdprPapel,
                              gdprDigital: gdprDigital,
                              conTunica: conTunica,
                              totalActivos: activos.length,
                              totalBajas: bajas.length)),
                    ],
                  )
                else ...[
                  _GenderCard(
                      hombres: hombres,
                      mujeres: mujeres,
                      total: activos.length),
                  const SizedBox(height: 16),
                  _StatusCard(
                      conCuota: conCuota,
                      gdprPapel: gdprPapel,
                      gdprDigital: gdprDigital,
                      conTunica: conTunica,
                      totalActivos: activos.length,
                      totalBajas: bajas.length),
                ],
                const SizedBox(height: 16),
                _AgeDistCard(ageRanges: ageRanges),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _BancoTunicasKPIs(firestoreService: firestoreService),
      ],
    );
  }
}

class _BancoTunicasKPIs extends StatelessWidget {
  final FirestoreService firestoreService;
  const _BancoTunicasKPIs({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestoreService.getAllBancoTunicas(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        final ofertas = items.where((i) => i['tipo'] == 'oferta').toList();
        final demandas = items.where((i) => i['tipo'] == 'demanda').toList();
        final ofertasDisp =
            ofertas.where((i) => i['estado'] == 'disponible').length;
        final ofertasReserv =
            ofertas.where((i) => i['estado'] == 'reservada').length;
        final demandasActivas =
            demandas.where((i) => i['estado'] == 'activa').length;
        final demandasCubiertas =
            demandas.where((i) => i['estado'] == 'cubierta').length;

        final elementCount = <String, int>{};
        for (final item in ofertas.where((i) => i['estado'] == 'disponible')) {
          final elementos = List<String>.from(item['elementos'] ?? []);
          for (final e in elementos) {
            elementCount[e] = (elementCount[e] ?? 0) + 1;
          }
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: AppTheme.accentColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.volunteer_activism,
                          size: 18, color: AppTheme.accentColor),
                    ),
                    const SizedBox(width: 10),
                    const Text('Banco de T\u00fanicas',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _KpiChip(
                        value: '$ofertasDisp',
                        label: 'Disponibles',
                        color: AppTheme.accentColor),
                    _KpiChip(
                        value: '$ofertasReserv',
                        label: 'Reservadas',
                        color: Colors.orange),
                    _KpiChip(
                        value: '$demandasActivas',
                        label: 'Demandas',
                        color: Colors.blue),
                    _KpiChip(
                        value: '$demandasCubiertas',
                        label: 'Cubiertas',
                        color: Colors.grey),
                  ],
                ),
                if (elementCount.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Elementos disponibles',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: elementCount.entries
                        .map((e) => Chip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              label: Text('${e.key} (${e.value})',
                                  style: const TextStyle(fontSize: 11)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _KpiChip(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _MetricTile(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _GenderCard extends StatelessWidget {
  final int hombres;
  final int mujeres;
  final int total;
  const _GenderCard(
      {required this.hombres, required this.mujeres, required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Distribuci\u00f3n por G\u00e9nero',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              width: 120,
              child: CustomPaint(
                painter: _DonutPainter(
                    hombres: hombres,
                    mujeres: mujeres,
                    sinDato: total - hombres - mujeres),
                child: Center(
                    child: Text('$total',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary))),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Dot(color: AppTheme.primaryColor, label: 'Hombres ($hombres)'),
                const SizedBox(width: 16),
                _Dot(color: AppTheme.accentColor, label: 'Mujeres ($mujeres)'),
              ],
            ),
            if (total - hombres - mujeres > 0) ...[
              const SizedBox(height: 4),
              _Dot(
                  color: Colors.grey.shade300,
                  label: 'Sin dato (${total - hombres - mujeres})'),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final int conCuota;
  final int gdprPapel;
  final int gdprDigital;
  final int conTunica;
  final int totalActivos;
  final int totalBajas;
  const _StatusCard(
      {required this.conCuota,
      required this.gdprPapel,
      required this.gdprDigital,
      required this.conTunica,
      required this.totalActivos,
      required this.totalBajas});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estado de la Cofrad\u00eda',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            _Bar(
                label: 'Cuotas al d\u00eda',
                value: conCuota,
                total: totalActivos,
                color: AppTheme.accentColor),
            const SizedBox(height: 14),
            _Bar(
                label: 'GDPR firmado (papel)',
                value: gdprPapel,
                total: totalActivos,
                color: AppTheme.primaryColor),
            const SizedBox(height: 14),
            _Bar(
                label: 'GDPR firmado (digital)',
                value: gdprDigital,
                total: totalActivos,
                color: AppTheme.primaryLight),
            const SizedBox(height: 14),
            _Bar(
                label: 'T\u00fanica propia',
                value: conTunica,
                total: totalActivos,
                color: Colors.brown.shade600),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.person_off,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text('$totalBajas bajas registradas',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  const _Bar(
      {required this.label,
      required this.value,
      required this.total,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? value / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text('$value/$total (${(pct * 100).toStringAsFixed(0)}%)',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.shade200,
              color: color,
              minHeight: 6),
        ),
      ],
    );
  }
}

class _AgeDistCard extends StatelessWidget {
  final Map<String, int> ageRanges;
  const _AgeDistCard({required this.ageRanges});

  @override
  Widget build(BuildContext context) {
    final maxVal = ageRanges.values.fold(0, math.max);
    if (maxVal == 0) return const SizedBox.shrink();
    final colors = [
      AppTheme.accentColor,
      Colors.teal.shade400,
      AppTheme.primaryLight,
      AppTheme.primaryColor,
      AppTheme.primaryDark,
      Colors.brown.shade400,
      Colors.brown.shade600,
      Colors.brown.shade800,
      Colors.blueGrey.shade600,
      Colors.grey.shade700
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Distribuci\u00f3n por Edad',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children:
                    ageRanges.entries.toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final range = entry.value;
                  final fraction = maxVal > 0 ? range.value / maxVal : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${range.value}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colors[idx % colors.length])),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: 80 * fraction,
                            decoration: BoxDecoration(
                                color: colors[idx % colors.length],
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4))),
                          ),
                          const SizedBox(height: 4),
                          Text(range.key,
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final int hombres;
  final int mujeres;
  final int sinDato;
  _DonutPainter(
      {required this.hombres, required this.mujeres, required this.sinDato});

  @override
  void paint(Canvas canvas, Size size) {
    final total = hombres + mujeres + sinDato;
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 18.0;
    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    double startAngle = -math.pi / 2;

    if (hombres > 0) {
      final sweep = (hombres / total) * 2 * math.pi;
      paint.color = AppTheme.primaryColor;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
    if (mujeres > 0) {
      final sweep = (mujeres / total) * 2 * math.pi;
      paint.color = AppTheme.accentColor;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
    if (sinDato > 0) {
      final sweep = (sinDato / total) * 2 * math.pi;
      paint.color = Colors.grey.shade300;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.hombres != hombres ||
      oldDelegate.mujeres != mujeres ||
      oldDelegate.sinDato != sinDato;
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _ActiveEncuestasSection extends StatelessWidget {
  final Cofrade cofrade;
  const _ActiveEncuestasSection({required this.cofrade});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EncuestaService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Encuestas activas',
                    style: Theme.of(context).textTheme.headlineSmall)),
            TextButton.icon(
                onPressed: () => context.go('/encuestas'),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Ver todas')),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Encuesta>>(
          stream: service.getEncuestasParaCofrade(cofrade),
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
                    side: BorderSide(color: Colors.grey.shade200)),
                child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No hay encuestas activas.')),
              );
            }
            return Column(
              children: encuestas.take(3).map((enc) {
                final fmt = DateFormat('dd/MM/yyyy');
                final dias = enc.fechaLimite != null
                    ? enc.fechaLimite!.difference(DateTime.now()).inDays
                    : 999;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade200)),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(20),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(
                          enc.tipo == 'procesion'
                              ? Icons.church
                              : enc.tipo == 'evento'
                                  ? Icons.event
                                  : Icons.how_to_vote,
                          color: Colors.orange.shade700),
                    ),
                    title: Text(enc.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      enc.fechaLimite != null
                          ? 'L\u00edmite: ${fmt.format(enc.fechaLimite!)} \u00b7 ${enc.totalRespuestas} resp.${dias <= 3 ? " \u00b7 \u00a1$dias d\u00edas!" : ""}'
                          : '${enc.totalRespuestas} respuestas',
                      style: TextStyle(
                          fontSize: 13,
                          color: dias <= 3
                              ? Colors.orange.shade700
                              : AppTheme.textSecondary),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: AppTheme.textSecondary),
                    onTap: () =>
                        context.go('/encuestas?surveyId=${enc.id}'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// =============================================================================
// DASHBOARD ENCUESTA RESULTS BANNER (real-time)
// =============================================================================

class _DashboardEncuestaResultsBanner extends StatelessWidget {
  final Cofrade cofrade;
  const _DashboardEncuestaResultsBanner({required this.cofrade});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EncuestaService>();
    return StreamBuilder<List<Encuesta>>(
      stream: service.getEncuestasConResultadosVisibles(cofrade),
      builder: (context, snapshot) {
        final encuestas = snapshot.data ?? [];
        if (encuestas.isEmpty) return const SizedBox.shrink();
        // Show up to 3 with results
        return Column(
          children: [
            ...encuestas.take(3).map((enc) =>
                _DashboardResultCard(encuesta: enc, cofrade: cofrade)),
            if (encuestas.length > 3)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/encuestas'),
                    child: const Text('Ver todas las encuestas'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DashboardResultCard extends StatelessWidget {
  final Encuesta encuesta;
  final Cofrade cofrade;
  const _DashboardResultCard(
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

        String winnerLabel = '';
        int winnerCount = 0;
        if (encuesta.tipoRespuesta == EncuestaTipoRespuesta.reaccion) {
          for (final emoji in encuesta.reactionEmojis) {
            final cnt = counts[emoji] ?? 0;
            if (cnt > winnerCount) {
              winnerCount = cnt;
              winnerLabel = emoji;
            }
          }
        } else {
          for (final opt in encuesta.opciones) {
            final cnt = counts[opt.id] ?? 0;
            if (cnt > winnerCount) {
              winnerCount = cnt;
              winnerLabel = opt.text;
            }
          }
        }
        final winnerPct =
            total > 0 ? (winnerCount / total * 100).toStringAsFixed(0) : '0';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppTheme.primaryColor.withAlpha(80)),
          ),
          color: AppTheme.primaryColor.withAlpha(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () =>
                context.go('/encuestas?surveyId=${encuesta.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: AppTheme.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resultados en directo',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          encuesta.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$winnerLabel lidera con $winnerPct% \u00b7 $total respuestas',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---- Urgent News Banners (top of private zone) ----
class _UrgentNewsBanners extends StatelessWidget {
  final Cofrade cofrade;
  const _UrgentNewsBanners({required this.cofrade});

  @override
  Widget build(BuildContext context) {
    final service = context.read<NoticiasService>();

    return StreamBuilder<List<Noticia>>(
      stream: service.getUrgentBanners(cofrade),
      builder: (context, snapshot) {
        final urgent = (snapshot.data ?? [])
            .where((n) => !service.isBannerDismissed(n.id))
            .toList();
        if (urgent.isEmpty) return const SizedBox.shrink();

        return Column(
          children: urgent.map((n) => _UrgentBannerCard(
            noticia: n,
            onDismiss: () {
              service.dismissBanner(n.id);
              (context as Element).markNeedsBuild();
            },
          )).toList(),
        );
      },
    );
  }
}

class _UrgentBannerCard extends StatelessWidget {
  final Noticia noticia;
  final VoidCallback onDismiss;
  const _UrgentBannerCard({required this.noticia, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: InkWell(
        onTap: () {
          final route = noticia.slug.isNotEmpty
              ? '/noticias/${noticia.slug}'
              : '/noticias/detalle?id=${noticia.id}';
          context.go(route);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber, color: Colors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('URGENTE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text(noticia.category,
                            style: TextStyle(
                                fontSize: 11, color: Colors.red.shade400)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(noticia.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if (noticia.shortDescription.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(noticia.shortDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: Colors.red.shade700)),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: Icon(Icons.close, size: 18, color: Colors.red.shade300),
                tooltip: 'Cerrar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Private News Section V2 (tag-aware, using NoticiasService) ----
class _PrivateNewsSectionV2 extends StatelessWidget {
  final Cofrade? cofrade;
  const _PrivateNewsSectionV2({required this.cofrade});

  @override
  Widget build(BuildContext context) {
    final service = context.read<NoticiasService>();
    final stream = cofrade != null
        ? service.getNoticiasParaCofrade(cofrade!)
        : service.getNoticiasActivas();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('Noticias para Cofrades',
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Noticia>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            // Filter to private/segmented only
            final noticias = (snapshot.data ?? [])
                .where((n) =>
                    n.visibility == NoticiaVisibility.privada ||
                    n.visibility == NoticiaVisibility.segmentada)
                .take(5)
                .toList();
            if (noticias.isEmpty) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200)),
                child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No hay noticias privadas.')),
              );
            }
            return Column(
              children: noticias.map((n) {
                final fmt = DateFormat('dd/MM/yyyy');
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade200)),
                  child: InkWell(
                    onTap: () {
                      final route = n.slug.isNotEmpty
                          ? '/noticias/${n.slug}'
                          : '/noticias/detalle?id=${n.id}';
                      context.go(route);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          if ((n.coverImageUrl ?? '').isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                n.coverImageUrl!,
                                width: 58,
                                height: 58,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.article,
                                  color: AppTheme.primaryColor),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(n.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    if (n.requireReadConfirmation)
                                      Icon(Icons.mark_email_unread,
                                          size: 16,
                                          color: Colors.orange.shade600),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(fmt.format(n.createdAt),
                                        style: const TextStyle(fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(n.category,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.primaryColor)),
                                    ),
                                    if (n.visibility ==
                                        NoticiaVisibility.segmentada) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.people,
                                          size: 14,
                                          color: Colors.grey.shade500),
                                    ],
                                  ],
                                ),
                                if (n.attachments.isNotEmpty)
                                  Text('${n.attachments.length} adjunto(s)',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 16, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CuotasResumenSection extends StatelessWidget {
  final FirestoreService firestoreService;
  final Cofrade cofrade;
  const _CuotasResumenSection(
      {required this.firestoreService, required this.cofrade});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('Resumen de Cuotas',
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<TreasuryInvoice>>(
          stream: context
              .read<TreasuryInvoiceService>()
              .getInvoicesForCofrade(cofrade.id),
          builder: (context, invoiceSnapshot) {
            final invoices = invoiceSnapshot.data ?? const [];
            return StreamBuilder<List<Cuota>>(
              stream: firestoreService.getCuotasCofrade(cofrade.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    invoiceSnapshot.connectionState ==
                        ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final cuotas = snapshot.data ?? [];
                if (cuotas.isEmpty && invoices.isEmpty) {
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200)),
                    child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No hay cuotas registradas.')),
                  );
                }
                final pendientes = cuotas.where((c) => c.isPendiente).length;
                final pagadas = cuotas.where((c) => c.isPagada).length;
                final paidInvoices =
                    invoices.where((i) => i.status == 'paid').length;
                final pendingInvoices =
                    invoices.where((i) => i.status != 'paid').length;
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _CuotaStat(
                            label: 'Pagadas',
                            count: pagadas + paidInvoices,
                            icon: Icons.check_circle,
                            color: AppTheme.accentColor),
                        Container(
                            width: 1, height: 50, color: Colors.grey.shade200),
                        _CuotaStat(
                            label: 'Pendientes',
                            count: pendientes + pendingInvoices,
                            icon: Icons.pending,
                            color: Colors.orange.shade700),
                        Container(
                            width: 1, height: 50, color: Colors.grey.shade200),
                        _CuotaStat(
                            label: 'Total',
                            count: cuotas.length + invoices.length,
                            icon: Icons.receipt_long,
                            color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _CuotaStat extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _CuotaStat(
      {required this.label,
      required this.count,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text('$count',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _CofradeSelectorCard extends StatelessWidget {
  final List<Cofrade> cofrades;
  final Cofrade? selectedCofrade;
  final void Function(String) onSelect;
  const _CofradeSelectorCard(
      {required this.cofrades,
      required this.selectedCofrade,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.primaryColor.withAlpha(50))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people, size: 20, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text('Cofrades vinculados a tu cuenta',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 12),
            ...cofrades.map((cofrade) {
              final isSelected = cofrade.id == selectedCofrade?.id;
              final isTutelado = cofrade.tuteladoDigital != null &&
                  cofrade.tuteladoDigital!.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isSelected
                        ? const BorderSide(color: AppTheme.primaryColor)
                        : BorderSide.none,
                  ),
                  tileColor:
                      isSelected ? AppTheme.primaryColor.withAlpha(15) : null,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isSelected
                        ? AppTheme.primaryColor
                        : Colors.grey.shade300,
                    child: Text(
                        cofrade.nombre.isNotEmpty
                            ? cofrade.nombre[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  title: Text(cofrade.nombreCompleto,
                      style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  subtitle: Text(isTutelado
                      ? 'Tutelado \u00b7 N\u00ba ${cofrade.numero ?? "-"}'
                      : 'N\u00ba ${cofrade.numero ?? "-"}'),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle,
                          color: AppTheme.primaryColor)
                      : null,
                  onTap: () => onSelect(cofrade.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Turnos de Andas card for Mi Zona dashboard
// ---------------------------------------------------------------------------

class _TurnosAndasCard extends StatelessWidget {
  final String cofradeId;
  const _TurnosAndasCard({required this.cofradeId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<TurnosAndasService>();
    return StreamBuilder<TurnoAndasEvento?>(
      stream: service.watchEventoActivo(),
      builder: (context, eventoSnap) {
        final evento = eventoSnap.data;
        if (evento == null) return const SizedBox.shrink();
        return StreamBuilder<InscripcionTurno?>(
          stream: service.watchMiInscripcion(evento.id, cofradeId),
          builder: (context, inscSnap) {
            final inscripcion = inscSnap.data;
            final estadoLabel = inscripcion == null
                ? 'No inscrito'
                : _inscEstadoLabel(inscripcion.estado);
            final estadoColor = inscripcion == null
                ? AppTheme.textSecondary
                : _inscEstadoColor(inscripcion.estado);
            final ctaLabel = inscripcion == null && evento.acceptsInscriptions
                ? 'QUIERO PORTAR'
                : inscripcion == null
                    ? 'Ver detalles'
                    : 'Ver mi solicitud';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppTheme.primaryColor.withAlpha(40)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => GoRouter.of(context).go('/turnos-andas'),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withAlpha(15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.fitness_center,
                                  color: AppTheme.primaryColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(evento.titulo,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: estadoColor.withAlpha(20),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                              color: estadoColor.withAlpha(80)),
                                        ),
                                        child: Text(estadoLabel,
                                            style: TextStyle(
                                                color: estadoColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 10)),
                                      ),
                                      if (evento.fechaProcesion != null) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.calendar_today,
                                            size: 12,
                                            color: AppTheme.textSecondary),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${evento.fechaProcesion!.day}/${evento.fechaProcesion!.month}/${evento.fechaProcesion!.year}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: inscripcion == null &&
                                        evento.acceptsInscriptions
                                    ? AppTheme.accentColor
                                    : AppTheme.primaryColor.withAlpha(15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                ctaLabel,
                                style: TextStyle(
                                  color: inscripcion == null &&
                                          evento.acceptsInscriptions
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _inscEstadoLabel(String estado) {
    switch (estado) {
      case 'solicitado':
        return 'Solicitud enviada';
      case 'asignado':
        return 'Asignado';
      case 'reserva':
        return 'Reserva';
      case 'sustituto':
        return 'Sustitución';
      case 'descartado':
        return 'Descartado';
      default:
        return estado;
    }
  }

  Color _inscEstadoColor(String estado) {
    switch (estado) {
      case 'solicitado':
        return Colors.orange.shade700;
      case 'asignado':
        return AppTheme.accentColor;
      case 'reserva':
      case 'sustituto':
        return Colors.blue.shade700;
      case 'descartado':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }
}
