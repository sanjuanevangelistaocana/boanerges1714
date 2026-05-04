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
      length: 4,
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
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        Tab(text: 'Festividad San Juan Evangelista'),
                        Tab(text: 'Eventos generales'),
                        Tab(text: 'Palmas Domingo de Ramos'),
                        Tab(text: 'Turnos de andas'),
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
                  title: 'Festividad San Juan Evangelista',
                  subtitle:
                      'Ediciones, menús, inscripciones, pagos e informe de la festividad.',
                  route: '/admin/festividad',
                ),
                _AdminEntryCard(
                  icon: Icons.event_available,
                  title: 'Eventos generales',
                  subtitle:
                      'Crear eventos públicos o privados, controlar inscritos y adjuntos.',
                  route: '/admin/events',
                ),
                _SpecialCampaignAdmin(type: 'palmas'),
                _SpecialCampaignAdmin(type: 'andas'),
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

class _SpecialCampaignAdmin extends StatelessWidget {
  final String type;

  const _SpecialCampaignAdmin({required this.type});

  bool get _isAndas => type == 'andas';

  @override
  Widget build(BuildContext context) {
    final service = context.read<EventsService>();
    return _AdminPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isAndas ? 'Turnos de andas' : 'Palmas Domingo de Ramos',
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
    final nameController = TextEditingController(
      text: campaign?.name ??
          (_isAndas
              ? 'Turnos de andas $year'
              : 'Palmas Domingo de Ramos $year'),
    );
    final descriptionController =
        TextEditingController(text: campaign?.description ?? '');
    final phoneController =
        TextEditingController(text: campaign?.contactPhone ?? '');
    final rulesController = TextEditingController(text: campaign?.rules ?? '');
    final costController =
        TextEditingController(text: (campaign?.cost ?? 0).toStringAsFixed(2));
    var selectedYear = campaign?.year ?? year;
    var active = campaign?.active ?? false;
    var published = campaign?.published ?? false;
    var startDate = campaign?.startDate ?? DateTime(selectedYear, 1, 1);
    var endDate = campaign?.endDate ?? DateTime(selectedYear, 12, 31);
    var processionDate =
        campaign?.processionDate ?? DateTime(selectedYear, 3, 30);
    var turns = List<Map<String, dynamic>>.from(campaign?.turns ??
        (_isAndas
            ? [
                {
                  'id': 'turno_1',
                  'name': 'Iglesia -> Plaza',
                  'from': 'Iglesia',
                  'to': 'Plaza'
                },
                {
                  'id': 'turno_2',
                  'name': 'Plaza -> Iglesia',
                  'from': 'Plaza',
                  'to': 'Iglesia'
                },
              ]
            : const []));

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
                            labelText: 'Coste opcional',
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
                    label: 'Inicio inscripciones',
                    date: startDate,
                    onPick: (date) => setLocalState(() => startDate = date),
                  ),
                  _DateTile(
                    label: 'Fin inscripciones',
                    date: endDate,
                    onPick: (date) => setLocalState(() => endDate = date),
                  ),
                  if (_isAndas) ...[
                    _DateTile(
                      label: 'Fecha procesión',
                      date: processionDate,
                      onPick: (date) =>
                          setLocalState(() => processionDate = date),
                    ),
                    TextField(
                      controller: phoneController,
                      decoration:
                          const InputDecoration(labelText: 'Teléfono contacto'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rulesController,
                      decoration: const InputDecoration(labelText: 'Normas'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Turnos',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    ...turns.asMap().entries.map((entry) {
                      final index = entry.key;
                      final turn = entry.value;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${turn['name'] ?? ''}'),
                        subtitle: Text(
                            '${turn['from'] ?? ''} -> ${turn['to'] ?? ''}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setLocalState(() => turns.removeAt(index)),
                        ),
                      );
                    }),
                    OutlinedButton.icon(
                      onPressed: () => setLocalState(() => turns.add({
                            'id': 'turno_${turns.length + 1}',
                            'name': 'Turno ${turns.length + 1}',
                            'from': '',
                            'to': '',
                          })),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir turno'),
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Campaña activa'),
                    value: active,
                    onChanged: (value) => setLocalState(() => active = value),
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
                  processionDate: _isAndas ? processionDate : null,
                  contactPhone: phoneController.text.trim(),
                  rules: rulesController.text.trim(),
                  cost: double.tryParse(
                          costController.text.replaceAll(',', '.')) ??
                      0,
                  active: active,
                  published: published,
                  turns: turns,
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
                          if (campaign.type == 'andas')
                            DropdownButton<String>(
                              value: reg.role,
                              items: const [
                                DropdownMenuItem(
                                    value: 'titular', child: Text('Titular')),
                                DropdownMenuItem(
                                    value: 'reserva', child: Text('Reserva')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  service.updateRegistration(
                                      reg.id, {'role': value});
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
