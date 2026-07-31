import 'dart:convert';
import 'package:boanerges1714/widgets/responsive_dialog.dart';
import 'package:boanerges1714/widgets/responsive_data_table.dart';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/cofradia_event.dart';
import 'package:boanerges1714/services/events_service.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/storage_service.dart';

class EventsAdminScreen extends StatefulWidget {
  const EventsAdminScreen({super.key});

  @override
  State<EventsAdminScreen> createState() => _EventsAdminScreenState();
}

class _EventsAdminScreenState extends State<EventsAdminScreen> {
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final selectedType = _selectedType;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryDark, AppTheme.primaryColor],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Row(
                children: [
                  const Icon(Icons.event_note, color: Colors.white, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedType == null
                          ? 'Administración de Eventos'
                          : 'Eventos · ${EventsService.definitionFor(selectedType).title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (selectedType != null)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _selectedType = null),
                      icon: const Icon(Icons.grid_view, color: Colors.white),
                      label: const Text('Tipos de evento',
                          style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: selectedType == null
              ? _EventTypeSelectionGrid(
                  onSelect: (type) {
                    if (type == 'festividad_27_diciembre') {
                      context.go('/admin/festividad');
                    } else {
                      setState(() => _selectedType = type);
                    }
                  },
                )
              : _ConfigurableCampaignAdmin(type: selectedType),
        ),
      ],
    );
  }
}

class _EventTypeSelectionGrid extends StatelessWidget {
  final ValueChanged<String> onSelect;

  const _EventTypeSelectionGrid({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EventsService>();
    return _AdminPadding(
      child: StreamBuilder<List<EventCampaign>>(
        stream: service.watchCampaigns(),
        builder: (context, campaignSnap) {
          final campaigns = campaignSnap.data ?? const <EventCampaign>[];
          return StreamBuilder<List<EventRegistration>>(
            stream: service.watchRegistrationsByType('__all__'),
            builder: (context, regSnap) {
              final registrations = regSnap.data ?? const <EventRegistration>[];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  mainAxisExtent: 230,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: EventsService.eventTypes.length,
                itemBuilder: (context, index) {
                  final definition = EventsService.eventTypes[index];
                  final typeCampaigns = campaigns
                      .where((campaign) =>
                          campaign.type == definition.type &&
                          !campaign.deleted &&
                          campaign.status != 'archived')
                      .toList();
                  final active = typeCampaigns
                      .where((campaign) =>
                          campaign.status == 'open' || campaign.active)
                      .length;
                  final activeCampaignIds =
                      typeCampaigns.map((campaign) => campaign.id).toSet();
                  final pending = registrations
                      .where((reg) =>
                          activeCampaignIds.contains(reg.campaignId) &&
                          const {
                            'solicitada',
                            'requested',
                            'pending',
                            'pendiente'
                          }.contains(reg.status))
                      .length;
                  final next =
                      typeCampaigns.isEmpty ? null : typeCampaigns.first;
                  return _EventTypeCard(
                    icon: _iconForType(definition.type),
                    title: definition.title,
                    description: definition.description,
                    activeCount: active,
                    pendingCount: pending,
                    nextEvent: next,
                    onManage: () => onSelect(definition.type),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'festividad_27_diciembre':
        return Icons.celebration;
      case 'palmas':
        return Icons.local_florist;
      case 'sanjuandereta':
        return Icons.music_note;
      case 'junta_general_ordinaria':
        return Icons.gavel;
      default:
        return Icons.event;
    }
  }
}

class _EventTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final int activeCount;
  final int pendingCount;
  final EventCampaign? nextEvent;
  final VoidCallback onManage;

  const _EventTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.activeCount,
    required this.pendingCount,
    required this.nextEvent,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onManage,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withAlpha(18),
                    child: Icon(icon, color: AppTheme.primaryColor),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: onManage,
                    child: const Text('Gestionar'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(label: 'Activos', value: '$activeCount'),
                  if (pendingCount > 0)
                    _StatChip(label: 'Pendientes', value: '$pendingCount'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                nextEvent == null
                    ? 'Sin eventos creados'
                    : 'Próximo: ${nextEvent!.name} · ${nextEvent!.year}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigurableCampaignAdmin extends StatefulWidget {
  final String type;

  const _ConfigurableCampaignAdmin({required this.type});

  @override
  State<_ConfigurableCampaignAdmin> createState() =>
      _ConfigurableCampaignAdminState();
}

class _ConfigurableCampaignAdminState
    extends State<_ConfigurableCampaignAdmin> {
  bool _showHistorical = false;
  String _statusFilter = 'activos';
  int? _yearFilter;

  @override
  Widget build(BuildContext context) {
    final service = context.read<EventsService>();
    final type = widget.type;
    final definition = EventsService.definitionFor(type);
    final isJunta = type == 'junta_general_ordinaria';
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
                label: const Text('Crear nuevo evento'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFilterBar(),
          const SizedBox(height: 16),
          StreamBuilder<List<EventCampaign>>(
            stream: service.watchCampaigns(type: type),
            builder: (context, snap) {
              final allCampaigns = snap.data ?? const <EventCampaign>[];
              var campaigns = isJunta && !_showHistorical
                  ? allCampaigns.where(_isCurrentJuntaCampaign).toList()
                  : allCampaigns;
              campaigns = _applyFilters(campaigns);
              if (campaigns.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isJunta) _historicalSwitch(),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            Icon(Icons.event_busy,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _statusFilter != 'activos' || _yearFilter != null
                                  ? 'No hay eventos con los filtros seleccionados.'
                                  : 'No hay eventos creados a\u00fan.',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              final grouped = _groupCampaigns(campaigns);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<List<EventRegistration>>(
                    stream: service.watchRegistrationsByType(type),
                    builder: (context, regSnap) => _CampaignTypeKpis(
                      campaigns: campaigns
                          .where((campaign) =>
                              !campaign.deleted &&
                              campaign.status != 'archived')
                          .toList(),
                      registrations:
                          (regSnap.data ?? const <EventRegistration>[])
                              .where((reg) => campaigns
                                  .where((campaign) =>
                                      !campaign.deleted &&
                                      campaign.status != 'archived')
                                  .map((campaign) => campaign.id)
                                  .contains(reg.campaignId))
                              .toList(),
                    ),
                  ),
                  if (isJunta) ...[
                    const SizedBox(height: 12),
                    _historicalSwitch(),
                  ],
                  const SizedBox(height: 18),
                  ...grouped.entries
                      .where((entry) => entry.value.isNotEmpty)
                      .map((entry) => _CampaignGroup(
                            title: entry.key,
                            campaigns: entry.value,
                            service: service,
                            onEdit: (campaign) =>
                                _showCampaignDialog(context, service, campaign),
                          )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (index) => currentYear - index);
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _FilterChip(
          label: 'Activos',
          selected: _statusFilter == 'activos',
          onTap: () => setState(() => _statusFilter = 'activos'),
        ),
        _FilterChip(
          label: 'Borradores',
          selected: _statusFilter == 'borradores',
          onTap: () => setState(() => _statusFilter = 'borradores'),
        ),
        _FilterChip(
          label: 'Finalizados',
          selected: _statusFilter == 'finalizados',
          onTap: () => setState(() => _statusFilter = 'finalizados'),
        ),
        _FilterChip(
          label: 'Archivados',
          selected: _statusFilter == 'archivados',
          onTap: () => setState(() => _statusFilter = 'archivados'),
        ),
        _FilterChip(
          label: 'Todos',
          selected: _statusFilter == 'todos',
          onTap: () => setState(() => _statusFilter = 'todos'),
        ),
        const SizedBox(width: 8),
        DropdownButton<int?>(
          value: _yearFilter,
          hint: const Text('A\u00f1o'),
          underline: const SizedBox.shrink(),
          isDense: true,
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
            ...years.map((year) => DropdownMenuItem<int?>(
                  value: year,
                  child: Text('$year'),
                )),
          ],
          onChanged: (value) => setState(() => _yearFilter = value),
        ),
      ],
    );
  }

  List<EventCampaign> _applyFilters(List<EventCampaign> campaigns) {
    var filtered = campaigns.toList();
    if (_yearFilter != null) {
      filtered =
          filtered.where((campaign) => campaign.year == _yearFilter).toList();
    }
    switch (_statusFilter) {
      case 'activos':
        filtered = filtered
            .where((campaign) =>
                !campaign.deleted &&
                campaign.status != 'archived' &&
                campaign.status != 'finished')
            .toList();
        break;
      case 'borradores':
        filtered = filtered
            .where(
                (campaign) => !campaign.deleted && campaign.status == 'draft')
            .toList();
        break;
      case 'finalizados':
        filtered = filtered
            .where((campaign) =>
                !campaign.deleted &&
                (campaign.status == 'finished' || campaign.status == 'closed'))
            .toList();
        break;
      case 'archivados':
        filtered = filtered
            .where((campaign) =>
                !campaign.deleted && campaign.status == 'archived')
            .toList();
        break;
      case 'todos':
        filtered = filtered.where((campaign) => !campaign.deleted).toList();
        break;
    }
    return filtered;
  }

  Widget _historicalSwitch() {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => setState(() => _showHistorical = !_showHistorical),
        icon: Icon(_showHistorical ? Icons.visibility_off : Icons.history),
        label: Text(_showHistorical
            ? 'Ocultar hist\u00f3rico'
            : 'Mostrar hist\u00f3rico'),
      ),
    );
  }

  bool _isCurrentJuntaCampaign(EventCampaign campaign) =>
      !campaign.deleted &&
      campaign.status != 'archived' &&
      campaign.status != 'finished' &&
      campaign.status != 'closed' &&
      !campaign.isAfterEventDay;

  Map<String, List<EventCampaign>> _groupCampaigns(
    List<EventCampaign> campaigns,
  ) {
    final map = <String, List<EventCampaign>>{
      'Activos / abiertos': [],
      'Borradores': [],
      'Próximos / publicados': [],
      'Finalizados / histórico': [],
      'Archivados': [],
    };
    for (final campaign in campaigns) {
      if (campaign.status == 'archived') {
        map['Archivados']!.add(campaign);
      } else if (campaign.status == 'draft') {
        map['Borradores']!.add(campaign);
      } else if (campaign.status == 'finished' || campaign.status == 'closed') {
        map['Finalizados / histórico']!.add(campaign);
      } else if (campaign.isOpen || campaign.status == 'open') {
        map['Activos / abiertos']!.add(campaign);
      } else {
        map['Próximos / publicados']!.add(campaign);
      }
    }
    return map;
  }

  void _showCampaignDialog(
    BuildContext context,
    EventsService service, [
    EventCampaign? campaign,
  ]) {
    final year = DateTime.now().year;
    final type = widget.type;
    final definition = EventsService.definitionFor(type);
    final isPalmas = type == 'palmas';
    final isJunta = type == 'junta_general_ordinaria';
    final supportsFoodFlow = !isPalmas && !isJunta;
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
        text: (isPalmas
                ? (campaign?.palmMemberPrice ?? campaign?.memberPrice ?? 0)
                : (campaign?.memberAdultPrice ?? campaign?.memberPrice ?? 5))
            .toStringAsFixed(2));
    final memberChildPriceController = TextEditingController(
        text: (campaign?.memberChildPrice ?? 5).toStringAsFixed(2));
    final guestCostController = TextEditingController(
        text: (isPalmas
                ? (campaign?.palmExternalPrice ?? campaign?.guestPrice ?? 0)
                : (campaign?.guestAdultPrice ?? campaign?.guestPrice ?? 27))
            .toStringAsFixed(2));
    final guestChildPriceController = TextEditingController(
        text: (campaign?.guestChildPrice ?? 15).toStringAsFixed(2));
    final protocolAdultPriceController = TextEditingController(
        text: (campaign?.protocolAdultPrice ?? 0).toStringAsFixed(2));
    final protocolChildPriceController = TextEditingController(
        text: (campaign?.protocolChildPrice ?? 0).toStringAsFixed(2));
    final realAdultCostController = TextEditingController(
        text: (isPalmas
                ? (campaign?.realPalmCost ?? campaign?.realAdultMenuCost ?? 0)
                : (campaign?.realAdultMenuCost ?? 27))
            .toStringAsFixed(2));
    final realChildCostController = TextEditingController(
        text: (campaign?.realChildMenuCost ?? 15).toStringAsFixed(2));
    var selectedYear = campaign?.year ?? year;
    var active = campaign?.active ?? false;
    var published = campaign?.published ?? false;
    var status = campaign?.status == 'active'
        ? 'open'
        : (campaign?.status ?? (active ? 'open' : 'draft'));
    var eventDate = campaign?.eventDate ?? DateTime(selectedYear, 12, 27);
    var startDate =
        campaign?.startDate ?? eventDate.subtract(const Duration(days: 7));
    var endDate =
        campaign?.endDate ?? eventDate.subtract(const Duration(days: 1));
    var registrationOpenTouched = campaign?.startDate != null;
    var registrationCloseTouched = campaign?.endDate != null;
    var requiresRegistration = campaign?.requiresRegistration ?? true;
    var allowCompanions = isPalmas || isJunta
        ? false
        : campaign?.allowCompanions ??
            (definition.defaults['allowCompanions'] == true);
    var allowExternalGuests = isJunta
        ? false
        : campaign?.allowExternalGuests ??
            (definition.defaults['allowExternalGuests'] == true);
    var allowOtherCofrades = campaign?.allowOtherCofrades ??
        (definition.defaults['allowOtherCofrades'] == true);
    var requiresPayment = isJunta
        ? false
        : campaign?.requiresPayment ??
            (definition.defaults['requiresPayment'] == true);
    var freeEvent = isJunta ? true : campaign?.freeEvent ?? !requiresPayment;
    var showBanner = campaign?.showBanner ?? true;
    var menusEnabled =
        supportsFoodFlow ? campaign?.menusEnabled ?? false : false;
    var menuRequired =
        supportsFoodFlow ? campaign?.menuRequired ?? false : false;
    var menus = supportsFoodFlow
        ? List<Map<String, dynamic>>.from(campaign?.menus ?? const [])
        : <Map<String, dynamic>>[];
    var customFields = supportsFoodFlow
        ? List<Map<String, dynamic>>.from(campaign?.customFields ?? const [])
        : <Map<String, dynamic>>[];
    var allergiesEnabled =
        supportsFoodFlow ? campaign?.allergiesEnabled ?? false : false;
    var observationsEnabled =
        supportsFoodFlow ? campaign?.observationsEnabled ?? true : false;
    var waitlistEnabled = campaign?.waitlistEnabled ?? false;
    var saving = false;
    final capacityController = TextEditingController(
      text: campaign?.capacity == null ? '' : '${campaign!.capacity}',
    );
    final firstCallController = TextEditingController(
      text:
          '${campaign?.registrationConfig['firstCallTime'] ?? campaign?.registrationConfig['horaPrimeraConvocatoria'] ?? campaign?.registrationConfig['firstCall'] ?? ''}',
    );
    final secondCallController = TextEditingController(
      text:
          '${campaign?.registrationConfig['secondCallTime'] ?? campaign?.registrationConfig['horaSegundaConvocatoria'] ?? campaign?.registrationConfig['secondCall'] ?? ''}',
    );
    final maxCompanionsController = TextEditingController(
      text: campaign?.maxCompanions == null ? '' : '${campaign!.maxCompanions}',
    );
    DateTime suggestedOpen(DateTime date) => DateTime(
          date.year,
          date.month,
          date.day,
        ).subtract(const Duration(days: 7));
    DateTime suggestedClose(DateTime date) => DateTime(
          date.year,
          date.month,
          date.day,
        ).subtract(const Duration(days: 1));

    showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title:
              Text(campaign == null ? 'Crear nuevo evento' : 'Editar evento'),
          content: ResponsiveDialogBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _FormSectionTitle(
                    title: 'Datos básicos',
                    help: 'Identifica el evento y cuándo se celebra.',
                  ),
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DateTile(
                    label: 'Fecha del evento',
                    date: eventDate,
                    onPick: (date) => setLocalState(() {
                      eventDate = date;
                      selectedYear = date.year;
                      if (!registrationOpenTouched) {
                        startDate = suggestedOpen(date);
                      }
                      if (!registrationCloseTouched) {
                        endDate = suggestedClose(date);
                      }
                    }),
                  ),
                  if (isJunta) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: firstCallController,
                            decoration: const InputDecoration(
                              labelText: 'Hora primera convocatoria',
                              hintText: '20:00',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: secondCallController,
                            decoration: const InputDecoration(
                              labelText: 'Hora segunda convocatoria',
                              hintText: '20:30',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  _DateTile(
                    label: 'Apertura inscripción',
                    date: startDate,
                    onPick: (date) => setLocalState(() {
                      registrationOpenTouched = true;
                      startDate = date;
                    }),
                  ),
                  _DateTile(
                    label: 'Cierre inscripción',
                    date: endDate,
                    onPick: (date) => setLocalState(() {
                      registrationCloseTouched = true;
                      endDate = date;
                    }),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setLocalState(() {
                        startDate = suggestedOpen(eventDate);
                        endDate = suggestedClose(eventDate);
                        registrationOpenTouched = false;
                        registrationCloseTouched = false;
                      }),
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Recalcular fechas sugeridas'),
                    ),
                  ),
                  const Divider(height: 28),
                  const _FormSectionTitle(
                    title: 'Publicación',
                    help:
                        'Visible en zona privada permite que el cofrade vea el evento cuando esté publicado o abierto.',
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('Borrador')),
                      DropdownMenuItem(
                          value: 'published', child: Text('Publicado')),
                      DropdownMenuItem(value: 'open', child: Text('Abierto')),
                      DropdownMenuItem(value: 'closed', child: Text('Cerrado')),
                      DropdownMenuItem(
                          value: 'finished', child: Text('Finalizado')),
                      DropdownMenuItem(
                          value: 'archived', child: Text('Archivado')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setLocalState(() {
                          status = value;
                          active = value == 'open';
                          published = value == 'published' || value == 'open';
                        });
                      }
                    },
                  ),
                  const Divider(height: 28),
                  const _FormSectionTitle(
                    title: 'Inscripción',
                    help:
                        'Requiere inscripción activa un formulario para que los cofrades puedan apuntarse.',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Requiere inscripción/confirmación'),
                    value: requiresRegistration,
                    onChanged: (value) =>
                        setLocalState(() => requiresRegistration = value),
                  ),
                  if (supportsFoodFlow)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Permitir acompañantes'),
                      value: allowCompanions,
                      onChanged: (value) =>
                          setLocalState(() => allowCompanions = value),
                    ),
                  if (!isJunta)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(isPalmas
                          ? 'Permitir pedir palma para persona no cofrade'
                          : 'Permitir invitados externos'),
                      value: allowExternalGuests,
                      onChanged: (value) =>
                          setLocalState(() => allowExternalGuests = value),
                    ),
                  if (!isJunta)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Permitir añadir otros cofrades'),
                      value: allowOtherCofrades,
                      onChanged: (value) =>
                          setLocalState(() => allowOtherCofrades = value),
                    ),
                  if (!isJunta)
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
                        if (supportsFoodFlow)
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
                  if (!isJunta)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Lista de espera preparada'),
                      value: waitlistEnabled,
                      onChanged: (value) =>
                          setLocalState(() => waitlistEnabled = value),
                    ),
                  if (!isJunta) ...[
                    _FormSectionTitle(
                      title: 'Pagos',
                      help: isPalmas
                          ? 'Configura el precio por palma y el coste real que asume la Cofradía.'
                          : 'Precio hermano adulto es lo que paga el hermano. La diferencia con el coste real será subvención de la cofradía.',
                    ),
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
                    if (requiresPayment || !freeEvent) ...[
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Precios que paga el asistente',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: costController,
                              decoration: InputDecoration(
                                labelText: isPalmas
                                    ? 'Precio palma para cofrade'
                                    : 'Hermano adulto',
                                suffixText: '€',
                                helperText: isPalmas
                                    ? 'Importe que paga el cofrade por palma.'
                                    : 'Importe que paga el hermano adulto.',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                          ),
                          if (!isPalmas) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: memberChildPriceController,
                                decoration: const InputDecoration(
                                  labelText: 'Hermano niño',
                                  suffixText: '€',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: guestCostController,
                              decoration: InputDecoration(
                                labelText: isPalmas
                                    ? 'Precio palma persona no cofrade'
                                    : 'Invitado adulto',
                                suffixText: '€',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                          ),
                          if (!isPalmas) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: guestChildPriceController,
                                decoration: const InputDecoration(
                                  labelText: 'Invitado niño',
                                  suffixText: '€',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!isPalmas) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: protocolAdultPriceController,
                                decoration: const InputDecoration(
                                  labelText: 'Protocolo adulto',
                                  suffixText: '€',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: protocolChildPriceController,
                                decoration: const InputDecoration(
                                  labelText: 'Protocolo niño',
                                  suffixText: '€',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            isPalmas
                                ? 'Coste real para la Cofradía'
                                : 'Costes reales del restaurante',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: realAdultCostController,
                              decoration: InputDecoration(
                                labelText: isPalmas
                                    ? 'Coste real de la palma'
                                    : 'Coste real menú adulto',
                                suffixText: '€',
                                helperText: isPalmas
                                    ? 'Coste real que asume la Cofradía por cada palma.'
                                    : 'Importe que la cofradía paga al restaurante.',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                          ),
                          if (!isPalmas) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: realChildCostController,
                                decoration: const InputDecoration(
                                  labelText: 'Coste real menú niño',
                                  suffixText: '€',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                  if (supportsFoodFlow) ...[
                    const Divider(height: 28),
                    const _FormSectionTitle(
                      title: 'Menús',
                      help:
                          'Activa menús si cada participante debe elegir una opción.',
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
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Menús'),
                      subtitle: Text(menusEnabled
                          ? '${menus.length} menú(es) configurado(s)'
                          : 'Sin menús'),
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Activar menús'),
                          value: menusEnabled,
                          onChanged: (value) =>
                              setLocalState(() => menusEnabled = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title:
                              const Text('Menú obligatorio por participante'),
                          value: menuRequired,
                          onChanged: menusEnabled
                              ? (value) =>
                                  setLocalState(() => menuRequired = value)
                              : null,
                        ),
                        for (var index = 0; index < menus.length; index++)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(menus[index]['name'] ?? 'Menú'),
                            subtitle: Text(
                                '${menus[index]['type'] ?? 'adulto'} · ${(menus[index]['price'] as num? ?? 0).toStringAsFixed(2)} €'),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showMenuEditor(
                                    ctx,
                                    menu: menus[index],
                                    onSave: (updated) => setLocalState(
                                        () => menus[index] = updated),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final menuId =
                                        '${menus[index]['id'] ?? ''}';
                                    final used =
                                        campaign?.id.isNotEmpty == true &&
                                            await service.isMenuUsed(
                                                campaign!.id, menuId);
                                    setLocalState(() {
                                      if (used) {
                                        menus[index] = {
                                          ...menus[index],
                                          'active': false
                                        };
                                      } else {
                                        menus.removeAt(index);
                                      }
                                    });
                                  },
                                ),
                                Switch(
                                  value: menus[index]['active'] != false,
                                  onChanged: (value) => setLocalState(() {
                                    menus[index] = {
                                      ...menus[index],
                                      'active': value
                                    };
                                  }),
                                ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _showMenuEditor(
                              ctx,
                              menu: {
                                'id':
                                    'menu_${DateTime.now().millisecondsSinceEpoch}',
                                'name': '',
                                'description': '',
                                'type': 'adulto',
                                'price': 0,
                                'required': false,
                                'active': true,
                                'order': menus.length,
                              },
                              onSave: (created) => setLocalState(() {
                                menusEnabled = true;
                                menus = [...menus, created];
                              }),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Añadir menú'),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    const _FormSectionTitle(
                      title: 'Campos personalizados',
                      help:
                          'Crea preguntas por inscripción o por participante. Las obligatorias bloquean el envío si faltan.',
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Campos personalizados'),
                      subtitle: Text(
                          '${customFields.length} campo(s) configurado(s)'),
                      children: [
                        for (var index = 0;
                            index < customFields.length;
                            index++)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title:
                                Text(customFields[index]['label'] ?? 'Campo'),
                            subtitle: Text(
                                '${customFields[index]['scope'] ?? 'registration'} · ${customFields[index]['type'] ?? 'short_text'}'),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showFieldEditor(
                                    ctx,
                                    field: customFields[index],
                                    onSave: (updated) => setLocalState(
                                        () => customFields[index] = updated),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final key =
                                        '${customFields[index]['key'] ?? ''}';
                                    final used =
                                        campaign?.id.isNotEmpty == true &&
                                            await service.isCustomFieldUsed(
                                                campaign!.id, key);
                                    setLocalState(() {
                                      if (used) {
                                        customFields[index] = {
                                          ...customFields[index],
                                          'active': false
                                        };
                                      } else {
                                        customFields.removeAt(index);
                                      }
                                    });
                                  },
                                ),
                                Switch(
                                  value: customFields[index]['active'] != false,
                                  onChanged: (value) => setLocalState(() {
                                    customFields[index] = {
                                      ...customFields[index],
                                      'active': value
                                    };
                                  }),
                                ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _showFieldEditor(
                              ctx,
                              field: {
                                'key':
                                    'field_${DateTime.now().millisecondsSinceEpoch}',
                                'label': '',
                                'helpText': '',
                                'type': 'short_text',
                                'scope': 'registration',
                                'required': false,
                                'active': true,
                                'visible': true,
                                'order': customFields.length,
                                'options': <String>[],
                              },
                              onSave: (created) => setLocalState(() {
                                customFields = [...customFields, created];
                              }),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Añadir campo'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!isJunta) ...[
                    const Divider(height: 28),
                    const _FormSectionTitle(
                      title: 'Novedades y banner',
                      help:
                          'Mostrar en Novedades crea un aviso para los cofrades cuando el evento esté visible.',
                    ),
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
                  ],
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
              onPressed: saving
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('El nombre es obligatorio.')),
                        );
                        return;
                      }
                      if (requiresRegistration) {
                        if (!startDate.isBefore(endDate)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'La apertura de inscripción debe ser anterior al cierre.',
                              ),
                            ),
                          );
                          return;
                        }
                        if (endDate.isAfter(eventDate)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'El cierre de inscripción no puede ser posterior a la fecha del evento.',
                              ),
                            ),
                          );
                          return;
                        }
                      }
                      try {
                        setLocalState(() => saving = true);
                        final effectivePublished = status == 'published' ||
                            status == 'open' ||
                            published;
                        final effectiveActive = status == 'open' || active;
                        final parsedMemberPrice = double.tryParse(
                                costController.text.replaceAll(',', '.')) ??
                            0;
                        final parsedGuestPrice = double.tryParse(
                                guestCostController.text
                                    .replaceAll(',', '.')) ??
                            0;
                        final parsedRealAdultCost = double.tryParse(
                                realAdultCostController.text
                                    .replaceAll(',', '.')) ??
                            0;
                        final effectiveRequiresPayment =
                            isJunta ? false : requiresPayment;
                        final effectiveFreeEvent = isJunta ? true : freeEvent;
                        final effectiveAllowCompanions =
                            supportsFoodFlow && allowCompanions;
                        final effectiveAllowExternalGuests =
                            !isJunta && allowExternalGuests;
                        final effectiveMenus =
                            supportsFoodFlow ? menus : <Map<String, dynamic>>[];
                        final effectiveCustomFields = supportsFoodFlow
                            ? customFields
                            : <Map<String, dynamic>>[];
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
                          cost: isJunta
                              ? 0
                              : double.tryParse(costController.text
                                      .replaceAll(',', '.')) ??
                                  0,
                          active: effectiveActive,
                          published: effectivePublished,
                          status: status,
                          requiresRegistration: requiresRegistration,
                          allowCompanions: effectiveAllowCompanions,
                          allowExternalGuests: effectiveAllowExternalGuests,
                          allowOtherCofrades:
                              isJunta ? false : allowOtherCofrades,
                          maxCompanions: isJunta
                              ? null
                              : int.tryParse(maxCompanionsController.text),
                          capacity: isJunta
                              ? null
                              : int.tryParse(capacityController.text),
                          waitlistEnabled: isJunta ? false : waitlistEnabled,
                          requiresPayment: effectiveRequiresPayment,
                          freeEvent: effectiveFreeEvent,
                          memberPrice: isJunta ? 0 : parsedMemberPrice,
                          guestPrice: isJunta ? 0 : parsedGuestPrice,
                          childPrice: double.tryParse(memberChildPriceController
                                  .text
                                  .replaceAll(',', '.')) ??
                              0,
                          protocolPrice: double.tryParse(
                                  protocolAdultPriceController.text
                                      .replaceAll(',', '.')) ??
                              0,
                          memberAdultPrice: isJunta ? 0 : parsedMemberPrice,
                          memberChildPrice: double.tryParse(
                                  memberChildPriceController.text
                                      .replaceAll(',', '.')) ??
                              0,
                          guestAdultPrice: isJunta ? 0 : parsedGuestPrice,
                          guestChildPrice: double.tryParse(
                                  guestChildPriceController.text
                                      .replaceAll(',', '.')) ??
                              0,
                          protocolAdultPrice: double.tryParse(
                                  protocolAdultPriceController.text
                                      .replaceAll(',', '.')) ??
                              0,
                          protocolChildPrice: double.tryParse(
                                  protocolChildPriceController.text
                                      .replaceAll(',', '.')) ??
                              0,
                          realAdultMenuCost: isJunta ? 0 : parsedRealAdultCost,
                          realChildMenuCost: double.tryParse(
                                  realChildCostController.text
                                      .replaceAll(',', '.')) ??
                              0,
                          palmMemberPrice: isJunta ? 0 : parsedMemberPrice,
                          palmExternalPrice: isJunta ? 0 : parsedGuestPrice,
                          realPalmCost: isJunta ? 0 : parsedRealAdultCost,
                          allergiesEnabled:
                              supportsFoodFlow && allergiesEnabled,
                          observationsEnabled:
                              supportsFoodFlow && observationsEnabled,
                          showBanner: isJunta ? false : showBanner,
                          bannerText:
                              isJunta ? '' : bannerController.text.trim(),
                          menusEnabled: supportsFoodFlow && menusEnabled,
                          menuRequired: supportsFoodFlow && menuRequired,
                          menus: effectiveMenus,
                          customFields: effectiveCustomFields,
                          registrationConfig: {
                            'requiresRegistration': requiresRegistration,
                            'allowEdit': true,
                            'allowCancel': true,
                            if (isJunta) ...{
                              'firstCallTime': firstCallController.text.trim(),
                              'secondCallTime':
                                  secondCallController.text.trim(),
                            },
                          },
                          companionConfig: {
                            'allowCompanions': effectiveAllowCompanions,
                            'allowExternalGuests': effectiveAllowExternalGuests,
                            'allowOtherCofrades':
                                isJunta ? false : allowOtherCofrades,
                            'maxCompanions': isJunta
                                ? null
                                : int.tryParse(maxCompanionsController.text),
                          },
                          pricingConfig: {
                            'requiresPayment': effectiveRequiresPayment,
                            'freeEvent': effectiveFreeEvent,
                            'memberPrice': parsedMemberPrice,
                            'guestPrice': parsedGuestPrice,
                            'memberAdultPrice': parsedMemberPrice,
                            'memberChildPrice': double.tryParse(
                                    memberChildPriceController.text
                                        .replaceAll(',', '.')) ??
                                0,
                            'guestAdultPrice': parsedGuestPrice,
                            'guestChildPrice': double.tryParse(
                                    guestChildPriceController.text
                                        .replaceAll(',', '.')) ??
                                0,
                            'protocolAdultPrice': double.tryParse(
                                    protocolAdultPriceController.text
                                        .replaceAll(',', '.')) ??
                                0,
                            'protocolChildPrice': double.tryParse(
                                    protocolChildPriceController.text
                                        .replaceAll(',', '.')) ??
                                0,
                            'realAdultMenuCost': parsedRealAdultCost,
                            'realChildMenuCost': double.tryParse(
                                    realChildCostController.text
                                        .replaceAll(',', '.')) ??
                                0,
                            'palmMemberPrice': parsedMemberPrice,
                            'palmExternalPrice': parsedGuestPrice,
                            'realPalmCost': parsedRealAdultCost,
                          },
                          notificationConfig: {
                            'showBanner': isJunta ? false : showBanner,
                            'bannerText':
                                isJunta ? '' : bannerController.text.trim(),
                            if (isJunta) 'automaticJuntaNotices': true,
                          },
                        ));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Evento creado correctamente.')),
                          );
                        }
                      } catch (e) {
                        debugPrint('[EventsAdmin] save campaign failed: $e');
                        if (ctx.mounted) setLocalState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'No se pudo guardar el evento: ${e.toString().replaceFirst('Exception: ', '')}'),
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenuEditor(
    BuildContext context, {
    required Map<String, dynamic> menu,
    required ValueChanged<Map<String, dynamic>> onSave,
  }) {
    final nameCtrl = TextEditingController(text: '${menu['name'] ?? ''}');
    final descriptionCtrl =
        TextEditingController(text: '${menu['description'] ?? ''}');
    final priceCtrl = TextEditingController(
      text: ((menu['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
    );
    final orderCtrl =
        TextEditingController(text: '${(menu['order'] as num?)?.toInt() ?? 0}');
    var type = '${menu['type'] ?? 'adulto'}';
    var required = menu['required'] == true;
    var active = menu['active'] != false;
    showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Menú del evento'),
          content: ResponsiveDialogBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'adulto', child: Text('Adulto')),
                    DropdownMenuItem(
                        value: 'infantil', child: Text('Infantil')),
                    DropdownMenuItem(
                        value: 'protocolo', child: Text('Protocolo')),
                    DropdownMenuItem(value: 'otro', child: Text('Otro')),
                  ],
                  onChanged: (value) =>
                      setLocalState(() => type = value ?? 'adulto'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Precio', suffixText: '€'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: orderCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Orden'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Obligatorio'),
                  value: required,
                  onChanged: (value) => setLocalState(() => required = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: active,
                  onChanged: (value) => setLocalState(() => active = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                onSave({
                  ...menu,
                  'name': nameCtrl.text.trim().isEmpty
                      ? 'Menú'
                      : nameCtrl.text.trim(),
                  'description': descriptionCtrl.text.trim(),
                  'type': type,
                  'price':
                      double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0,
                  'required': required,
                  'active': active,
                  'order': int.tryParse(orderCtrl.text) ?? 0,
                });
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFieldEditor(
    BuildContext context, {
    required Map<String, dynamic> field,
    required ValueChanged<Map<String, dynamic>> onSave,
  }) {
    final labelCtrl = TextEditingController(text: '${field['label'] ?? ''}');
    final helpCtrl = TextEditingController(text: '${field['helpText'] ?? ''}');
    final optionsCtrl = TextEditingController(
      text: ((field['options'] as List<dynamic>? ?? []).join('\n')),
    );
    final orderCtrl = TextEditingController(
        text: '${(field['order'] as num?)?.toInt() ?? 0}');
    var type = '${field['type'] ?? 'short_text'}';
    var scope = '${field['scope'] ?? 'registration'}';
    var required = field['required'] == true;
    var active = field['active'] != false;
    var visible = field['visible'] != false;
    showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Campo personalizado'),
          content: ResponsiveDialogBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(labelText: 'Etiqueta'),
                  ),
                  TextField(
                    controller: helpCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Texto de ayuda'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: scope,
                    decoration: const InputDecoration(labelText: 'Ámbito'),
                    items: const [
                      DropdownMenuItem(
                          value: 'registration',
                          child: Text('Por inscripción')),
                      DropdownMenuItem(
                          value: 'participant',
                          child: Text('Por participante')),
                    ],
                    onChanged: (value) =>
                        setLocalState(() => scope = value ?? 'registration'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(
                          value: 'short_text', child: Text('Texto corto')),
                      DropdownMenuItem(
                          value: 'long_text', child: Text('Texto largo')),
                      DropdownMenuItem(value: 'number', child: Text('Número')),
                      DropdownMenuItem(value: 'boolean', child: Text('Sí/No')),
                      DropdownMenuItem(
                          value: 'single_select',
                          child: Text('Selector único')),
                      DropdownMenuItem(
                          value: 'multi_select',
                          child: Text('Selector múltiple')),
                      DropdownMenuItem(value: 'date', child: Text('Fecha')),
                    ],
                    onChanged: (value) =>
                        setLocalState(() => type = value ?? 'short_text'),
                  ),
                  if (type == 'single_select' || type == 'multi_select')
                    TextField(
                      controller: optionsCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Opciones (una por línea)',
                      ),
                    ),
                  TextField(
                    controller: orderCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Orden'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Obligatorio'),
                    value: required,
                    onChanged: (value) => setLocalState(() => required = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Visible'),
                    value: visible,
                    onChanged: (value) => setLocalState(() => visible = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activo'),
                    value: active,
                    onChanged: (value) => setLocalState(() => active = value),
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
              onPressed: () {
                final label = labelCtrl.text.trim().isEmpty
                    ? 'Pregunta'
                    : labelCtrl.text.trim();
                onSave({
                  ...field,
                  'label': label,
                  'helpText': helpCtrl.text.trim(),
                  'type': type,
                  'scope': scope,
                  'required': required,
                  'active': active,
                  'visible': visible,
                  'order': int.tryParse(orderCtrl.text) ?? 0,
                  'options': optionsCtrl.text
                      .split('\n')
                      .map((line) => line.trim())
                      .where((line) => line.isNotEmpty)
                      .toList(),
                });
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignTypeKpis extends StatelessWidget {
  final List<EventCampaign> campaigns;
  final List<EventRegistration> registrations;

  const _CampaignTypeKpis({
    required this.campaigns,
    required this.registrations,
  });

  @override
  Widget build(BuildContext context) {
    final open =
        campaigns.where((campaign) => campaign.status == 'open').length;
    final drafts =
        campaigns.where((campaign) => campaign.status == 'draft').length;
    final participants = registrations.fold<int>(
      0,
      (total, reg) =>
          total + (reg.participants.isEmpty ? 1 : reg.participants.length),
    );
    final pendingPayments = registrations
        .where((reg) =>
            reg.paymentStatus == 'pending' || reg.paymentStatus == 'partial')
        .length;
    final isPalmas = campaigns.isNotEmpty &&
        campaigns.every((campaign) => campaign.type == 'palmas');
    final isJunta = campaigns.isNotEmpty &&
        campaigns
            .every((campaign) => campaign.type == 'junta_general_ordinaria');

    // Palmas-specific status KPIs
    final palmasPending = isPalmas
        ? registrations
            .where((reg) => const {
                  'solicitada',
                  'requested',
                  'pending',
                  'pendiente'
                }.contains(reg.status))
            .length
        : 0;
    final palmasConfirmed = isPalmas
        ? registrations.where((reg) => reg.status == 'confirmada').length
        : 0;
    final palmasRejected = isPalmas
        ? registrations.where((reg) => reg.status == 'rechazada').length
        : 0;
    final palmasDelivered = isPalmas
        ? registrations.where((reg) => reg.status == 'entregada').length
        : 0;

    // Sanjuandereta / general payment KPIs
    final paidCount =
        registrations.where((reg) => reg.paymentStatus == 'paid').length;
    final companionCount = registrations.fold<int>(
        0,
        (total, reg) =>
            total +
            (reg.participants.length > 1 ? reg.participants.length - 1 : 0));

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _AdminKpi(label: 'Eventos', value: '${campaigns.length}'),
        _AdminKpi(label: 'Abiertos', value: '$open'),
        _AdminKpi(label: 'Borradores', value: '$drafts'),
        _AdminKpi(
          label: isPalmas ? 'Solicitudes' : 'Inscripciones',
          value: '${registrations.length}',
        ),
        _AdminKpi(label: 'Participantes', value: '$participants'),
        if (isPalmas) ...[
          _AdminKpi(label: 'Pendientes', value: '$palmasPending'),
          _AdminKpi(label: 'Confirmadas', value: '$palmasConfirmed'),
          _AdminKpi(label: 'Rechazadas', value: '$palmasRejected'),
          _AdminKpi(label: 'Entregadas', value: '$palmasDelivered'),
        ],
        if (!isJunta && !isPalmas) ...[
          _AdminKpi(label: 'Pagos pendientes', value: '$pendingPayments'),
          _AdminKpi(label: 'Pagados', value: '$paidCount'),
          _AdminKpi(label: 'Acompañantes', value: '$companionCount'),
        ],
      ],
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  final String title;
  final String help;

  const _FormSectionTitle({required this.title, required this.help});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(help,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _AdminKpi extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _AdminKpi({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  onTap == null ? Colors.grey.shade200 : AppTheme.accentColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
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

  String _statusLabel() {
    if (campaign.isOpen) return 'Abierto';
    switch (campaign.status) {
      case 'draft':
        return 'Borrador';
      case 'published':
        return 'Publicado';
      case 'closed':
        return 'Cerrado';
      case 'finished':
        return 'Finalizado';
      case 'archived':
        return 'Archivado';
      default:
        return campaign.status;
    }
  }

  Color _statusColor() {
    if (campaign.isOpen) return AppTheme.accentColor;
    switch (campaign.status) {
      case 'draft':
        return Colors.blueGrey;
      case 'published':
        return Colors.blue.shade700;
      case 'closed':
      case 'finished':
        return AppTheme.textSecondary;
      case 'archived':
        return Colors.grey;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isJunta = campaign.type == 'junta_general_ordinaria';
    final isPalmas = campaign.type == 'palmas';
    final supportsFoodFlow = !isJunta && !isPalmas;
    final dateFormat = _campaignDateFormat();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: campaign.isOpen ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: campaign.isOpen
              ? AppTheme.accentColor.withAlpha(80)
              : Colors.grey.shade200,
        ),
      ),
      child: ExpansionTile(
        leading: campaign.coverImageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(campaign.coverImageUrl,
                    width: 44, height: 44, fit: BoxFit.cover),
              )
            : CircleAvatar(
                backgroundColor: _statusColor().withAlpha(20),
                child: Icon(
                  campaign.isOpen ? Icons.play_circle : Icons.pause_circle,
                  color: _statusColor(),
                ),
              ),
        title: Row(
          children: [
            Expanded(child: Text(campaign.name)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor().withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _statusColor().withAlpha(60)),
              ),
              child: Text(
                _statusLabel(),
                style: TextStyle(
                  color: _statusColor(),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('A\u00f1o ${campaign.year}'),
              if (dateFormat.isNotEmpty)
                Text(dateFormat,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              if (campaign.location.isNotEmpty)
                Text(campaign.location,
                    style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onEdit,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionButton(
                    icon: Icons.settings,
                    label: 'Configuraci\u00f3n',
                    onTap: onEdit),
                _ActionButton(
                    icon: Icons.dashboard_outlined,
                    label: isJunta
                        ? 'Asistencia e informe'
                        : isPalmas
                            ? 'Dashboard/Informe'
                            : 'Dashboard',
                    onTap: isJunta
                        ? () => _showRegistrationsDialog(context)
                        : () => _showDashboardDialog(context)),
                if (!isJunta)
                  _ActionButton(
                      icon: Icons.people,
                      label: isPalmas ? 'Peticiones y pagos' : 'Inscripciones',
                      onTap: () => _showRegistrationsDialog(context)),
                if (!isPalmas && !isJunta)
                  _ActionButton(
                      icon: Icons.analytics_outlined,
                      label: 'Informe',
                      onTap: () => _showReportDialog(context)),
                if (supportsFoodFlow) ...[
                  _ActionButton(
                      icon: Icons.restaurant_menu,
                      label: 'Men\u00fas/campos',
                      onTap: onEdit),
                  _ActionButton(
                      icon: Icons.payment,
                      label: 'Pagos',
                      onTap: () => _showRegistrationsDialog(context)),
                ],
                _ActionButton(
                    icon: Icons.attach_file,
                    label: 'Adjuntos',
                    onTap: () => _showAttachmentsDialog(context)),
                _ActionButton(
                    icon: Icons.image_outlined,
                    label: 'Portada',
                    onTap: () => _showCoverDialog(context)),
                if (!isJunta)
                  _ActionButton(
                      icon: Icons.open_in_new,
                      label: 'Popup login',
                      onTap: () => _showPopupDialog(context)),
                _ActionButton(
                    icon: Icons.copy_outlined,
                    label: 'Duplicar',
                    onTap: () => _duplicateCampaign(context)),
                if (campaign.status != 'archived')
                  _ActionButton(
                      icon: Icons.archive_outlined,
                      label: 'Archivar',
                      onTap: () => _archiveCampaign(context)),
                _ActionButton(
                    icon: Icons.delete_outline,
                    label: 'Eliminar evento',
                    destructive: true,
                    onTap: () => _confirmDelete(context)),
              ],
            ),
          ),
          StreamBuilder<List<EventRegistration>>(
            stream: service.watchRegistrations(campaign.id),
            builder: (context, snap) {
              final regs = snap.data ?? const <EventRegistration>[];
              final participants = regs.fold<int>(
                0,
                (total, reg) =>
                    total +
                    (reg.participants.isEmpty ? 1 : reg.participants.length),
              );
              final pendingPayments = regs
                  .where((reg) =>
                      reg.paymentStatus == 'pending' ||
                      reg.paymentStatus == 'partial')
                  .length;
              final estimated =
                  regs.fold<double>(0, (total, reg) => total + reg.totalAmount);
              final paid = regs.fold<double>(
                  0,
                  (total, reg) =>
                      total +
                      (reg.paymentStatus == 'paid'
                          ? reg.totalAmount
                          : reg.paidAmount));
              if (regs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: _CampaignStatsRow(
                    inscriptions: 0,
                    participants: 0,
                    pendingPayments: 0,
                    estimated: 0,
                    paid: 0,
                    showPayments: campaign.requiresPayment,
                  ),
                );
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _CampaignStatsRow(
                      inscriptions: regs.length,
                      participants: participants,
                      pendingPayments: pendingPayments,
                      estimated: estimated,
                      paid: paid,
                      showPayments: campaign.requiresPayment,
                    ),
                  ),
                  ConstrainedBox(
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
                            '${_registrationSummary(reg).isEmpty ? '' : ' · ${_registrationSummary(reg)}'}'
                            '${reg.heightCm == null ? '' : ' · ${reg.heightCm} cm'}'
                            '${reg.turnName.isEmpty ? '' : ' · ${reg.turnName}'}',
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              if (campaign.type == 'junta_general_ordinaria')
                                Chip(
                                  label: Text(_attendanceLabel(reg.status)),
                                  avatar:
                                      const Icon(Icons.how_to_vote, size: 18),
                                )
                              else
                                DropdownButton<String>(
                                  value: reg.status,
                                  items: isPalmas
                                      ? const [
                                          DropdownMenuItem(
                                              value: 'solicitada',
                                              child: Text('Solicitada')),
                                          DropdownMenuItem(
                                              value: 'confirmada',
                                              child: Text('Confirmada')),
                                          DropdownMenuItem(
                                              value: 'rechazada',
                                              child: Text('Rechazada')),
                                          DropdownMenuItem(
                                              value: 'entregada',
                                              child: Text('Entregada')),
                                          DropdownMenuItem(
                                              value: 'cancelada',
                                              child: Text('Cancelada')),
                                        ]
                                      : const [
                                          DropdownMenuItem(
                                              value: 'pending',
                                              child: Text('Pendiente')),
                                          DropdownMenuItem(
                                              value: 'confirmada',
                                              child: Text('Confirmada')),
                                          DropdownMenuItem(
                                              value: 'cancelada',
                                              child: Text('Cancelada')),
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
                                        value: 'partial',
                                        child: Text('Pago parcial')),
                                    DropdownMenuItem(
                                        value: 'paid', child: Text('Pagado')),
                                    DropdownMenuItem(
                                        value: 'refunded',
                                        child: Text('Devuelto')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      if (value == 'partial') {
                                        _showPartialPaymentDialog(
                                          context,
                                          service,
                                          reg,
                                        );
                                      } else {
                                        service.updateRegistration(reg.id, {
                                          'paymentStatus': value,
                                          'paidAmount': value == 'paid'
                                              ? reg.totalAmount
                                              : 0,
                                        });
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _exportCsv(regs),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Exportar inscritos'),
                      ),
                    ),
                  ),
                ],
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _confirmReminder(context),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Lanzar recordatorio a no inscritos'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _campaignDateFormat() {
    final parts = <String>[];
    if (campaign.eventDate != null) {
      final eventDate = campaign.eventDate!;
      parts.add('${eventDate.day}/${eventDate.month}/${eventDate.year}');
    }
    if (campaign.endDate != null && campaign.isOpen) {
      final remaining = campaign.endDate!.difference(DateTime.now()).inDays;
      if (remaining >= 0) {
        parts.add(remaining == 0
            ? 'Cierre hoy'
            : remaining == 1
                ? 'Cierra ma\u00f1ana'
                : 'Cierra en $remaining d\u00edas');
      } else {
        parts.add('Cerrada');
      }
    }
    return parts.join(' \u00b7 ');
  }

  Future<void> _duplicateCampaign(BuildContext context) async {
    final year = DateTime.now().year;
    final newCampaign = EventCampaign(
      id: '',
      type: campaign.type,
      year: year,
      name: '${campaign.name} (copia)',
      description: campaign.description,
      startDate: campaign.startDate,
      endDate: campaign.endDate,
      eventDate: campaign.eventDate,
      location: campaign.location,
      active: false,
      published: false,
      status: 'draft',
      requiresRegistration: campaign.requiresRegistration,
      allowCompanions: campaign.allowCompanions,
      allowExternalGuests: campaign.allowExternalGuests,
      allowOtherCofrades: campaign.allowOtherCofrades,
      maxCompanions: campaign.maxCompanions,
      capacity: campaign.capacity,
      waitlistEnabled: campaign.waitlistEnabled,
      requiresPayment: campaign.requiresPayment,
      freeEvent: campaign.freeEvent,
      memberPrice: campaign.memberPrice,
      guestPrice: campaign.guestPrice,
      childPrice: campaign.childPrice,
      protocolPrice: campaign.protocolPrice,
      memberAdultPrice: campaign.memberAdultPrice,
      memberChildPrice: campaign.memberChildPrice,
      guestAdultPrice: campaign.guestAdultPrice,
      guestChildPrice: campaign.guestChildPrice,
      protocolAdultPrice: campaign.protocolAdultPrice,
      protocolChildPrice: campaign.protocolChildPrice,
      realAdultMenuCost: campaign.realAdultMenuCost,
      realChildMenuCost: campaign.realChildMenuCost,
      palmMemberPrice: campaign.palmMemberPrice,
      palmExternalPrice: campaign.palmExternalPrice,
      realPalmCost: campaign.realPalmCost,
      allergiesEnabled: campaign.allergiesEnabled,
      observationsEnabled: campaign.observationsEnabled,
      showBanner: campaign.showBanner,
      bannerText: campaign.bannerText,
      menusEnabled: campaign.menusEnabled,
      menuRequired: campaign.menuRequired,
      menus: List<Map<String, dynamic>>.from(campaign.menus),
      customFields: List<Map<String, dynamic>>.from(campaign.customFields),
      registrationConfig:
          Map<String, dynamic>.from(campaign.registrationConfig),
      pricingConfig: Map<String, dynamic>.from(campaign.pricingConfig),
      companionConfig: Map<String, dynamic>.from(campaign.companionConfig),
      paymentConfig: Map<String, dynamic>.from(campaign.paymentConfig),
      notificationConfig:
          Map<String, dynamic>.from(campaign.notificationConfig),
      popupConfig: Map<String, dynamic>.from(campaign.popupConfig),
    );
    try {
      await service.saveCampaign(newCampaign);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento duplicado como borrador.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error al duplicar: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }

  Future<void> _archiveCampaign(BuildContext context) async {
    final confirm = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivar evento'),
        content: const Text(
          'El evento se mover\u00e1 a la secci\u00f3n de archivados. '
          'No ser\u00e1 visible para los cofrades pero se conservar\u00e1n todos los datos.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await service.saveCampaign(EventCampaign(
      id: campaign.id,
      type: campaign.type,
      year: campaign.year,
      name: campaign.name,
      description: campaign.description,
      startDate: campaign.startDate,
      endDate: campaign.endDate,
      eventDate: campaign.eventDate,
      location: campaign.location,
      active: false,
      published: false,
      status: 'archived',
      requiresRegistration: campaign.requiresRegistration,
      allowCompanions: campaign.allowCompanions,
      allowExternalGuests: campaign.allowExternalGuests,
      allowOtherCofrades: campaign.allowOtherCofrades,
      maxCompanions: campaign.maxCompanions,
      capacity: campaign.capacity,
      waitlistEnabled: campaign.waitlistEnabled,
      requiresPayment: campaign.requiresPayment,
      freeEvent: campaign.freeEvent,
      memberPrice: campaign.memberPrice,
      guestPrice: campaign.guestPrice,
      childPrice: campaign.childPrice,
      protocolPrice: campaign.protocolPrice,
      memberAdultPrice: campaign.memberAdultPrice,
      memberChildPrice: campaign.memberChildPrice,
      guestAdultPrice: campaign.guestAdultPrice,
      guestChildPrice: campaign.guestChildPrice,
      protocolAdultPrice: campaign.protocolAdultPrice,
      protocolChildPrice: campaign.protocolChildPrice,
      realAdultMenuCost: campaign.realAdultMenuCost,
      realChildMenuCost: campaign.realChildMenuCost,
      palmMemberPrice: campaign.palmMemberPrice,
      palmExternalPrice: campaign.palmExternalPrice,
      realPalmCost: campaign.realPalmCost,
      allergiesEnabled: campaign.allergiesEnabled,
      observationsEnabled: campaign.observationsEnabled,
      showBanner: campaign.showBanner,
      bannerText: campaign.bannerText,
      menusEnabled: campaign.menusEnabled,
      menuRequired: campaign.menuRequired,
      menus: campaign.menus,
      customFields: campaign.customFields,
      registrationConfig: campaign.registrationConfig,
      pricingConfig: campaign.pricingConfig,
      companionConfig: campaign.companionConfig,
      paymentConfig: campaign.paymentConfig,
      notificationConfig: campaign.notificationConfig,
      popupConfig: campaign.popupConfig,
      coverImagePath: campaign.coverImagePath,
      coverImageUrl: campaign.coverImageUrl,
    ));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento archivado.')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: ResponsiveDialogBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Esta acción puede afectar a inscripciones, pagos y documentos asociados. Si el evento ya tiene actividad, se archivará en lugar de eliminarse definitivamente.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar/archivar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await service.deleteCampaign(
      campaign,
      reason: reasonCtrl.text.trim().isEmpty
          ? 'Eliminado desde administración'
          : reasonCtrl.text.trim(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento eliminado o archivado.')),
      );
    }
  }

  void _showDashboardDialog(BuildContext context) {
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Dashboard · ${campaign.name}'),
        content: ResponsiveDialogBox(
          width: 620,
          child: StreamBuilder<List<EventRegistration>>(
            stream: service.watchRegistrations(campaign.id),
            builder: (context, snap) {
              final regs = snap.data ?? const <EventRegistration>[];
              final participants = regs.fold<int>(
                0,
                (total, reg) =>
                    total +
                    (reg.participants.isEmpty ? 1 : reg.participants.length),
              );
              final pendingPayments = regs
                  .where((reg) =>
                      reg.paymentStatus == 'pending' ||
                      reg.paymentStatus == 'partial')
                  .length;
              final estimated =
                  regs.fold<double>(0, (total, reg) => total + reg.totalAmount);
              final paid = regs.fold<double>(
                0,
                (total, reg) =>
                    total +
                    (reg.paymentStatus == 'paid'
                        ? reg.totalAmount
                        : reg.paidAmount),
              );
              if (campaign.type == 'palmas') {
                var cofradePalms = 0;
                var externalPalms = 0;
                for (final reg in regs) {
                  final people = reg.participants.isEmpty
                      ? [
                          {'type': 'cofrade'}
                        ]
                      : reg.participants;
                  for (final participant in people) {
                    if (participant['type'] == 'external_guest') {
                      externalPalms++;
                    } else {
                      cofradePalms++;
                    }
                  }
                }
                final totalPalms = cofradePalms + externalPalms;
                final expected = cofradePalms * campaign.palmMemberPrice +
                    externalPalms * campaign.palmExternalPrice;
                final totalCost = totalPalms * campaign.realPalmCost;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _AdminKpi(label: 'Palmas cofrade', value: '$cofradePalms'),
                    _AdminKpi(
                        label: 'Palmas no cofrade', value: '$externalPalms'),
                    _AdminKpi(label: 'Total palmas', value: '$totalPalms'),
                    _AdminKpi(
                        label: 'Recaudación prevista',
                        value: '${expected.toStringAsFixed(2)} €'),
                    _AdminKpi(
                        label: 'Recaudación confirmada',
                        value: '${paid.toStringAsFixed(2)} €'),
                    _AdminKpi(
                        label: 'Pendiente de cobro',
                        value:
                            '${(expected - paid).clamp(0, expected).toStringAsFixed(2)} €'),
                    _AdminKpi(
                        label: 'Coste total Cofradía',
                        value: '${totalCost.toStringAsFixed(2)} €'),
                    _AdminKpi(
                        label: 'Resultado previsto',
                        value:
                            '${(expected - totalCost).toStringAsFixed(2)} €'),
                    _AdminKpi(
                        label: 'Resultado real actual',
                        value: '${(paid - totalCost).toStringAsFixed(2)} €'),
                    _AdminKpi(
                        label: 'Subvención/pérdida',
                        value:
                            '${(totalCost - expected).clamp(0, totalCost).toStringAsFixed(2)} €'),
                  ],
                );
              }
              if (campaign.type == 'junta_general_ordinaria') {
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _AdminKpi(label: 'Respuestas', value: '${regs.length}'),
                    _AdminKpi(label: 'Participantes', value: '$participants'),
                  ],
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _AdminKpi(label: 'Inscripciones', value: '${regs.length}'),
                  _AdminKpi(label: 'Participantes', value: '$participants'),
                  _AdminKpi(
                      label: 'Pagos pendientes', value: '$pendingPayments'),
                  _AdminKpi(
                      label: 'Previsto',
                      value: '${estimated.toStringAsFixed(2)} €'),
                  _AdminKpi(
                      label: 'Cobrado', value: '${paid.toStringAsFixed(2)} €'),
                  _AdminKpi(
                    label: 'Pendiente',
                    value:
                        '${(estimated - paid).clamp(0, estimated).toStringAsFixed(2)} €',
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showRegistrationsDialog(BuildContext context) {
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(campaign.type == 'junta_general_ordinaria'
            ? 'Asistencia e informe · ${campaign.name}'
            : campaign.type == 'palmas'
                ? 'Peticiones · ${campaign.name}'
                : 'Inscripciones · ${campaign.name}'),
        content: ResponsiveDialogBox(
          width: 760,
          child: StreamBuilder<List<EventRegistration>>(
            stream: service.watchRegistrations(campaign.id),
            builder: (context, snap) {
              final regs = snap.data ?? const <EventRegistration>[];
              if (campaign.type == 'junta_general_ordinaria') {
                return FutureBuilder<List<Cofrade>>(
                  future: context.read<FirestoreService>().getCofrades().first,
                  builder: (context, cofradesSnap) {
                    final activeCofrades =
                        (cofradesSnap.data ?? const <Cofrade>[])
                            .where(_isActiveCofrade)
                            .toList();
                    final attending = regs
                        .where((reg) =>
                            reg.status == 'attending' ||
                            reg.status == 'confirmed' ||
                            reg.status == 'confirmada')
                        .length;
                    final notAttending = regs
                        .where((reg) => reg.status == 'not_attending')
                        .length;
                    final respondedIds =
                        regs.map((reg) => reg.cofradeId).toSet();
                    final pendingCofrades = activeCofrades
                        .where((cofrade) => !respondedIds.contains(cofrade.id))
                        .toList();
                    final delegated = regs
                        .expand((reg) => reg.delegatedVotes)
                        .where((vote) =>
                            '${vote['status'] ?? 'requested'}' != 'cancelled')
                        .toList();
                    final accepted = delegated
                        .where(
                            (vote) => '${vote['status'] ?? ''}' == 'accepted')
                        .length;
                    final requested = delegated
                        .where((vote) =>
                            '${vote['status'] ?? 'requested'}' == 'requested')
                        .length;
                    final rejected = delegated
                        .where(
                            (vote) => '${vote['status'] ?? ''}' == 'rejected')
                        .length;
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 560),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _AdminKpi(
                                  label: 'Convocados',
                                  value: '${activeCofrades.length}'),
                              _AdminKpi(label: 'Asisten', value: '$attending'),
                              _AdminKpi(
                                  label: 'No asisten', value: '$notAttending'),
                              _AdminKpi(
                                label: 'Pendientes respuesta',
                                value: '${pendingCofrades.length}',
                                onTap: () => _showJuntaPendingResponsesDialog(
                                    context, campaign, pendingCofrades),
                              ),
                              _AdminKpi(
                                  label: 'Votos solicitados',
                                  value: '${delegated.length}'),
                              _AdminKpi(
                                  label: 'Votos confirmados',
                                  value: '$accepted'),
                              _AdminKpi(
                                  label: 'Votos pendientes',
                                  value: '$requested'),
                              _AdminKpi(
                                  label: 'Votos rechazados',
                                  value: '$rejected'),
                              _AdminKpi(
                                  label: 'Total votos representados',
                                  value: '${attending + accepted}'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (regs.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(18),
                              child: Text('No hay respuestas registradas.'),
                            ),
                          for (final reg in regs)
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(reg.cofradeName),
                              subtitle: Text(
                                'Estado asistencia: ${_attendanceLabel(reg.status)} · '
                                '${reg.delegatedVotes.length} voto(s) delegado(s)',
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.person_add_alt_1),
                                    tooltip: 'Añadir delegación manual',
                                    onPressed: () =>
                                        _showJuntaDelegationManager(
                                            context, reg),
                                  ),
                                  if (reg.status == 'cancelled')
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Borrar asistencia cancelada',
                                      onPressed: () =>
                                          service.deleteJuntaRegistration(
                                        registrationId: reg.id,
                                        changedBy: 'admin',
                                      ),
                                    ),
                                ],
                              ),
                              children: [
                                if (reg.delegatedVotes.isEmpty)
                                  const ListTile(
                                    title: Text('Sin votos delegados'),
                                    dense: true,
                                  )
                                else
                                  for (final vote in reg.delegatedVotes)
                                    ListTile(
                                      dense: true,
                                      leading: const Icon(
                                          Icons.how_to_vote_outlined),
                                      title: Text(
                                          '${vote['delegatingCofradeName'] ?? ''}'),
                                      subtitle: Text(
                                          '${_delegationStatusLabel('${vote['status'] ?? 'requested'}')} · Nº ${vote['delegatingCofradeNumber'] ?? '-'} · DNI ${vote['delegatingCofradeDni'] ?? ''}'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () =>
                                            service.removeDelegatedVote(
                                          registrationId: reg.id,
                                          delegatingCofradeId:
                                              '${vote['delegatingCofradeId'] ?? ''}',
                                          changedBy: 'admin',
                                          reason: 'Corrección administrativa',
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: regs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final reg = regs[index];
                    return ListTile(
                      title: Text(reg.cofradeName),
                      subtitle: Text(
                        '${_registrationStatusLabel(reg.status)} · ${reg.participants.length} participante(s) · '
                        'Pago ${_paymentStatusLabel(reg.paymentStatus)} · Total ${reg.totalAmount.toStringAsFixed(2)} €',
                      ),
                      trailing: campaign.requiresPayment
                          ? DropdownButton<String>(
                              value: reg.paymentStatus,
                              items: const [
                                DropdownMenuItem(
                                    value: 'pending', child: Text('Pendiente')),
                                DropdownMenuItem(
                                    value: 'partial', child: Text('Parcial')),
                                DropdownMenuItem(
                                    value: 'paid', child: Text('Pagado')),
                                DropdownMenuItem(
                                    value: 'refunded', child: Text('Devuelto')),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                if (value == 'partial') {
                                  _showPartialPaymentDialog(
                                      context, service, reg);
                                } else {
                                  service.updateRegistration(reg.id, {
                                    'paymentStatus': value,
                                    'paidAmount':
                                        value == 'paid' ? reg.totalAmount : 0,
                                  });
                                }
                              },
                            )
                          : null,
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          if (campaign.type == 'junta_general_ordinaria')
            TextButton.icon(
              onPressed: () async {
                final regs =
                    await service.watchRegistrations(campaign.id).first;
                _exportJuntaDelegationsCsv(regs);
              },
              icon: const Icon(Icons.download),
              label: const Text('Exportar asistentes y votos'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  String _attendanceLabel(String status) {
    switch (status) {
      case 'pending_response':
        return 'Pendiente de respuesta';
      case 'attending':
      case 'asistire':
      case 'confirmed':
      case 'confirmada':
        return 'Asistirá';
      case 'not_attending':
      case 'no_asistire':
        return 'No asistirá';
      case 'delegated':
        return 'Voto delegado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status;
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
      case 'cancelled':
      case 'cancelada':
        return 'Cancelada';
      case 'confirmed':
      case 'confirmada':
        return 'Confirmada';
      case 'requested':
      case 'solicitada':
        return 'Solicitada';
      case 'pending_payment':
        return 'Pendiente de pago';
      case 'rejected':
      case 'rechazada':
        return 'Rechazada';
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
      case 'refunded':
      case 'devuelto':
        return 'Devuelto';
      case 'not_required':
        return 'No requerido';
      case 'pending':
      case 'pendiente':
        return 'Pendiente';
      default:
        return status;
    }
  }

  String _delegationStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Confirmado';
      case 'rejected':
        return 'Rechazado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Pendiente';
    }
  }

  bool _isActiveCofrade(Cofrade cofrade) {
    final status = cofrade.status.toLowerCase();
    final estado = cofrade.estado.toLowerCase();
    return status != 'baja' &&
        status != 'inactive' &&
        estado != 'baja' &&
        estado != 'inactivo' &&
        estado != 'pendiente' &&
        !cofrade.id.startsWith('ADM-');
  }

  void _showJuntaPendingResponsesDialog(
    BuildContext context,
    EventCampaign campaign,
    List<Cofrade> pending,
  ) {
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pendientes de respuesta · ${campaign.name}'),
        content: ResponsiveDialogBox(
          width: 560,
          child: pending.isEmpty
              ? const Text('No quedan cofrades pendientes de respuesta.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: pending.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cofrade = pending[index];
                    return ListTile(
                      leading: const Icon(Icons.pending_actions),
                      title: Text(cofrade.nombreCompleto),
                      subtitle: Text(
                          'Nº ${cofrade.numero ?? '-'}${cofrade.email.isEmpty ? '' : ' · ${cofrade.email}'}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton.icon(
            onPressed: pending.isEmpty
                ? null
                : () => _exportJuntaPendingResponsesCsv(campaign, pending),
            icon: const Icon(Icons.download),
            label: const Text('Exportar'),
          ),
          TextButton.icon(
            onPressed: pending.isEmpty
                ? null
                : () async {
                    final count = await service.sendReminderToNotRegistered(
                      campaign,
                    );
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content:
                              Text('Recordatorio enviado a $count cofrades.'),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Lanzar recordatorio'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _exportJuntaPendingResponsesCsv(
    EventCampaign campaign,
    List<Cofrade> pending,
  ) {
    final rows = <List<String>>[
      ['Cofrade pendiente', 'Nº cofrade', 'DNI', 'Email', 'Teléfono'],
      for (final cofrade in pending)
        [
          cofrade.nombreCompleto,
          '${cofrade.numero ?? ''}',
          cofrade.dni ?? '',
          cofrade.email,
          cofrade.telefonoMovil.isNotEmpty
              ? cofrade.telefonoMovil
              : cofrade.telefonoFijo,
        ],
    ];
    final csv = rows
        .map((row) =>
            row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','))
        .join('\n');
    final blob = html.Blob([utf8.encode(csv)], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = 'junta_pendientes_${campaign.year}.csv'
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _showJuntaDelegationManager(
    BuildContext context,
    EventRegistration registration,
  ) async {
    final fs = context.read<FirestoreService>();
    final queryCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var results = <Cofrade>[];
    var selectedReason = 'Petición presencial';
    var force = false;
    var searching = false;
    Cofrade? attendee;

    attendee = await fs.getCofrade(registration.cofradeId);
    if (!context.mounted) return;
    if (attendee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se ha encontrado el asistente.')),
      );
      return;
    }

    await showAppDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text('Delegaciones · ${registration.cofradeName}'),
          content: ResponsiveDialogBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Busca el cofrade que delega su voto. Si existe conflicto, solo administración puede forzar la delegación indicando motivo.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: queryCtrl,
                    decoration: InputDecoration(
                      labelText: 'Buscar por nombre, nº cofrade o DNI',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () async {
                          setLocalState(() => searching = true);
                          final found = await fs.searchCofrades(queryCtrl.text);
                          setLocalState(() {
                            results = found
                                .where((c) => c.id != registration.cofradeId)
                                .toList();
                            searching = false;
                          });
                        },
                      ),
                    ),
                  ),
                  if (searching) const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  for (final cofrade in results.take(8))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(cofrade.nombreCompleto),
                      subtitle: Text(
                          'Nº ${cofrade.numero ?? '-'}${(cofrade.dni ?? '').isEmpty ? '' : ' · DNI ${cofrade.dni}'}'),
                      trailing: TextButton(
                        onPressed: () async {
                          try {
                            await service.addDelegatedVote(
                              campaign: campaign,
                              registrationId: registration.id,
                              delegatingCofrade: cofrade,
                              delegatedTo: attendee!,
                              registeredBy: 'admin',
                              source: 'admin',
                              force: force,
                              overrideReason: force
                                  ? '${selectedReason}: ${reasonCtrl.text.trim()}'
                                  : '',
                              observations: notesCtrl.text,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Delegación registrada.')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '$e'.replaceFirst('Exception: ', ''))),
                              );
                            }
                          }
                        },
                        child: const Text('Añadir'),
                      ),
                    ),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Forzar delegación con motivo'),
                    subtitle: const Text(
                        'Usar solo para corregir conflicto validado por administración.'),
                    value: force,
                    onChanged: (value) => setLocalState(() => force = value),
                  ),
                  if (force) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      decoration: const InputDecoration(labelText: 'Motivo'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Petición presencial',
                            child: Text('Petición presencial')),
                        DropdownMenuItem(
                            value: 'Petición por email',
                            child: Text('Petición por email')),
                        DropdownMenuItem(
                            value: 'Error administrativo',
                            child: Text('Error administrativo')),
                        DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                      ],
                      onChanged: (value) => setLocalState(
                          () => selectedReason = value ?? selectedReason),
                    ),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Detalle obligatorio del motivo'),
                    ),
                  ],
                  TextField(
                    controller: notesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Observaciones'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar')),
          ],
        ),
      ),
    );
  }

  void _exportJuntaDelegationsCsv(List<EventRegistration> regs) {
    final rows = <List<String>>[
      [
        'Cofrade asistente',
        'Nº cofrade asistente',
        'DNI asistente',
        'Asiste sí/no',
        'Cofrade que delega',
        'Nº cofrade delegante',
        'DNI delegante',
        'Registrado por',
        'Fecha registro',
        'Observaciones',
      ],
    ];
    for (final reg in regs) {
      final attendeeNumber = reg.participants.isEmpty
          ? ''
          : '${reg.participants.first['cofradeNumber'] ?? ''}';
      final attendeeDni = reg.participants.isEmpty
          ? ''
          : '${reg.participants.first['dni'] ?? ''}';
      if (reg.delegatedVotes.isEmpty) {
        rows.add([
          reg.cofradeName,
          attendeeNumber,
          attendeeDni,
          _attendanceLabel(reg.status),
          '',
          '',
          '',
          '',
          '',
          '',
        ]);
      } else {
        for (final vote in reg.delegatedVotes) {
          final registeredAt = vote['registeredAt'];
          rows.add([
            reg.cofradeName,
            attendeeNumber,
            attendeeDni,
            _attendanceLabel(reg.status),
            '${vote['delegatingCofradeName'] ?? ''}',
            '${vote['delegatingCofradeNumber'] ?? ''}',
            '${vote['delegatingCofradeDni'] ?? ''}',
            '${vote['registeredBy'] ?? ''}',
            _csvDate(registeredAt),
            '${vote['observations'] ?? vote['overrideReason'] ?? ''}',
          ]);
        }
      }
    }
    final csv = rows
        .map((row) =>
            row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','))
        .join('\n');
    final blob = html.Blob([utf8.encode(csv)], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = 'junta_asistentes_votos_${campaign.year}.csv'
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _csvDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value == null ? '' : '$value';
  }

  void _showReportDialog(BuildContext context) {
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Informe · ${campaign.name}'),
        content: StreamBuilder<List<EventRegistration>>(
          stream: service.watchRegistrations(campaign.id),
          builder: (context, snap) {
            final regs = snap.data ?? const <EventRegistration>[];
            final rows = <ResponsiveTableRow>[];
            for (final reg in regs) {
              for (final participant in reg.participants) {
                rows.add(ResponsiveTableRow(cells: [
                  Text(reg.cofradeName),
                  Text('${participant['name'] ?? ''}'),
                  Text('${participant['type'] ?? 'cofrade'}'),
                  Text(_registrationStatusLabel(reg.status)),
                  Text(_paymentStatusLabel(reg.paymentStatus)),
                  Text(
                    '${((participant['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} €',
                  ),
                ]));
              }
            }
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay datos para el informe.'),
              );
            }
            return ResponsiveDataTable(
              columns: const [
                ResponsiveTableColumn(label: 'Titular', mobilePriority: 0),
                ResponsiveTableColumn(label: 'Participante', mobilePriority: 0),
                ResponsiveTableColumn(label: 'Tipo', mobilePriority: 2),
                ResponsiveTableColumn(label: 'Estado', mobilePriority: 1),
                ResponsiveTableColumn(label: 'Pago', mobilePriority: 1),
                ResponsiveTableColumn(
                    label: 'Importe', mobilePriority: 2, numeric: true),
              ],
              rows: rows,
            );
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Future<void> _showCoverDialog(BuildContext context) async {
    final storage = context.read<StorageService>();
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Portada del evento'),
        content: ResponsiveDialogBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (campaign.coverImageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(campaign.coverImageUrl,
                      height: 180, width: double.infinity, fit: BoxFit.cover),
                )
              else
                const ListTile(
                  leading: Icon(Icons.image_outlined),
                  title: Text('Sin portada configurada'),
                ),
            ],
          ),
        ),
        actions: [
          if (campaign.coverImageUrl.isNotEmpty)
            TextButton(
              onPressed: () async {
                await service.clearCoverImage(campaignId: campaign.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Eliminar portada'),
            ),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
                withData: true,
              );
              final file = result?.files.single;
              if (file?.bytes == null) return;
              final upload = await storage.uploadFile(
                path: 'events/${campaign.id}/cover',
                bytes: file!.bytes!,
                fileName: file.name,
                allowedExtensions: {'jpg', 'jpeg', 'png', 'webp'},
                maxSizeBytes: 8 * 1024 * 1024,
              );
              await service.updateCoverImage(
                campaignId: campaign.id,
                storagePath: upload['storage_path'] ?? '',
                url: upload['url'] ?? '',
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            icon: const Icon(Icons.upload),
            label: const Text('Subir/cambiar'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Future<void> _showAttachmentsDialog(BuildContext context) async {
    final storage = context.read<StorageService>();
    String category = 'documento_informativo';
    bool visibleToUsers = true;
    showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Adjuntos del evento'),
          content: ResponsiveDialogBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: const [
                          DropdownMenuItem(
                              value: 'convocatoria',
                              child: Text('Convocatoria')),
                          DropdownMenuItem(
                              value: 'orden_dia', child: Text('Orden del día')),
                          DropdownMenuItem(
                              value: 'documentacion_previa',
                              child: Text('Documentación previa')),
                          DropdownMenuItem(value: 'menu', child: Text('Menú')),
                          DropdownMenuItem(
                              value: 'autorizacion',
                              child: Text('Autorización')),
                          DropdownMenuItem(
                              value: 'cartel', child: Text('Cartel')),
                          DropdownMenuItem(value: 'acta', child: Text('Acta')),
                          DropdownMenuItem(
                              value: 'documento_informativo',
                              child: Text('Documento informativo')),
                          DropdownMenuItem(value: 'otro', child: Text('Otro')),
                        ],
                        onChanged: (value) =>
                            setLocalState(() => category = value ?? 'otro'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Visible para cofrades'),
                        value: visibleToUsers,
                        onChanged: (value) =>
                            setLocalState(() => visibleToUsers = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: service.watchAttachments(campaign.id),
                  builder: (context, snap) {
                    final attachments = (snap.data ?? [])
                        .where((item) => item['status'] != 'deleted')
                        .toList();
                    if (attachments.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('No hay adjuntos.'),
                      );
                    }
                    return Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: attachments
                            .map((attachment) => ListTile(
                                  leading: const Icon(Icons.attach_file),
                                  title: Text(
                                      '${attachment['fileName'] ?? attachment['nombre'] ?? 'Archivo'}'),
                                  subtitle: Text(
                                      '${attachment['category'] ?? ''} · ${attachment['visibleToUsers'] == true ? 'Visible' : 'Solo admin'}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => service.deleteAttachment(
                                      campaignId: campaign.id,
                                      attachmentId: '${attachment['id']}',
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  withData: true,
                  allowMultiple: false,
                );
                final file = result?.files.single;
                if (file?.bytes == null) return;
                final upload = await storage.uploadFile(
                  path: 'events/${campaign.id}/attachments',
                  bytes: file!.bytes!,
                  fileName: file.name,
                  maxSizeBytes: 20 * 1024 * 1024 - 1,
                  customMetadata: {
                    'eventId': campaign.id,
                    'visibleToUsers': '$visibleToUsers',
                  },
                );
                await service.addAttachment(
                  campaignId: campaign.id,
                  metadata: {
                    'fileName': file.name,
                    'storagePath': upload['storage_path'],
                    'downloadUrl': upload['url'],
                    'category': category,
                    'visibleToUsers': visibleToUsers,
                    'size': file.size,
                    'contentType': upload['tipo'],
                    'uploadedBy': upload['uploaded_by'],
                  },
                );
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Subir archivo'),
            ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar')),
          ],
        ),
      ),
    );
  }

  void _showPopupDialog(BuildContext context) {
    final popup = Map<String, dynamic>.from(campaign.popupConfig);
    var enabled = popup['enabled'] == true;
    var popupType = '${popup['type'] ?? 'informativo'}';
    var target = '${popup['target'] ?? 'todos'}';
    var repeatUntilAction = popup['repeatUntilAction'] == true;
    var showCover = popup['showCover'] != false;
    final titleCtrl =
        TextEditingController(text: '${popup['title'] ?? campaign.name}');
    final bodyCtrl = TextEditingController(text: '${popup['body'] ?? ''}');
    final buttonCtrl = TextEditingController(
        text: '${popup['primaryButton'] ?? 'Ver evento'}');
    showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Aviso emergente al iniciar sesión'),
          content: ResponsiveDialogBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar popup al iniciar sesión'),
                    value: enabled,
                    onChanged: (value) => setLocalState(() => enabled = value),
                  ),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  TextField(
                    controller: bodyCtrl,
                    decoration: const InputDecoration(labelText: 'Texto'),
                    maxLines: 3,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: popupType,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(
                          value: 'informativo', child: Text('Informativo')),
                      DropdownMenuItem(
                          value: 'requiere_inscripcion',
                          child: Text('Requiere inscripción')),
                      DropdownMenuItem(
                          value: 'requiere_confirmacion',
                          child: Text('Requiere confirmación')),
                      DropdownMenuItem(
                          value: 'urgente', child: Text('Urgente')),
                    ],
                    onChanged: (value) =>
                        setLocalState(() => popupType = value ?? popupType),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: target,
                    decoration:
                        const InputDecoration(labelText: 'Público objetivo'),
                    items: const [
                      DropdownMenuItem(
                          value: 'todos', child: Text('Todos activos')),
                      DropdownMenuItem(
                          value: 'no_inscritos',
                          child: Text('Solo no inscritos')),
                      DropdownMenuItem(
                          value: 'inscritos', child: Text('Solo inscritos')),
                      DropdownMenuItem(
                          value: 'no_respondidos',
                          child: Text('Solo no respondidos')),
                    ],
                    onChanged: (value) =>
                        setLocalState(() => target = value ?? target),
                  ),
                  TextField(
                    controller: buttonCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Botón principal'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Repetir hasta acción'),
                    value: repeatUntilAction,
                    onChanged: (value) =>
                        setLocalState(() => repeatUntilAction = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar portada'),
                    value: showCover,
                    onChanged: (value) =>
                        setLocalState(() => showCover = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                await service.saveCampaign(EventCampaign(
                  id: campaign.id,
                  type: campaign.type,
                  year: campaign.year,
                  name: campaign.name,
                  description: campaign.description,
                  startDate: campaign.startDate,
                  endDate: campaign.endDate,
                  eventDate: campaign.eventDate,
                  location: campaign.location,
                  active: campaign.active,
                  published: campaign.published,
                  status: campaign.status,
                  requiresRegistration: campaign.requiresRegistration,
                  allowCompanions: campaign.allowCompanions,
                  allowExternalGuests: campaign.allowExternalGuests,
                  allowOtherCofrades: campaign.allowOtherCofrades,
                  maxCompanions: campaign.maxCompanions,
                  capacity: campaign.capacity,
                  waitlistEnabled: campaign.waitlistEnabled,
                  requiresPayment: campaign.requiresPayment,
                  freeEvent: campaign.freeEvent,
                  memberPrice: campaign.memberPrice,
                  guestPrice: campaign.guestPrice,
                  childPrice: campaign.childPrice,
                  protocolPrice: campaign.protocolPrice,
                  memberAdultPrice: campaign.memberAdultPrice,
                  memberChildPrice: campaign.memberChildPrice,
                  guestAdultPrice: campaign.guestAdultPrice,
                  guestChildPrice: campaign.guestChildPrice,
                  protocolAdultPrice: campaign.protocolAdultPrice,
                  protocolChildPrice: campaign.protocolChildPrice,
                  realAdultMenuCost: campaign.realAdultMenuCost,
                  realChildMenuCost: campaign.realChildMenuCost,
                  allergiesEnabled: campaign.allergiesEnabled,
                  observationsEnabled: campaign.observationsEnabled,
                  showBanner: campaign.showBanner,
                  bannerText: campaign.bannerText,
                  menusEnabled: campaign.menusEnabled,
                  menuRequired: campaign.menuRequired,
                  menus: campaign.menus,
                  customFields: campaign.customFields,
                  registrationConfig: campaign.registrationConfig,
                  pricingConfig: campaign.pricingConfig,
                  companionConfig: campaign.companionConfig,
                  paymentConfig: campaign.paymentConfig,
                  notificationConfig: campaign.notificationConfig,
                  popupConfig: {
                    'enabled': enabled,
                    'title': titleCtrl.text.trim(),
                    'body': bodyCtrl.text.trim(),
                    'type': popupType,
                    'target': target,
                    'repeatUntilAction': repeatUntilAction,
                    'primaryButton': buttonCtrl.text.trim(),
                    'showCover': showCover,
                  },
                  coverImagePath: campaign.coverImagePath,
                  coverImageUrl: campaign.coverImageUrl,
                  deleted: campaign.deleted,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar popup'),
            ),
          ],
        ),
      ),
    );
  }

  String _registrationSummary(EventRegistration reg) {
    final parts = <String>[];
    for (final participant in reg.participants) {
      final menu = '${participant['menuName'] ?? ''}'.trim();
      if (menu.isNotEmpty) parts.add('Menú $menu');
      final answers = participant['answers'];
      if (answers is Map && answers.isNotEmpty) {
        parts.addAll(
            answers.entries.map((entry) => '${entry.key}: ${entry.value}'));
      }
    }
    if (reg.answers.isNotEmpty) {
      parts.addAll(
          reg.answers.entries.map((entry) => '${entry.key}: ${entry.value}'));
    }
    return parts.take(4).join(' · ');
  }

  void _exportCsv(List<EventRegistration> regs) {
    final rows = <List<String>>[
      [
        'Evento',
        'Año',
        'Cofrade',
        'Estado',
        'Pago',
        'Total',
        'Pagado',
        'Pendiente',
        'Añadido por',
        'Menús',
        'Respuestas inscripción',
        'Respuestas participantes',
      ],
      ...regs.map((reg) {
        final menus = reg.participants
            .map((participant) => '${participant['menuName'] ?? ''}'.trim())
            .where((value) => value.isNotEmpty)
            .join(' | ');
        final participantAnswers = reg.participants
            .map((participant) {
              final name = '${participant['name'] ?? reg.cofradeName}'.trim();
              final answers = participant['answers'];
              if (answers is! Map || answers.isEmpty) return '';
              return '$name: ${_mapToHumanText(answers)}';
            })
            .where((value) => value.isNotEmpty)
            .join(' | ');
        final paid =
            reg.paymentStatus == 'paid' ? reg.totalAmount : reg.paidAmount;
        final pending = (reg.totalAmount - paid).clamp(0, reg.totalAmount);
        return [
          campaign.name,
          '${campaign.year}',
          reg.cofradeName,
          reg.status,
          reg.paymentStatus,
          reg.totalAmount.toStringAsFixed(2),
          paid.toStringAsFixed(2),
          pending.toStringAsFixed(2),
          reg.addedByName,
          menus,
          _mapToHumanText(reg.answers),
          participantAnswers,
        ];
      }),
    ];
    final csv = rows
        .map((row) =>
            row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','))
        .join('\n');
    final bytes = utf8.encode('\uFEFF$csv');
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        '${campaign.type}_${campaign.year}_inscripciones.csv',
      )
      ..click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  String _mapToHumanText(Map<dynamic, dynamic> value) {
    if (value.isEmpty) return '';
    return value.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' | ');
  }

  void _showPartialPaymentDialog(
    BuildContext context,
    EventsService service,
    EventRegistration reg,
  ) {
    final paidCtrl =
        TextEditingController(text: reg.paidAmount.toStringAsFixed(2));
    final notesCtrl = TextEditingController(text: reg.paymentNotes);
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pago parcial'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total: ${reg.totalAmount.toStringAsFixed(2)} €'),
              const SizedBox(height: 12),
              TextField(
                controller: paidCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Importe pagado',
                  suffixText: '€',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final paid =
                  double.tryParse(paidCtrl.text.replaceAll(',', '.')) ?? 0;
              final normalized = paid.clamp(0, reg.totalAmount).toDouble();
              await service.updateRegistration(reg.id, {
                'paymentStatus': 'partial',
                'paidAmount': normalized,
                'paymentNotes': notesCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmReminder(BuildContext context) {
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lanzar recordatorio'),
        content: Text(
          'Se calcularán los cofrades activos que no figuren en ${campaign.name} ni como titulares ni como participantes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final sent = await service.sendReminderToNotRegistered(campaign);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Recordatorio enviado a $sent cofrades no inscritos.'),
                  ),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}

class _CampaignGroup extends StatelessWidget {
  final String title;
  final List<EventCampaign> campaigns;
  final EventsService service;
  final ValueChanged<EventCampaign> onEdit;

  const _CampaignGroup({
    required this.title,
    required this.campaigns,
    required this.service,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...campaigns.map((campaign) => _CampaignAdminCard(
                campaign: campaign,
                service: service,
                onEdit: () => onEdit(campaign),
              )),
        ],
      ),
    );
  }
}

class _CampaignStatsRow extends StatelessWidget {
  final int inscriptions;
  final int participants;
  final int pendingPayments;
  final double estimated;
  final double paid;
  final bool showPayments;

  const _CampaignStatsRow({
    required this.inscriptions,
    required this.participants,
    required this.pendingPayments,
    required this.estimated,
    required this.paid,
    required this.showPayments,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(label: 'Inscripciones', value: '$inscriptions'),
        _StatChip(label: 'Participantes', value: '$participants'),
        if (showPayments) ...[
          _StatChip(label: 'Pagos pendientes', value: '$pendingPayments'),
          _StatChip(
              label: 'Estimado', value: '${estimated.toStringAsFixed(2)} €'),
          _StatChip(label: 'Cobrado', value: '${paid.toStringAsFixed(2)} €'),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.grey.shade100,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red.shade700 : AppTheme.primaryColor;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withAlpha(90)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
