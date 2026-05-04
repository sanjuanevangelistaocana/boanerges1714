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
import 'package:boanerges1714/models/cuota.dart';
import 'package:boanerges1714/models/noticia.dart';
import 'package:boanerges1714/models/evento.dart';
import 'package:boanerges1714/models/convocatoria.dart';
import 'package:boanerges1714/models/sugerencia.dart';
import 'package:boanerges1714/models/loteria.dart';
import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/treasury/treasury_bank_validation_service.dart';
import 'package:boanerges1714/services/treasury/treasury_invoice_service.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _popupShown = false;
  bool _treasuryPopupShown = false;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final cofrade = authService.cofrade;

    if (!_popupShown && cofrade != null) {
      _popupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkUnansweredConvocatorias(context, firestoreService, cofrade.id);
      });
    }
    if (!_treasuryPopupShown && authService.userId != null) {
      _treasuryPopupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkPendingBankValidation(authService.userId!);
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
                  _FestividadBanner(firestoreService: firestoreService),
                  _LoteriaBanner(firestoreService: firestoreService),
                  if (authService.userId != null)
                    _TreasuryValidationBanner(
                      authUid: authService.userId!,
                      cofradeId: cofrade?.id,
                    ),
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
                  _ActiveConvocatoriasSection(
                      firestoreService: firestoreService),
                  const SizedBox(height: 28),
                  _PrivateNewsSection(firestoreService: firestoreService),
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

  Future<void> _checkUnansweredConvocatorias(BuildContext context,
      FirestoreService firestoreService, String cofradeId) async {
    try {
      final activasSnapshot =
          await firestoreService.getConvocatoriasActivas().first;
      final unanswered = <Convocatoria>[];
      for (final c in activasSnapshot) {
        if (!c.isVigente) continue;
        final resp = await firestoreService.getMiRespuesta(c.id, cofradeId);
        if (resp == null) unanswered.add(c);
      }
      if (!context.mounted) return;
      if (unanswered.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.how_to_vote, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Expanded(child: Text('Convocatorias pendientes')),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tienes ${unanswered.length} convocatoria${unanswered.length > 1 ? 's' : ''} sin responder:',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  ...unanswered.map((c) {
                    final dias =
                        c.fechaLimite.difference(DateTime.now()).inDays;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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
                                Text(c.titulo,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                Text(
                                  dias <= 0
                                      ? '\u00a1\u00daltimo d\u00eda!'
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
                        ],
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
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/convocatorias');
                },
                child: const Text('Responder ahora'),
              ),
            ],
          ),
        );
      }
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
  const _FestividadBanner({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: firestoreService.getFestividadEdicionActivaStream(),
      builder: (context, snap) {
        final edicion = snap.data;
        if (edicion == null) return const SizedBox.shrink();
        final estado = edicion['estado'] ?? 'borrador';
        if (estado != 'abierto') return const SizedBox.shrink();
        final fechaLimite = (edicion['fecha_limite'] as Timestamp?)?.toDate();
        if (fechaLimite != null && fechaLimite.isBefore(DateTime.now())) {
          return const SizedBox.shrink();
        }

        final fmt = DateFormat('dd/MM/yyyy');
        final diasRestantes = fechaLimite?.difference(DateTime.now()).inDays;

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
            onTap: () => context.go('/festividad'),
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
                        edicion['nombre'] ?? 'Festividad San Juan Evangelista',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        diasRestantes != null && diasRestantes <= 3
                            ? (diasRestantes <= 0
                                ? '\u00a1\u00daltimo d\u00eda para inscribirse!'
                                : '\u00a1Quedan $diasRestantes d\u00eda${diasRestantes == 1 ? '' : 's'}! Inscr\u00edbete antes del ${fmt.format(fechaLimite!)}')
                            : 'Inscripciones abiertas${fechaLimite != null ? ' hasta el ${fmt.format(fechaLimite)}' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: diasRestantes != null && diasRestantes <= 3
                              ? Colors.red.shade700
                              : AppTheme.accentColor,
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

  @override
  void initState() {
    super.initState();
    _loadLeidas();
  }

  @override
  void didUpdateWidget(covariant _NovedadesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cofradeId != widget.cofradeId) {
      _leidas = {};
      _leidasLoaded = false;
      _loadLeidas();
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
            return StreamBuilder<List<Convocatoria>>(
              stream: widget.firestoreService.getConvocatoriasActivas(),
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
                              route: '/events',
                            ));
                          }
                        }
                        for (final c in (convoSnap.data ?? <Convocatoria>[])) {
                          if (c.isVigente) {
                            final dias = c.fechaLimite.difference(now).inDays;
                            items.add(_NovedadItem(
                              id: 'convo_${c.id}',
                              icon: Icons.how_to_vote,
                              color: Colors.orange.shade700,
                              title: c.titulo,
                              subtitle: dias <= 0
                                  ? '\u00a1\u00daltimo d\u00eda para responder!'
                                  : 'Quedan $dias d\u00edas para responder',
                              route: '/convocatorias',
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
                    _ActionCard(
                        icon: Icons.event,
                        label: 'Eventos',
                        subtitle: 'Actividades',
                        onTap: () => context.go('/events')),
                    _ActionCard(
                        icon: Icons.how_to_vote,
                        label: 'Convocatorias',
                        subtitle: 'Consultas',
                        onTap: () => context.go('/convocatorias')),
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
                        icon: Icons.lightbulb_outline,
                        label: 'Sugerencias',
                        subtitle: 'Env\u00eda tu opini\u00f3n',
                        onTap: () => context.go('/sugerencias')),
                    _ActionCard(
                        icon: Icons.campaign,
                        label: 'Tabl\u00f3n',
                        subtitle: 'Anuncios cofrades',
                        onTap: () => context.go('/tablon')),
                    _ActionCard(
                        icon: Icons.celebration,
                        label: 'Festividad',
                        subtitle: '27 de diciembre',
                        onTap: () => context.go('/festividad')),
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
  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.onTap,
      this.isAdmin = false});

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
                    color:
                        isAdmin ? AppTheme.primaryColor : AppTheme.accentColor),
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

class _ActiveConvocatoriasSection extends StatelessWidget {
  final FirestoreService firestoreService;
  const _ActiveConvocatoriasSection({required this.firestoreService});

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
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Convocatorias Activas',
                    style: Theme.of(context).textTheme.headlineSmall)),
            TextButton.icon(
                onPressed: () => context.go('/convocatorias'),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Ver todas')),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Convocatoria>>(
          stream: firestoreService.getConvocatoriasActivas(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final convocatorias = snapshot.data ?? [];
            if (convocatorias.isEmpty) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200)),
                child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No hay convocatorias activas.')),
              );
            }
            return Column(
              children: convocatorias.take(3).map((c) {
                final fmt = DateFormat('dd/MM/yyyy');
                final dias = c.fechaLimite.difference(DateTime.now()).inDays;
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
                          c.tipo == 'procesion'
                              ? Icons.church
                              : c.tipo == 'evento'
                                  ? Icons.event
                                  : Icons.how_to_vote,
                          color: Colors.orange.shade700),
                    ),
                    title: Text(c.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'L\u00edmite: ${fmt.format(c.fechaLimite)} \u00b7 ${c.totalRespuestas} resp.${dias <= 3 ? " \u00b7 \u00a1$dias d\u00edas!" : ""}',
                      style: TextStyle(
                          fontSize: 13,
                          color: dias <= 3
                              ? Colors.orange.shade700
                              : AppTheme.textSecondary),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: AppTheme.textSecondary),
                    onTap: () => context.go('/convocatorias'),
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

class _PrivateNewsSection extends StatelessWidget {
  final FirestoreService firestoreService;
  const _PrivateNewsSection({required this.firestoreService});

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
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('Noticias para Cofrades',
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Noticia>>(
          stream: firestoreService.getNoticiasCofrades(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final noticias = snapshot.data ?? [];
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
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withAlpha(15),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.article,
                          color: AppTheme.primaryColor),
                    ),
                    title: Text(n.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(fmt.format(n.fecha),
                        style: const TextStyle(fontSize: 13)),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: AppTheme.textSecondary),
                    onTap: () => context.go('/news'),
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
