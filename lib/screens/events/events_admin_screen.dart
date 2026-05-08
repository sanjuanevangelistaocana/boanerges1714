import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/cofradia_event.dart';
import 'package:boanerges1714/services/events_service.dart';

class EventsAdminScreen extends StatelessWidget {
  const EventsAdminScreen({super.key});

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
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.event_note, color: Colors.white, size: 30),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Administración de Eventos',
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
                _AdminEntryCard(
                  icon: Icons.celebration,
                  title: 'Festividad 27 de diciembre',
                  subtitle:
                      'Ediciones, menús, inscripciones, pagos e informe de la festividad.',
                  route: '/admin/festividad',
                ),
                _ConfigurableCampaignAdmin(type: 'palmas'),
                _ConfigurableCampaignAdmin(type: 'sanjuandereta'),
                _ConfigurableCampaignAdmin(type: 'junta_general_ordinaria'),
                _ConfigurableCampaignAdmin(type: 'general'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminEntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _AdminEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return _AdminPadding(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(20),
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            child: Icon(icon, color: Colors.white),
          ),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: ElevatedButton(
            onPressed: () => context.go(route),
            child: const Text('Gestionar'),
          ),
        ),
      ),
    );
  }
}

class _ConfigurableCampaignAdmin extends StatelessWidget {
  final String type;

  const _ConfigurableCampaignAdmin({required this.type});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EventsService>();
    final definition = EventsService.definitionFor(type);
    return _AdminPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  definition.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCampaignDialog(context, service),
                icon: const Icon(Icons.add),
                label: const Text('Crear campaña'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<EventCampaign>>(
            stream: service.watchCampaigns(type: type),
            builder: (context, snap) {
              final campaigns = snap.data ?? const <EventCampaign>[];
              if (campaigns.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text('No hay campañas configuradas.'),
                  ),
                );
              }
              return Column(
                children: campaigns
                    .map((campaign) => _CampaignAdminCard(
                          campaign: campaign,
                          service: service,
                          onEdit: () =>
                              _showCampaignDialog(context, service, campaign),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCampaignDialog(
    BuildContext context,
    EventsService service, [
    EventCampaign? campaign,
  ]) {
    final year = DateTime.now().year;
    final definition = EventsService.definitionFor(type);
    final nameController = TextEditingController(
      text: campaign?.name ?? '${definition.title} $year',
    );
    final descriptionController = TextEditingController(
        text: campaign?.description ?? definition.description);
    final locationController =
        TextEditingController(text: campaign?.location ?? '');
    final bannerController =
        TextEditingController(text: campaign?.bannerText ?? '');
    final costController = TextEditingController(
        text: (campaign?.memberPrice ?? 0).toStringAsFixed(2));
    final guestCostController = TextEditingController(
        text: (campaign?.guestPrice ?? 0).toStringAsFixed(2));
    var selectedYear = campaign?.year ?? year;
    var active = campaign?.active ?? false;
    var published = campaign?.published ?? false;
    var status = campaign?.status ?? (active ? 'active' : 'draft');
    var startDate = campaign?.startDate ?? DateTime(selectedYear, 1, 1);
    var endDate = campaign?.endDate ?? DateTime(selectedYear, 12, 31);
    var eventDate = campaign?.eventDate ?? DateTime(selectedYear, 12, 27);
    var requiresRegistration = campaign?.requiresRegistration ?? true;
    var allowCompanions = campaign?.allowCompanions ??
        (definition.defaults['allowCompanions'] == true);
    var allowExternalGuests = campaign?.allowExternalGuests ??
        (definition.defaults['allowExternalGuests'] == true);
    var allowOtherCofrades = campaign?.allowOtherCofrades ??
        (definition.defaults['allowOtherCofrades'] == true);
    var requiresPayment = campaign?.requiresPayment ??
        (definition.defaults['requiresPayment'] == true);
    var freeEvent = campaign?.freeEvent ?? !requiresPayment;
    var showBanner = campaign?.showBanner ?? true;
    var allergiesEnabled = campaign?.allergiesEnabled ?? false;
    var observationsEnabled = campaign?.observationsEnabled ?? true;
    var waitlistEnabled = campaign?.waitlistEnabled ?? false;
    final capacityController = TextEditingController(
      text: campaign?.capacity == null ? '' : '${campaign!.capacity}',
    );
    final maxCompanionsController = TextEditingController(
      text: campaign?.maxCompanions == null ? '' : '${campaign!.maxCompanions}',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(campaign == null ? 'Crear campaña' : 'Editar campaña'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Lugar'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '$selectedYear',
                          decoration: const InputDecoration(labelText: 'Año'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null) selectedYear = parsed;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: costController,
                          decoration: const InputDecoration(
                            labelText: 'Precio cofrade',
                            suffixText: '€',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: guestCostController,
                          decoration: const InputDecoration(
                            labelText: 'Precio invitado',
                            suffixText: '€',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DateTile(
                    label: 'Fecha del evento',
                    date: eventDate,
                    onPick: (date) => setLocalState(() => eventDate = date),
                  ),
                  _DateTile(
                    label: 'Apertura inscripción',
                    date: startDate,
                    onPick: (date) => setLocalState(() => startDate = date),
                  ),
                  _DateTile(
                    label: 'Cierre inscripción',
                    date: endDate,
                    onPick: (date) => setLocalState(() => endDate = date),
                  ),
                  const Divider(height: 28),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('Borrador')),
                      DropdownMenuItem(value: 'active', child: Text('Activo')),
                      DropdownMenuItem(value: 'closed', child: Text('Cerrado')),
                      DropdownMenuItem(
                          value: 'archived', child: Text('Archivado')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setLocalState(() {
                          status = value;
                          active = value == 'active';
                        });
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Requiere inscripción/confirmación'),
                    value: requiresRegistration,
                    onChanged: (value) =>
                        setLocalState(() => requiresRegistration = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Permitir acompañantes'),
                    value: allowCompanions,
                    onChanged: (value) =>
                        setLocalState(() => allowCompanions = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Permitir invitados externos'),
                    value: allowExternalGuests,
                    onChanged: (value) =>
                        setLocalState(() => allowExternalGuests = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Permitir añadir otros cofrades'),
                    value: allowOtherCofrades,
                    onChanged: (value) =>
                        setLocalState(() => allowOtherCofrades = value),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: capacityController,
                          decoration: const InputDecoration(
                              labelText: 'Capacidad máxima'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxCompanionsController,
                          decoration: const InputDecoration(
                              labelText: 'Máx. acompañantes'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lista de espera preparada'),
                    value: waitlistEnabled,
                    onChanged: (value) =>
                        setLocalState(() => waitlistEnabled = value),
                  ),
                  const Divider(height: 28),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Evento gratuito'),
                    value: freeEvent,
                    onChanged: (value) => setLocalState(() {
                      freeEvent = value;
                      requiresPayment = !value;
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Requiere pago'),
                    value: requiresPayment,
                    onChanged: (value) => setLocalState(() {
                      requiresPayment = value;
                      freeEvent = !value;
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alergias/intolerancias'),
                    value: allergiesEnabled,
                    onChanged: (value) =>
                        setLocalState(() => allergiesEnabled = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Observaciones'),
                    value: observationsEnabled,
                    onChanged: (value) =>
                        setLocalState(() => observationsEnabled = value),
                  ),
                  const Divider(height: 28),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar banner en Novedades'),
                    value: showBanner,
                    onChanged: (value) =>
                        setLocalState(() => showBanner = value),
                  ),
                  TextField(
                    controller: bannerController,
                    decoration:
                        const InputDecoration(labelText: 'Texto del banner'),
                    maxLines: 2,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Resultados publicados'),
                    value: published,
                    onChanged: (value) =>
                        setLocalState(() => published = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await service.saveCampaign(EventCampaign(
                  id: campaign?.id ?? '',
                  type: type,
                  year: selectedYear,
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  startDate: startDate,
                  endDate: endDate,
                  eventDate: eventDate,
                  location: locationController.text.trim(),
                  cost: double.tryParse(
                          costController.text.replaceAll(',', '.')) ??
                      0,
                  active: active,
                  published: published,
                  status: status,
                  requiresRegistration: requiresRegistration,
                  allowCompanions: allowCompanions,
                  allowExternalGuests: allowExternalGuests,
                  allowOtherCofrades: allowOtherCofrades,
                  maxCompanions: int.tryParse(maxCompanionsController.text),
                  capacity: int.tryParse(capacityController.text),
                  waitlistEnabled: waitlistEnabled,
                  requiresPayment: requiresPayment,
                  freeEvent: freeEvent,
                  memberPrice: double.tryParse(
                          costController.text.replaceAll(',', '.')) ??
                      0,
                  guestPrice: double.tryParse(
                          guestCostController.text.replaceAll(',', '.')) ??
                      0,
                  allergiesEnabled: allergiesEnabled,
                  observationsEnabled: observationsEnabled,
                  showBanner: showBanner,
                  bannerText: bannerController.text.trim(),
                  registrationConfig: {
                    'requiresRegistration': requiresRegistration,
                    'allowEdit': true,
                    'allowCancel': true,
                  },
                  companionConfig: {
                    'allowCompanions': allowCompanions,
                    'allowExternalGuests': allowExternalGuests,
                    'allowOtherCofrades': allowOtherCofrades,
                    'maxCompanions': int.tryParse(maxCompanionsController.text),
                  },
                  pricingConfig: {
                    'requiresPayment': requiresPayment,
                    'freeEvent': freeEvent,
                    'memberPrice': double.tryParse(
                            costController.text.replaceAll(',', '.')) ??
                        0,
                    'guestPrice': double.tryParse(
                            guestCostController.text.replaceAll(',', '.')) ??
                        0,
                  },
                  notificationConfig: {
                    'showBanner': showBanner,
                    'bannerText': bannerController.text.trim(),
                  },
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignAdminCard extends StatelessWidget {
  final EventCampaign campaign;
  final EventsService service;
  final VoidCallback onEdit;

  const _CampaignAdminCard({
    required this.campaign,
    required this.service,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          campaign.active ? Icons.play_circle : Icons.pause_circle,
          color: campaign.active ? AppTheme.accentColor : Colors.grey,
        ),
        title: Text(campaign.name),
        subtitle: Text(
          'Año ${campaign.year} · ${campaign.active ? 'Activa' : 'Inactiva'} · ${campaign.published ? 'Publicada' : 'Sin publicar'}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onEdit,
        ),
        children: [
          StreamBuilder<List<EventRegistration>>(
            stream: service.watchRegistrations(campaign.id),
            builder: (context, snap) {
              final regs = snap.data ?? const <EventRegistration>[];
              if (regs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay inscripciones.'),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: regs.length,
                  itemBuilder: (context, index) {
                    final reg = regs[index];
                    return ListTile(
                      title: Text(reg.cofradeName),
                      subtitle: Text(
                        '${reg.status} · Añadido por ${reg.addedByName}'
                        '${reg.heightCm == null ? '' : ' · ${reg.heightCm} cm'}'
                        '${reg.turnName.isEmpty ? '' : ' · ${reg.turnName}'}',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          DropdownButton<String>(
                            value: reg.status,
                            items: const [
                              DropdownMenuItem(
                                  value: 'solicitada',
                                  child: Text('Solicitada')),
                              DropdownMenuItem(
                                  value: 'confirmada',
                                  child: Text('Confirmada')),
                              DropdownMenuItem(
                                  value: 'entregada', child: Text('Entregada')),
                              DropdownMenuItem(
                                  value: 'cancelada', child: Text('Cancelada')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                service.updateRegistration(
                                    reg.id, {'status': value});
                              }
                            },
                          ),
                          if (campaign.requiresPayment)
                            DropdownButton<String>(
                              value: reg.paymentStatus,
                              items: const [
                                DropdownMenuItem(
                                    value: 'pending',
                                    child: Text('Pago pendiente')),
                                DropdownMenuItem(
                                    value: 'paid', child: Text('Pagado')),
                                DropdownMenuItem(
                                    value: 'refunded', child: Text('Devuelto')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  service.updateRegistration(
                                      reg.id, {'paymentStatus': value});
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          if (!campaign.published)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => service.publishCampaignResults(campaign),
                  icon: const Icon(Icons.campaign),
                  label: const Text('Publicar resultados'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;

  const _DateTile({
    required this.label,
    required this.date,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text('${date.day}/${date.month}/${date.year}'),
      trailing: const Icon(Icons.calendar_today),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(date.year - 2),
          lastDate: DateTime(date.year + 3, 12, 31),
        );
        if (picked != null) onPick(picked);
      },
    );
  }
}

class _AdminPadding extends StatelessWidget {
  final Widget child;

  const _AdminPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: child,
        ),
      ),
    );
  }
}
