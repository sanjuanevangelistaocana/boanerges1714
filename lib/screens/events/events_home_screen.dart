import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/cofradia_event.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/events_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';

class EventsHomeScreen extends StatelessWidget {
  const EventsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: EventsService.eventTypes.length,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primaryColor],
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.event_available,
                            color: Colors.white, size: 30),
                        SizedBox(width: 12),
                        Expanded(
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
                    SizedBox(height: 16),
                    TabBar(
                      isScrollable: true,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      indicatorColor: Colors.white,
                      tabs: [
                        for (final definition in EventsService.eventTypes)
                          Tab(text: definition.title),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _FestividadEntry(),
                _ConfigurableEventPrivatePanel(type: 'palmas'),
                _ConfigurableEventPrivatePanel(type: 'sanjuandereta'),
                _ConfigurableEventPrivatePanel(type: 'junta_general_ordinaria'),
                _ConfigurableEventPrivatePanel(type: 'general'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FestividadEntry extends StatelessWidget {
  const _FestividadEntry();

  @override
  Widget build(BuildContext context) {
    return _ModulePadding(
      child: _ActionCard(
        icon: Icons.celebration,
        title: 'Festividad 27 de diciembre',
        subtitle:
            'Inscripción, acompañantes, menús y estado de tu participación.',
        action: 'Abrir Festividad',
        onTap: () => context.go('/festividad'),
      ),
    );
  }
}

class _ConfigurableEventPrivatePanel extends StatefulWidget {
  final String type;

  const _ConfigurableEventPrivatePanel({required this.type});

  @override
  State<_ConfigurableEventPrivatePanel> createState() =>
      _ConfigurableEventPrivatePanelState();
}

class _ConfigurableEventPrivatePanelState
    extends State<_ConfigurableEventPrivatePanel> {
  List<Cofrade> _cofrades = const [];
  Cofrade? _selectedCofrade;
  bool _loadingCofrades = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final current = auth.cofrade;
    final events = context.read<EventsService>();
    final definition = EventsService.definitionFor(widget.type);
    if (current == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _ModulePadding(
      child: StreamBuilder<EventCampaign?>(
        stream: events.watchActiveCampaign(widget.type),
        builder: (context, campaignSnap) {
          final campaign = campaignSnap.data;
          if (campaign == null) {
            return _EmptySpecialCard(
              title: definition.title,
              message: 'No hay campaña activa en este momento.',
            );
          }
          return StreamBuilder<List<EventRegistration>>(
            stream: events.watchMyRegistrations(current.id),
            builder: (context, regSnap) {
              final myRegs = (regSnap.data ?? const <EventRegistration>[])
                  .where((r) => r.campaignId == campaign.id)
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CampaignHeader(campaign: campaign),
                  const SizedBox(height: 16),
                  if (myRegs.isNotEmpty)
                    ...myRegs.map((r) => _RegistrationStatusCard(reg: r)),
                  const SizedBox(height: 16),
                  if (campaign.isOpen)
                    _GenericRegistrationCard(
                      campaign: campaign,
                      cofrades: _cofrades,
                      selected: _selectedCofrade,
                      loading: _loadingCofrades,
                      saving: _saving,
                      onLoadCofrades: _loadCofrades,
                      onSelected: (value) =>
                          setState(() => _selectedCofrade = value),
                      onRegisterSelf: () =>
                          _register(events, campaign, current, current),
                      onRegisterOther: _selectedCofrade == null
                          ? null
                          : () => _register(
                                events,
                                campaign,
                                _selectedCofrade!,
                                current,
                              ),
                    )
                  else
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
    EventsService events,
    EventCampaign campaign,
    Cofrade cofrade,
    Cofrade addedBy,
  ) async {
    setState(() => _saving = true);
    try {
      await events.registerCofrade(
        campaign: campaign,
        cofrade: cofrade,
        addedBy: addedBy,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${cofrade.nombreCompleto} inscrito.')),
        );
      }
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('Año ${campaign.year}')),
                Chip(
                    label: Text(
                        campaign.isOpen ? 'Inscripción abierta' : 'Cerrada')),
                if (campaign.cost > 0)
                  Chip(label: Text('${campaign.cost.toStringAsFixed(2)} €')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationStatusCard extends StatelessWidget {
  final EventRegistration reg;

  const _RegistrationStatusCard({required this.reg});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.accentColor,
          child: Icon(Icons.check, color: Colors.white),
        ),
        title: Text('Inscripción: ${reg.status}'),
        subtitle: Text(
          [
            if (reg.addedByName.isNotEmpty && reg.addedById != reg.cofradeId)
              'Añadido por ${reg.addedByName}',
            if (reg.heightCm != null) 'Altura ${reg.heightCm} cm',
            if (reg.turnName.isNotEmpty) 'Turno ${reg.turnName}',
            if (reg.role.isNotEmpty) reg.role,
            if (reg.position != null) 'Posición ${reg.position}',
          ].join(' · '),
        ),
      ),
    );
  }
}

class _GenericRegistrationCard extends StatelessWidget {
  final EventCampaign campaign;
  final List<Cofrade> cofrades;
  final Cofrade? selected;
  final bool loading;
  final bool saving;
  final VoidCallback onLoadCofrades;
  final ValueChanged<Cofrade?> onSelected;
  final VoidCallback onRegisterSelf;
  final VoidCallback? onRegisterOther;

  const _GenericRegistrationCard({
    required this.campaign,
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
  Widget build(BuildContext context) {
    final canAddOther = campaign.allowOtherCofrades;
    return _ActionPanel(
      title: campaign.requiresRegistration
          ? 'Inscripción'
          : 'Confirmación de asistencia',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: saving ? null : onRegisterSelf,
                  icon: const Icon(Icons.person_add),
                  label: Text(campaign.requiresRegistration
                      ? 'Inscribirme'
                      : 'Confirmar asistencia'),
                ),
              ),
              if (canAddOther) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: loading ? null : onLoadCofrades,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: const Text('Cargar cofrades'),
                ),
              ],
            ],
          ),
          if (canAddOther) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<Cofrade>(
              initialValue: selected,
              decoration:
                  const InputDecoration(labelText: 'Añadir otro cofrade'),
              items: cofrades
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.nombreCompleto),
                      ))
                  .toList(),
              onChanged: onSelected,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: saving ? null : onRegisterOther,
                icon: const Icon(Icons.group_add),
                label: const Text('Añadir seleccionado'),
              ),
            ),
          ],
          if (campaign.requiresPayment && campaign.memberPrice > 0) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.payments_outlined, size: 18),
                label: Text(
                    'Importe cofrade: ${campaign.memberPrice.toStringAsFixed(2)} €'),
              ),
            ),
          ],
        ],
      ),
    );
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
