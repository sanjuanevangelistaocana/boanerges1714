import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/firestore_service.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/storage_service.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/tag_config.dart';
import 'package:boanerges1714/models/cofrade_field_config.dart';

class ManageCofradesScreen extends StatefulWidget {
  const ManageCofradesScreen({super.key});

  @override
  State<ManageCofradesScreen> createState() => _ManageCofradesScreenState();
}

class _ManageCofradesScreenState extends State<ManageCofradesScreen> {
  String _filtroEstado = 'activo';
  String _busqueda = '';
  final Set<String> _tagFilterIds = <String>{};
  bool _tagFilterMatchAll = true;
  bool _filterOpenConversations = false;
  bool _filterPendingConversations = false;
  bool _filterIncompleteProfiles = false;
  String _accessFilter = 'todos';
  String _consentFilter = 'todos';
  StreamSubscription<List<Map<String, dynamic>>>? _conversationSub;
  Map<String, List<Map<String, dynamic>>> _conversationsByCofrade = const {};
  List<Cofrade> _lastAllCofrades = const [];
  Map<String, String> _tagNames = const {};
  Map<String, String> _tagColors = const {};
  List<CofradeFieldConfig> _fieldsConfig = const [];
  final Set<String> _selectedCofradeIds = <String>{};
  bool _tagsRecomputedOnOpen = false;
  bool _tagsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeTagsOnOpen());
  }

  @override
  void dispose() {
    _conversationSub?.cancel();
    super.dispose();
  }

  Future<void> _recomputeTagsOnOpen() async {
    if (_tagsRecomputedOnOpen || !mounted) return;
    _tagsRecomputedOnOpen = true;
    try {
      final fs = context.read<FirestoreService>();
      _startConversationListener(fs);
      final tags = await fs.getTagsConfig().first;
      final fields = await fs.getCofradeFieldsConfig().first;
      if (!mounted) return;
      setState(() {
        _tagNames = {for (final tag in tags) tag.id: tag.nombre};
        _tagColors = {for (final tag in tags) tag.id: tag.color};
        _fieldsConfig = fields;
      });
      await fs.recomputeAutomaticTags();
      final refreshedTags = await fs.getTagsConfig().first;
      if (!mounted) return;
      setState(() {
        _tagNames = {for (final tag in refreshedTags) tag.id: tag.nombre};
        _tagColors = {for (final tag in refreshedTags) tag.id: tag.color};
      });
    } catch (e) {
      debugPrint('[AdminCofrades] auto tags recompute failed: $e');
    } finally {
      if (mounted) setState(() => _tagsReady = true);
    }
  }

  void _updateFilters(VoidCallback change) {
    setState(() {
      change();
      _selectedCofradeIds.clear();
    });
  }

  void _startConversationListener(FirestoreService fs) {
    _conversationSub ??= fs.watchAllConversations().listen((conversations) {
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final conversation in conversations) {
        final cofradeId = '${conversation['cofradeId'] ?? ''}';
        if (cofradeId.isEmpty) continue;
        grouped.putIfAbsent(cofradeId, () => []).add(conversation);
      }
      if (mounted) setState(() => _conversationsByCofrade = grouped);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gestión de Cofrades',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showCreateCofradeDialog(context),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Nuevo cofrade'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showTagsManagement(context),
                    icon: const Icon(Icons.sell),
                    label: const Text('Gestión de tags'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showFieldsConfig(context),
                    icon: const Icon(Icons.tune),
                    label: const Text('Configurar campos'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showRoleAudit(context),
                    icon: const Icon(Icons.security),
                    label: const Text('Auditoría roles'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Filters
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre, nº, teléfono o email...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) =>
                        _updateFilters(() => _busqueda = v.toLowerCase()),
                  ),
                ),
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _filtroEstado == 'todos',
                  onSelected: (_) =>
                      _updateFilters(() => _filtroEstado = 'todos'),
                ),
                ChoiceChip(
                  label: const Text('Activos'),
                  selected: _filtroEstado == 'activo',
                  onSelected: (_) =>
                      _updateFilters(() => _filtroEstado = 'activo'),
                ),
                ChoiceChip(
                  label: const Text('Baja'),
                  selected: _filtroEstado == 'baja',
                  onSelected: (_) =>
                      _updateFilters(() => _filtroEstado = 'baja'),
                ),
                FilterChip(
                  label: const Text('Con conversaciones abiertas'),
                  selected: _filterOpenConversations,
                  onSelected: (value) =>
                      _updateFilters(() => _filterOpenConversations = value),
                ),
                FilterChip(
                  label: const Text('Pendientes de resolver'),
                  selected: _filterPendingConversations,
                  onSelected: (value) =>
                      _updateFilters(() => _filterPendingConversations = value),
                ),
                FilterChip(
                  label: const Text('Datos incompletos'),
                  selected: _filterIncompleteProfiles,
                  onSelected: (value) =>
                      _updateFilters(() => _filterIncompleteProfiles = value),
                ),
                DropdownButton<String>(
                  value: _accessFilter,
                  items: const [
                    DropdownMenuItem(
                        value: 'todos', child: Text('Acceso: todos')),
                    DropdownMenuItem(
                        value: 'nunca', child: Text('Nunca han accedido')),
                    DropdownMenuItem(
                        value: 'han_accedido', child: Text('Han accedido')),
                    DropdownMenuItem(
                        value: 'reciente', child: Text('Acceso reciente')),
                    DropdownMenuItem(
                        value: 'google', child: Text('Acceso por Google')),
                    DropdownMenuItem(
                        value: 'password',
                        child: Text('Acceso por email/password')),
                    DropdownMenuItem(
                        value: 'dni', child: Text('Acceso por DNI')),
                  ],
                  onChanged: (value) =>
                      _updateFilters(() => _accessFilter = value ?? 'todos'),
                ),
                DropdownButton<String>(
                  value: _consentFilter,
                  items: const [
                    DropdownMenuItem(
                        value: 'todos', child: Text('Consentimiento: todos')),
                    DropdownMenuItem(
                        value: 'signed', child: Text('Consentimiento firmado')),
                    DropdownMenuItem(
                        value: 'revocation_requested',
                        child: Text('Revocación pendiente')),
                    DropdownMenuItem(
                        value: 'revoked',
                        child: Text('Consentimiento revocado')),
                    DropdownMenuItem(
                        value: 'missing', child: Text('Sin consentimiento')),
                    DropdownMenuItem(
                        value: 'mixed_email',
                        child: Text('Email compartido mixto')),
                  ],
                  onChanged: (value) =>
                      _updateFilters(() => _consentFilter = value ?? 'todos'),
                ),
                StreamBuilder<List<TagConfig>>(
                  stream: firestoreService.getUsedTagsConfig(),
                  builder: (context, snapshot) {
                    final tags = snapshot.data ?? const <TagConfig>[];
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownButton<String>(
                          hint: const Text('Añadir tag'),
                          value: null,
                          items: tags
                              .where((tag) => !_tagFilterIds.contains(tag.id))
                              .map((tag) => DropdownMenuItem(
                                    value: tag.id,
                                    child: Text(tag.nombre),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            _updateFilters(() => _tagFilterIds.add(value));
                          },
                        ),
                        if (_tagFilterIds.isNotEmpty)
                          DropdownButton<bool>(
                            value: _tagFilterMatchAll,
                            items: const [
                              DropdownMenuItem(
                                value: true,
                                child: Text('Tiene todas las tags'),
                              ),
                              DropdownMenuItem(
                                value: false,
                                child: Text('Tiene alguna tag'),
                              ),
                            ],
                            onChanged: (value) => _updateFilters(
                                () => _tagFilterMatchAll = value ?? true),
                          ),
                        ..._tagFilterIds.map((tagId) => InputChip(
                              label: Text(_tagLabel(tagId)),
                              backgroundColor: _tagColor(tagId).withAlpha(24),
                              onDeleted: () => _updateFilters(
                                  () => _tagFilterIds.remove(tagId)),
                            )),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!_tagsReady) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Recalculando tags automáticas...'),
              const SizedBox(height: 24),
            ],
            StreamBuilder<List<Cofrade>>(
              stream: _tagsReady
                  ? firestoreService.watchAllCofradesForAdmin()
                  : const Stream<List<Cofrade>>.empty(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final message = error is FirebaseException &&
                          error.code == 'permission-denied'
                      ? 'No tienes permisos para consultar cofrades.'
                      : 'Error técnico consultando cofrades: $error';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(message)),
                    ),
                  );
                }
                final totalLeidos = snapshot.data?.length ?? 0;
                final allCofrades = (snapshot.data ?? [])
                    .where(
                        (c) => !c.esCuentaServicio && !c.id.startsWith('ADM-'))
                    .toList();
                _lastAllCofrades = allCofrades;
                var cofrades = allCofrades.toList();
                final sharedByEmail = _sharedEmailMap(allCofrades);
                debugPrint(
                    '[AdminCofrades] docs recibidos=$totalLeidos filtro=$_filtroEstado tags=${_tagFilterIds.join(",")} busqueda="$_busqueda"');

                // Apply filters
                if (_filtroEstado != 'todos') {
                  cofrades = cofrades.where((c) {
                    if (_filtroEstado == 'activo') return c.isActivo;
                    if (_filtroEstado == 'baja') return c.isBaja;
                    return true;
                  }).toList();
                }
                if (_tagFilterIds.isNotEmpty) {
                  cofrades = cofrades.where((c) {
                    final tags = {...c.tagsManual, ...c.tagsAuto};
                    return _tagFilterMatchAll
                        ? _tagFilterIds.every(tags.contains)
                        : _tagFilterIds.any(tags.contains);
                  }).toList();
                }
                if (_filterOpenConversations) {
                  cofrades = cofrades
                      .where((c) => _hasOpenConversation(c.id))
                      .toList();
                }
                if (_filterPendingConversations) {
                  cofrades = cofrades
                      .where((c) => _hasPendingAdminConversation(c.id))
                      .toList();
                }
                if (_filterIncompleteProfiles) {
                  cofrades = cofrades
                      .where((c) => _missingRequiredLabels(c).isNotEmpty)
                      .toList();
                }
                if (_accessFilter != 'todos') {
                  cofrades = cofrades.where(_matchesAccessFilter).toList();
                }
                if (_consentFilter != 'todos') {
                  cofrades = cofrades
                      .where((c) => _matchesConsentFilter(c, sharedByEmail))
                      .toList();
                }
                if (_busqueda.isNotEmpty) {
                  cofrades = cofrades.where((c) {
                    final searchable = [
                      c.nombre,
                      c.apellidos,
                      c.nombreCompleto,
                      c.numero?.toString() ?? '',
                      c.telefonoMovil,
                      c.email,
                    ].join(' ').toLowerCase();
                    return searchable.contains(_busqueda);
                  }).toList();
                }
                cofrades.sort(_compareCofradesForAdminList);
                _selectedCofradeIds
                    .removeWhere((id) => !cofrades.any((c) => c.id == id));
                debugPrint(
                    '[AdminCofrades] docs después de filtros=${cofrades.length}');

                if (cofrades.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          totalLeidos == 0
                              ? 'No se han leído documentos de cofrades. Revisa permisos, colección o consola.'
                              : 'No hay cofrades que coincidan con este filtro.',
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOperationalPanel(cofrades),
                    _buildConsentAdminBanner(allCofrades),
                    const SizedBox(height: 12),
                    _buildSelectionControls(cofrades),
                    const SizedBox(height: 8),
                    if (_selectedCofradeIds.isNotEmpty)
                      _buildBulkActionsBar(cofrades),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cofrades.length,
                      itemBuilder: (context, index) {
                        final cofrade = cofrades[index];
                        final selected =
                            _selectedCofradeIds.contains(cofrade.id);
                        final missing = _missingRequiredLabels(cofrade);
                        final emailPeers =
                            sharedByEmail[_normalizeEmail(cofrade.email)] ??
                                const <Cofrade>[];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Checkbox(
                                  value: selected,
                                  onChanged: (value) => setState(() {
                                    if (value == true) {
                                      _selectedCofradeIds.add(cofrade.id);
                                    } else {
                                      _selectedCofradeIds.remove(cofrade.id);
                                    }
                                  }),
                                ),
                                CircleAvatar(
                                  backgroundColor:
                                      _getStatusColor(cofrade.estado),
                                  child: Text(
                                    cofrade.nombre.isNotEmpty
                                        ? cofrade.nombre[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    cofrade.nombreCompleto,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                _DataQualityChip(
                                  status: _dataQualityStatus(cofrade),
                                  missing: missing,
                                  pendingReview:
                                      cofrade.hasPendingProfileReview,
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${cofrade.estado} · ${cofrade.email.isEmpty ? "Sin email" : cofrade.email} · Nº ${cofrade.numero ?? "-"}',
                                ),
                                Text(
                                  cofrade.rawData['hasLoggedIn'] == true
                                      ? 'Ha accedido · ${_formatRawDate(cofrade.rawData['lastLoginAt'])} · ${cofrade.rawData['lastLoginMethod'] ?? "-"}'
                                      : 'Nunca ha accedido',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  'Consentimiento: ${_consentStatusLabel(cofrade)}${emailPeers.length > 1 ? " · Email compartido con ${emailPeers.length - 1} perfil(es)" : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _consentStatusColor(cofrade),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (cofrade.tagsManual.isNotEmpty ||
                                    cofrade.tagsAuto.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        ...cofrade.tagsAuto
                                            .where(
                                                (tag) => tag != 'faltan_datos')
                                            .map((tag) => Chip(
                                                  label: Text(_tagLabel(tag)),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  backgroundColor:
                                                      _tagColor(tag)
                                                          .withAlpha(30),
                                                  labelStyle: TextStyle(
                                                      color: _tagColor(tag)),
                                                )),
                                        ...cofrade.tagsManual.map((tag) => Chip(
                                              label: Text(_tagLabel(tag)),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              backgroundColor:
                                                  _tagColor(tag).withAlpha(24),
                                              labelStyle: TextStyle(
                                                  color: _tagColor(tag)),
                                            )),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () => _showCofrade360Dialog(cofrade),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StreamBuilder<List<Map<String, dynamic>>>(
                                  stream: firestoreService
                                      .watchConversations(cofrade.id),
                                  builder: (context, snapshot) {
                                    final open = (snapshot.data ?? [])
                                        .where((conv) =>
                                            conv['status'] != 'closed')
                                        .toList();
                                    if (open.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    final pendingAdmin = open.any((conv) =>
                                        conv['status'] == 'pending_admin');
                                    return Tooltip(
                                      message: pendingAdmin
                                          ? 'Tiene conversación pendiente de administración'
                                          : 'Tiene conversación abierta',
                                      child: IconButton(
                                        icon: Icon(
                                          pendingAdmin
                                              ? Icons.mark_email_unread
                                              : Icons.forum_outlined,
                                          color: pendingAdmin
                                              ? Colors.orange.shade700
                                              : AppTheme.primaryColor,
                                        ),
                                        onPressed: () => context.go(
                                          '/admin/sugerencias?cofradeId=${cofrade.id}',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  tooltip: 'Editar cofrade',
                                  onPressed: () =>
                                      _showEditCofradeDialog(cofrade),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (action) =>
                                      _handleAction(action, cofrade),
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'editar',
                                      child: ListTile(
                                        leading: Icon(Icons.edit),
                                        title: Text('Editar'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    if (!cofrade.isBaja)
                                      const PopupMenuItem(
                                        value: 'baja',
                                        child: ListTile(
                                          leading: Icon(Icons.block,
                                              color: Colors.red),
                                          title: Text('Dar de baja'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    if (cofrade.isBaja)
                                      const PopupMenuItem(
                                        value: 'reactivar',
                                        child: ListTile(
                                          leading: Icon(Icons.refresh,
                                              color: Colors.blue),
                                          title: Text('Reactivar'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    if (!cofrade.isAdmin)
                                      const PopupMenuItem(
                                        value: 'hacer_admin',
                                        child: ListTile(
                                          leading: Icon(
                                              Icons.admin_panel_settings,
                                              color: AppTheme.primaryColor),
                                          title: Text('Hacer admin'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    if (cofrade.isAdmin)
                                      const PopupMenuItem(
                                        value: 'quitar_admin',
                                        child: ListTile(
                                          leading: Icon(
                                              Icons.admin_panel_settings,
                                              color: Colors.red),
                                          title: Text('Quitar admin'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'gestionar_tags',
                                      child: ListTile(
                                        leading: Icon(Icons.sell),
                                        title: Text('Gestionar tags'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'mensaje',
                                      child: ListTile(
                                        leading: Icon(Icons.forum_outlined),
                                        title: Text('Enviar mensaje privado'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'auditoria',
                                      child: ListTile(
                                        leading: Icon(Icons.history),
                                        title:
                                            Text('Ver auditoría del cofrade'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    if (cofrade.hasPendingProfileReview)
                                      const PopupMenuItem(
                                        value: 'revisar_cambios',
                                        child: ListTile(
                                          leading:
                                              Icon(Icons.verified_outlined),
                                          title:
                                              Text('Marcar cambios revisados'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    if (cofrade.gdprDigitalStatus ==
                                            'revocation_requested' ||
                                        cofrade.gdprDigitalStatus ==
                                            'revoked' ||
                                        cofrade.gdprDigitalRevoked)
                                      const PopupMenuItem(
                                        value: 'reactivar_consentimiento',
                                        child: ListTile(
                                          leading: Icon(Icons.privacy_tip),
                                          title:
                                              Text('Reactivar consentimiento'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return Colors.green;
      case 'pendiente':
        return Colors.grey;
      case 'baja':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  int _compareCofradesForAdminList(Cofrade a, Cofrade b) {
    final aNoNumber = a.numero == null;
    final bNoNumber = b.numero == null;
    if (aNoNumber != bNoNumber) return aNoNumber ? 1 : -1;
    if (a.numero != null && b.numero != null) {
      final byNumber = a.numero!.compareTo(b.numero!);
      if (byNumber != 0) return byNumber;
    }
    if (a.isBaja != b.isBaja) return a.isBaja ? 1 : -1;
    return a.nombreCompleto.compareTo(b.nombreCompleto);
  }

  String _tagLabel(String tagId) {
    return _tagNames[tagId] ??
        (tagId == 'faltan_datos' ? 'Faltan datos' : 'Tag eliminada');
  }

  Color _tagColor(String tagId) {
    return _parseColor(_tagColors[tagId] ?? '#607D8B');
  }

  bool _hasOpenConversation(String cofradeId) {
    return (_conversationsByCofrade[cofradeId] ?? const [])
        .any((conversation) => conversation['status'] != 'closed');
  }

  bool _hasPendingAdminConversation(String cofradeId) {
    return (_conversationsByCofrade[cofradeId] ?? const []).any((conversation) {
      if (conversation['status'] == 'closed') return false;
      final unread = conversation['unreadByAdmin'];
      final unreadCount = unread is num
          ? unread.toInt()
          : (unread == true ? 1 : int.tryParse('$unread') ?? 0);
      return conversation['status'] == 'pending_admin' || unreadCount > 0;
    });
  }

  bool _matchesAccessFilter(Cofrade cofrade) {
    final method = '${cofrade.rawData['lastLoginMethod'] ?? ''}'.toLowerCase();
    final hasLoggedIn = cofrade.rawData['hasLoggedIn'] == true ||
        cofrade.rawData['lastLoginAt'] != null ||
        ((cofrade.rawData['loginCount'] as num?)?.toInt() ?? 0) > 0;
    switch (_accessFilter) {
      case 'nunca':
        return !hasLoggedIn;
      case 'han_accedido':
        return hasLoggedIn;
      case 'reciente':
        final last = cofrade.rawData['lastLoginAt'];
        if (last is! Timestamp) return false;
        return DateTime.now().difference(last.toDate()).inDays <= 30;
      case 'google':
        return method == 'google';
      case 'password':
        return method == 'password';
      case 'dni':
        return method == 'dni';
      default:
        return true;
    }
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Map<String, List<Cofrade>> _sharedEmailMap(List<Cofrade> cofrades) {
    final map = <String, List<Cofrade>>{};
    for (final cofrade in cofrades) {
      final email = _normalizeEmail(cofrade.email);
      if (email.isEmpty) continue;
      map.putIfAbsent(email, () => <Cofrade>[]).add(cofrade);
    }
    map.removeWhere((_, value) => value.length < 2);
    return map;
  }

  bool _isConsentSigned(Cofrade cofrade) =>
      cofrade.gdprDigitalAccepted == true &&
      cofrade.gdprDigitalStatus != 'revoked' &&
      cofrade.gdprDigitalStatus != 'revocation_requested';

  bool _isConsentMissing(Cofrade cofrade) =>
      cofrade.gdprDigitalAccepted != true &&
      cofrade.gdprDigitalStatus != 'revoked' &&
      cofrade.gdprDigitalStatus != 'revocation_requested';

  bool _matchesConsentFilter(
    Cofrade cofrade,
    Map<String, List<Cofrade>> sharedByEmail,
  ) {
    switch (_consentFilter) {
      case 'signed':
        return _isConsentSigned(cofrade);
      case 'revocation_requested':
        return cofrade.gdprDigitalStatus == 'revocation_requested';
      case 'revoked':
        return cofrade.gdprDigitalStatus == 'revoked' ||
            cofrade.gdprDigitalRevoked;
      case 'missing':
        return _isConsentMissing(cofrade);
      case 'mixed_email':
        final peers = sharedByEmail[_normalizeEmail(cofrade.email)] ?? const [];
        if (peers.length < 2) return false;
        final statuses = peers.map(_consentStatusKey).toSet();
        return statuses.length > 1;
      default:
        return true;
    }
  }

  String _consentStatusKey(Cofrade cofrade) {
    if (cofrade.gdprDigitalStatus == 'revocation_requested') {
      return 'revocation_requested';
    }
    if (cofrade.gdprDigitalStatus == 'revoked' || cofrade.gdprDigitalRevoked) {
      return 'revoked';
    }
    if (_isConsentSigned(cofrade)) return 'signed';
    return 'missing';
  }

  String _consentStatusLabel(Cofrade cofrade) {
    switch (_consentStatusKey(cofrade)) {
      case 'revocation_requested':
        return 'Revocación pendiente';
      case 'revoked':
        return 'Revocado';
      case 'signed':
        return 'Firmado';
      default:
        return 'Sin consentimiento';
    }
  }

  Color _consentStatusColor(Cofrade cofrade) {
    switch (_consentStatusKey(cofrade)) {
      case 'revocation_requested':
        return Colors.orange.shade800;
      case 'revoked':
        return Colors.red.shade700;
      case 'signed':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  List<String> _missingRequiredLabels(Cofrade cofrade) {
    if (_fieldsConfig.isEmpty) return const [];
    return context
        .read<FirestoreService>()
        .getMissingRequiredFields(cofrade, _fieldsConfig)
        .map((field) => field.label)
        .toList();
  }

  String _dataQualityStatus(Cofrade cofrade) {
    final missing = _missingRequiredLabels(cofrade);
    if (missing.isEmpty) return 'COMPLETE';
    return 'INCOMPLETE';
  }

  Widget _buildOperationalPanel(List<Cofrade> cofrades) {
    final operative = cofrades.where((c) => c.isActivo).toList();
    final active = operative.length;
    final bajas = cofrades.where((c) => c.isBaja).length;
    final incomplete =
        operative.where((c) => _dataQualityStatus(c) != 'COMPLETE').length;
    final duplicates = _duplicateGroups(operative).length;
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _MiniKpi(label: 'Total', value: '${cofrades.length}'),
            _MiniKpi(label: 'Activos', value: '$active'),
            _MiniKpi(label: 'Baja', value: '$bajas'),
            _MiniKpi(label: 'Datos incompletos', value: '$incomplete'),
            _MiniKpi(label: 'Posibles duplicados', value: '$duplicates'),
            OutlinedButton.icon(
              onPressed: () => _showIncidenciasDialog(operative),
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Incidencias'),
            ),
            OutlinedButton.icon(
              onPressed: () => _exportCofrades(cofrades, excel: false),
              icon: const Icon(Icons.table_view),
              label: const Text('Exportar CSV'),
            ),
            OutlinedButton.icon(
              onPressed: () => _exportCofrades(cofrades, excel: true),
              icon: const Icon(Icons.grid_on),
              label: const Text('Exportar Excel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentAdminBanner(List<Cofrade> allCofrades) {
    final revoked = allCofrades
        .where((c) => c.gdprDigitalStatus == 'revoked' || c.gdprDigitalRevoked)
        .length;
    final pending = allCofrades
        .where((c) => c.gdprDigitalStatus == 'revocation_requested')
        .length;
    if (revoked == 0 && pending == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        color: Colors.orange.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.orange.shade200),
        ),
        child: ListTile(
          leading:
              Icon(Icons.privacy_tip_outlined, color: Colors.orange.shade800),
          title: Text(
            'Hay ${revoked + pending} cofrades con consentimiento revocado o pendiente de gestionar.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '$pending solicitud(es) de revocación pendiente(s) · $revoked consentimiento(s) revocado(s).',
          ),
          trailing: Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: pending == 0
                    ? null
                    : () => _updateFilters(
                        () => _consentFilter = 'revocation_requested'),
                child: const Text('Ver pendientes'),
              ),
              OutlinedButton(
                onPressed: revoked == 0
                    ? null
                    : () => _updateFilters(() => _consentFilter = 'revoked'),
                child: const Text('Ver revocados'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionsBar(List<Cofrade> visibleCofrades) {
    final selected = visibleCofrades
        .where((cofrade) => _selectedCofradeIds.contains(cofrade.id))
        .toList();
    return Card(
      elevation: 0,
      color: AppTheme.primaryColor.withAlpha(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${selected.length} seleccionados',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            OutlinedButton.icon(
              onPressed: () => setState(() => _selectedCofradeIds.clear()),
              icon: const Icon(Icons.close),
              label: const Text('Limpiar'),
            ),
            ElevatedButton.icon(
              onPressed: () => _bulkAssignTag(selected, remove: false),
              icon: const Icon(Icons.sell),
              label: const Text('Asignar tag'),
            ),
            OutlinedButton.icon(
              onPressed: () => _bulkAssignTag(selected, remove: true),
              icon: const Icon(Icons.sell_outlined),
              label: const Text('Quitar tag'),
            ),
            OutlinedButton.icon(
              onPressed: () => _bulkSendMessage(selected),
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Enviar mensaje'),
            ),
            OutlinedButton.icon(
              onPressed: () => _bulkRequestDataUpdate(selected),
              icon: const Icon(Icons.notification_important_outlined),
              label: const Text('Solicitar datos'),
            ),
            OutlinedButton.icon(
              onPressed: () => _bulkSetCuotaActiva(selected, true),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Activar cuota'),
            ),
            OutlinedButton.icon(
              onPressed: () => _bulkSetCuotaActiva(selected, false),
              icon: const Icon(Icons.money_off_outlined),
              label: const Text('Desactivar cuota'),
            ),
            OutlinedButton.icon(
              onPressed: () => _bulkMarkReview(selected),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Pendiente revisión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionControls(List<Cofrade> filteredCofrades) {
    final selectedVisible = filteredCofrades
        .where((cofrade) => _selectedCofradeIds.contains(cofrade.id))
        .length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: filteredCofrades.isEmpty
              ? null
              : () => setState(() {
                    _selectedCofradeIds
                      ..clear()
                      ..addAll(filteredCofrades.map((cofrade) => cofrade.id));
                  }),
          icon: const Icon(Icons.select_all),
          label: Text(
            'Seleccionar resultados filtrados (${filteredCofrades.length})',
          ),
        ),
        if (_selectedCofradeIds.isNotEmpty)
          TextButton.icon(
            onPressed: () => setState(() => _selectedCofradeIds.clear()),
            icon: const Icon(Icons.clear),
            label: Text('Deseleccionar todos ($selectedVisible visibles)'),
          ),
      ],
    );
  }

  Future<String?> _pickManualTag() async {
    final fs = context.read<FirestoreService>();
    final tags = await fs.getTagsConfig().first;
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Selecciona tag'),
        children: tags
            .where((tag) => tag.tipo == 'manual' && tag.activo)
            .map((tag) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, tag.id),
                  child: Text(tag.nombre),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _bulkAssignTag(List<Cofrade> cofrades,
      {required bool remove}) async {
    final tagId = await _pickManualTag();
    if (tagId == null) return;
    final fs = context.read<FirestoreService>();
    final confirm = await _confirmBulk(
      '${remove ? "Quitar" : "Asignar"} tag',
      '${remove ? "Quitar" : "Asignar"} "${_tagLabel(tagId)}" a ${cofrades.length} cofrades?',
    );
    if (confirm != true) return;
    for (final cofrade in cofrades) {
      final tags = cofrade.tagsManual.toSet();
      if (remove) {
        tags.remove(tagId);
      } else {
        tags.add(tagId);
      }
      await fs.updateCofradeManualTags(cofrade.id, tags.toList());
    }
    await fs.createAuditLog(
      action: remove ? 'bulk_manual_tag_removed' : 'bulk_manual_tag_assigned',
      targetId: 'bulk_cofrades',
      targetType: 'cofrade',
      targetNombre: 'Acción masiva',
      changedBy: context.read<AuthService>().cofrade?.id ?? 'admin',
      metadata: {'tagId': tagId, 'count': cofrades.length},
    );
    if (mounted) setState(() => _selectedCofradeIds.clear());
  }

  Future<void> _bulkSendMessage(List<Cofrade> cofrades) async {
    final subjectC = TextEditingController();
    final bodyC = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enviar mensaje a ${cofrades.length} cofrades'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: subjectC,
                decoration: const InputDecoration(labelText: 'Asunto')),
            TextField(
              controller: bodyC,
              decoration: const InputDecoration(labelText: 'Mensaje'),
              minLines: 3,
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                    'subject': subjectC.text.trim(),
                    'body': bodyC.text.trim(),
                  }),
              child: const Text('Enviar')),
        ],
      ),
    );
    if (result == null ||
        result['subject']!.isEmpty ||
        result['body']!.isEmpty) {
      return;
    }
    final fs = context.read<FirestoreService>();
    final actor = context.read<AuthService>().cofrade;
    for (final cofrade in cofrades) {
      await fs.startConversation(
        cofradeId: cofrade.id,
        cofradeName: cofrade.nombreCompleto,
        subject: result['subject']!,
        body: result['body']!,
        createdBy: actor?.id ?? 'admin',
        createdByRole: actor?.rol ?? 'admin',
      );
    }
    await fs.createAuditLog(
      action: 'bulk_message_sent',
      targetId: 'bulk_cofrades',
      targetType: 'conversation',
      targetNombre: 'Mensaje masivo',
      changedBy: actor?.id ?? 'admin',
      metadata: {'count': cofrades.length},
    );
    if (mounted) setState(() => _selectedCofradeIds.clear());
  }

  Future<void> _bulkRequestDataUpdate(List<Cofrade> cofrades) async {
    final confirm = await _confirmBulk(
      'Solicitar actualización de datos',
      'Se creará un aviso privado para ${cofrades.length} cofrades.',
    );
    if (confirm != true) return;
    final fs = context.read<FirestoreService>();
    final actor = context.read<AuthService>().cofrade;
    for (final cofrade in cofrades) {
      await fs.crearNovedad(
        tipo: 'datos_obligatorios_pendientes',
        titulo: 'Tienes datos obligatorios pendientes de completar',
        descripcion: _missingRequiredLabels(cofrade).isEmpty
            ? 'Revisa y actualiza tu perfil.'
            : 'Faltan: ${_missingRequiredLabels(cofrade).join(", ")}',
        referenciaId:
            'datos_${cofrade.id}_${DateTime.now().millisecondsSinceEpoch}',
        ruta: '/profile',
        visiblePara: 'cofrade',
        cofradeId: cofrade.id,
      );
    }
    await fs.createAuditLog(
      action: 'bulk_required_data_update_requested',
      targetId: 'bulk_cofrades',
      targetType: 'novedades',
      targetNombre: 'Solicitud masiva de datos',
      changedBy: actor?.id ?? 'admin',
      metadata: {'count': cofrades.length},
    );
    if (mounted) setState(() => _selectedCofradeIds.clear());
  }

  Future<void> _bulkSetCuotaActiva(List<Cofrade> cofrades, bool active) async {
    final confirm = await _confirmBulk(
      active ? 'Activar cuota' : 'Desactivar cuota',
      '${active ? "Activar" : "Desactivar"} cuota a ${cofrades.length} cofrades?',
    );
    if (confirm != true) return;
    final fs = context.read<FirestoreService>();
    final actor = context.read<AuthService>().cofrade;
    for (final cofrade in cofrades) {
      await fs.updateCofrade(
        cofrade.id,
        {'cuotaActiva': active, 'tiene_cuota': active},
        changedBy: actor?.id ?? 'admin',
        changedByRole: actor?.rol ?? 'admin',
      );
    }
    await fs.createAuditLog(
      action: 'bulk_cuota_status_updated',
      targetId: 'bulk_cofrades',
      targetType: 'cofrade',
      targetNombre: 'Cuota masiva',
      changedBy: actor?.id ?? 'admin',
      metadata: {'count': cofrades.length, 'active': active},
    );
    if (mounted) setState(() => _selectedCofradeIds.clear());
  }

  Future<void> _bulkMarkReview(List<Cofrade> cofrades) async {
    final confirm = await _confirmBulk(
      'Marcar pendiente revisión',
      'Marcar ${cofrades.length} cofrades como pendientes de revisión operativa?',
    );
    if (confirm != true) return;
    final fs = context.read<FirestoreService>();
    final actor = context.read<AuthService>().cofrade;
    for (final cofrade in cofrades) {
      await fs.updateCofrade(
        cofrade.id,
        {'needsReview': true, 'reviewMarkedAt': FieldValue.serverTimestamp()},
        changedBy: actor?.id ?? 'admin',
        changedByRole: actor?.rol ?? 'admin',
      );
    }
    await fs.createAuditLog(
      action: 'bulk_marked_pending_review',
      targetId: 'bulk_cofrades',
      targetType: 'cofrade',
      targetNombre: 'Pendiente revisión',
      changedBy: actor?.id ?? 'admin',
      metadata: {'count': cofrades.length},
    );
    if (mounted) setState(() => _selectedCofradeIds.clear());
  }

  Future<bool?> _confirmBulk(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
  }

  void _showIncidenciasDialog(List<Cofrade> cofrades) {
    final incomplete =
        cofrades.where((c) => _dataQualityStatus(c) != 'COMPLETE').toList();
    final gdprPending =
        cofrades.where((c) => !c.gdprDigitalAccepted && !c.gdprPapel).toList();
    final duplicateGroups = _duplicateGroups(cofrades);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Panel de incidencias'),
        content: SizedBox(
          width: 720,
          height: 520,
          child: ListView(
            children: [
              _IncidentSection(
                title: 'Datos incompletos',
                count: incomplete.length,
                children: incomplete
                    .map((c) => ListTile(
                          title: Text(c.nombreCompleto),
                          subtitle: Text(_missingRequiredLabels(c).join(', ')),
                          trailing: TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showCofrade360Dialog(c);
                            },
                            child: const Text('Resolver'),
                          ),
                        ))
                    .toList(),
              ),
              _IncidentSection(
                title: 'GDPR pendiente',
                count: gdprPending.length,
                children: gdprPending
                    .map((c) => ListTile(
                          title: Text(c.nombreCompleto),
                          subtitle: const Text('Sin GDPR papel ni digital'),
                        ))
                    .toList(),
              ),
              _IncidentSection(
                title: 'Posibles duplicados',
                count: duplicateGroups.length,
                children: duplicateGroups
                    .map((group) => ListTile(
                          title: Text(group.key),
                          subtitle: Text(group.value
                              .map((c) => c.nombreCompleto)
                              .join(' · ')),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  List<MapEntry<String, List<Cofrade>>> _duplicateGroups(
      List<Cofrade> cofrades) {
    final groups = <String, List<Cofrade>>{};
    void add(String key, Cofrade cofrade) {
      if (key.trim().isEmpty) return;
      groups.putIfAbsent(key, () => []).add(cofrade);
    }

    for (final c in cofrades) {
      add('DNI ${c.dni ?? ''}'.toUpperCase(), c);
      add('Email ${c.email}'.toLowerCase(), c);
      add('Tel ${c.telefonoMovil}', c);
      add('Nombre+nacimiento ${c.nombreCompleto.toLowerCase()} ${c.fechaNacimientoStr}',
          c);
    }
    return groups.entries.where((entry) => entry.value.length > 1).toList();
  }

  Future<void> _exportCofrades(List<Cofrade> cofrades,
      {required bool excel}) async {
    final selected = _selectedCofradeIds.isEmpty
        ? cofrades
        : cofrades
            .where((cofrade) => _selectedCofradeIds.contains(cofrade.id))
            .toList();
    final dynamicKeys = <String>{};
    for (final cofrade in selected) {
      dynamicKeys.addAll(cofrade.rawData.keys.map((key) => key.toString()));
    }
    final preferredKeys = [
      'id',
      'id_interno',
      'numero',
      'estado',
      'status',
      'isActive',
      'nombre',
      'apellidos',
      'dni',
      'genero',
      'fecha_nacimiento_str',
      'edad',
      'anio_alta',
      'anios_hermandad',
      'anio_mayordomia',
      'email',
      'email_secundario',
      'telefono_movil',
      'telefono_fijo',
      'telefono_secundario',
      'domicilio',
      'localidad',
      'codigo_postal',
      'tiene_cuota',
      'cuotaActiva',
      'cuota_domiciliada',
      'cuota_metalico',
      'iban',
      'titular_iban',
      'gdprPapel',
      'gdprFirmadoPapel',
      'gdprDigitalAccepted',
      'gdprDigitalStatus',
      'requiresDigitalTutor',
      'digitalTutorName',
      'digitalTutorDni',
      'digitalTutorPhone',
      'digitalTutorEmail',
      'digitalTutorRelationship',
      'tags_manual',
      'tags_auto',
      'fecha_creacion',
      'fecha_actualizacion',
      'bajaAt',
      'bajaReason',
      'reactivatedAt',
    ];
    final keys = [
      ...preferredKeys.where(dynamicKeys.contains),
      ...dynamicKeys.where((key) => !preferredKeys.contains(key)).toList()
        ..sort(),
    ];
    final rows = [
      ['documentId', 'calidad_datos', 'datos_faltantes', ...keys],
      ...selected.map((c) => [
            c.id,
            _dataQualityStatus(c),
            _missingRequiredLabels(c).join('|'),
            ...keys.map((key) => _exportValue(c.rawData[key])),
          ]),
    ];
    final separator = excel ? '\t' : ',';
    final content = rows
        .map((row) => row
            .map((value) => excel
                ? value.replaceAll('\t', ' ')
                : '"${value.replaceAll('"', '""')}"')
            .join(separator))
        .join('\n');
    final uri = Uri.dataFromString(
      content,
      mimeType: excel ? 'application/vnd.ms-excel' : 'text/csv',
      encoding: utf8,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _exportValue(Object? value) {
    if (value == null) return '';
    if (value is Timestamp) return _formatTimestamp(value);
    if (value is Iterable) return value.map(_exportValue).join('|');
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}:${_exportValue(entry.value)}')
          .join('|');
    }
    return '$value';
  }

  String _formatRawDate(Object? value) {
    if (value is Timestamp) return _formatTimestamp(value);
    return value == null ? '-' : '$value';
  }

  void _showCofrade360Dialog(Cofrade cofrade) {
    final missing = _missingRequiredLabels(cofrade);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Vista 360 · ${cofrade.nombreCompleto}'),
        content: SizedBox(
          width: 760,
          height: 620,
          child: ListView(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Estado: ${cofrade.estado}')),
                  Chip(label: Text('Nº ${cofrade.numero ?? "-"}')),
                  _DataQualityChip(
                    status: _dataQualityStatus(cofrade),
                    missing: missing,
                  ),
                  if (missing.isNotEmpty)
                    Chip(label: Text('Faltan: ${missing.length} campos')),
                ],
              ),
              const SizedBox(height: 12),
              _InfoSection(title: 'Datos personales', rows: {
                'ID': cofrade.id,
                'Nombre': cofrade.nombreCompleto,
                'DNI': cofrade.dni ?? '',
                'Email': cofrade.email,
                'Teléfono': cofrade.telefonoMovil,
                'Dirección': cofrade.domicilio,
                'Género': cofrade.genero ?? '',
              }),
              _InfoSection(title: 'Estado y cuota', rows: {
                'Estado': cofrade.estado,
                'Status acceso': cofrade.status,
                'Cuota activa': cofrade.cuotaActiva ? 'Sí' : 'No',
                'Domiciliada': cofrade.cuotaDomiciliada ? 'Sí' : 'No',
              }),
              _InfoSection(title: 'Acceso a la app', rows: {
                'Ha accedido':
                    cofrade.rawData['hasLoggedIn'] == true ? 'Sí' : 'No',
                'Primer acceso':
                    _formatRawDate(cofrade.rawData['firstLoginAt']),
                'Último acceso': _formatRawDate(cofrade.rawData['lastLoginAt']),
                'Nº accesos': '${cofrade.rawData['loginCount'] ?? 0}',
                'Último método': '${cofrade.rawData['lastLoginMethod'] ?? '-'}',
                'Proveedores':
                    _exportValue(cofrade.rawData['linkedAuthProviders']),
              }),
              _InfoSection(title: 'GDPR', rows: {
                'Papel': cofrade.gdprPapel ? 'Sí' : 'No',
                'Digital': cofrade.gdprDigitalAccepted ? 'Sí' : 'No',
                'Estado digital': cofrade.gdprDigitalStatus,
                'Fecha firma':
                    _formatRawDate(cofrade.rawData['gdprDigitalAcceptedAt']),
                'Solicitud revocación': _formatRawDate(
                    cofrade.rawData['gdprDigitalRevocationRequestedAt']),
                'Solicitada por':
                    '${cofrade.rawData['gdprDigitalRevocationRequestedBy'] ?? '-'}',
                'Fecha revocación':
                    _formatRawDate(cofrade.rawData['gdprDigitalRevokedAt']),
                'Versión': cofrade.gdprDigitalConsentVersion ?? '',
              }),
              _SharedEmailInfoSection(
                cofrade: cofrade,
                peers: _sharedEmailMap(
                      _lastAllCofrades,
                    )[_normalizeEmail(cofrade.email)] ??
                    const [],
                statusLabel: _consentStatusLabel,
              ),
              _InfoSection(title: 'Calidad de datos', rows: {
                'Estado': _dataQualityStatus(cofrade),
                'Faltan': missing.isEmpty ? 'Nada' : missing.join(', '),
              }),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditCofradeDialog(cofrade);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAdminConversationDialog(context, cofrade);
                    },
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('Mensajes'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCofradeAudit(context, cofrade);
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('Auditoría'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showCreateCofradeDialog(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final nombreC = TextEditingController();
    final apellidosC = TextEditingController();
    final emailC = TextEditingController();
    final telefonoC = TextEditingController();
    final dniC = TextEditingController();
    final nacimientoC = TextEditingController();
    var estado = 'Activo';
    var rol = 'cofrade';
    final dynamicValues = <String, dynamic>{};
    List<CofradeFieldConfig> latestFields = const [];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuevo cofrade'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreC,
                    decoration: const InputDecoration(labelText: 'Nombre *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: apellidosC,
                    decoration: const InputDecoration(labelText: 'Apellidos *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: dniC,
                    decoration: const InputDecoration(labelText: 'DNI'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailC,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: telefonoC,
                    decoration:
                        const InputDecoration(labelText: 'Teléfono móvil'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nacimientoC,
                    decoration: const InputDecoration(
                        labelText: 'Fecha nacimiento dd/MM/yyyy'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: estado,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'Activo', child: Text('Activo')),
                      DropdownMenuItem(value: 'Baja', child: Text('Baja')),
                      DropdownMenuItem(
                          value: 'Pendiente', child: Text('Pendiente')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => estado = value ?? 'Activo'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: rol,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: const [
                      DropdownMenuItem(
                          value: 'cofrade', child: Text('Cofrade')),
                      DropdownMenuItem(value: 'junta', child: Text('Junta')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => rol = value ?? 'cofrade'),
                  ),
                  const Divider(height: 28),
                  StreamBuilder<List<CofradeFieldConfig>>(
                    stream: fs.getCofradeFieldsConfig(),
                    builder: (context, snapshot) {
                      latestFields =
                          (snapshot.data ?? const <CofradeFieldConfig>[])
                              .where((field) =>
                                  field.active &&
                                  field.visibleInAdmin &&
                                  field.editableByAdmin)
                              .toList();
                      if (latestFields.isEmpty) {
                        return const Text(
                            'Configura los campos para mostrar el formulario completo.');
                      }
                      return Column(
                        children: latestFields.map((field) {
                          if (field.type == 'boolean') {
                            return SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  '${field.label}${field.required ? " *" : ""}'),
                              value: dynamicValues[field.fieldKey] == true,
                              onChanged: (value) => setDialogState(
                                  () => dynamicValues[field.fieldKey] = value),
                            );
                          }
                          if (field.type == 'select' &&
                              field.options.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: DropdownButtonFormField<String>(
                                initialValue:
                                    dynamicValues[field.fieldKey]?.toString(),
                                decoration: InputDecoration(
                                  labelText:
                                      '${field.label}${field.required ? " *" : ""}',
                                ),
                                items: field.options
                                    .map((option) => DropdownMenuItem(
                                          value: option,
                                          child: Text(option),
                                        ))
                                    .toList(),
                                onChanged: (value) => setDialogState(() =>
                                    dynamicValues[field.fieldKey] =
                                        value ?? ''),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextFormField(
                              initialValue:
                                  dynamicValues[field.fieldKey]?.toString() ??
                                      '',
                              keyboardType: field.type == 'number'
                                  ? TextInputType.number
                                  : TextInputType.text,
                              decoration: InputDecoration(
                                labelText:
                                    '${field.label}${field.required ? " *" : ""}',
                              ),
                              onChanged: (value) {
                                dynamicValues[field.fieldKey] =
                                    field.type == 'number'
                                        ? int.tryParse(value.trim())
                                        : value.trim();
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
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
                if (nombreC.text.trim().isEmpty ||
                    apellidosC.text.trim().isEmpty) {
                  return;
                }
                final missingRequired = latestFields.where((field) {
                  if (!field.required) return false;
                  final value = dynamicValues[field.fieldKey];
                  if (value == null) return true;
                  if (value is String) return value.trim().isEmpty;
                  if (field.fieldKey == 'gdpr_firmado' && value is bool) {
                    return !value;
                  }
                  return false;
                }).toList();
                if (missingRequired.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Faltan campos obligatorios: ${missingRequired.map((e) => e.label).join(", ")}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final baseData = <String, dynamic>{
                    ...dynamicValues,
                    'nombre': nombreC.text.trim(),
                    'apellidos': apellidosC.text.trim(),
                    'dni': dniC.text.trim().toUpperCase(),
                    'dni_normalizado': dniC.text
                        .toUpperCase()
                        .replaceAll(RegExp(r'[\s\-_.]'), ''),
                    'email': emailC.text.trim(),
                    'telefono_movil': telefonoC.text.trim(),
                    'fecha_nacimiento_str': nacimientoC.text.trim(),
                    'estado': estado,
                    'rol': rol,
                    'role': rol,
                    'roles': ['cofrade'],
                    'tiene_cuota': false,
                    'cuota_domiciliada': false,
                    'cuota_metalico': false,
                    'gdpr_firmado': false,
                    'notificaciones_activas': true,
                    'tiene_tunica_propia': false,
                    'tutelado_digital': false,
                    'requiresDigitalTutor': false,
                    'digitalTutorConsentAccepted': false,
                  };
                  final id = await fs.createCofradeForAdmin(baseData);
                  await fs.createWelcomeNovedadForCofrade(id);
                  if (ctx.mounted) navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Cofrade creado: $id')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error creando cofrade: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTagsManagement(BuildContext context) {
    final fs = context.read<FirestoreService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gestión de tags'),
        content: SizedBox(
          width: 720,
          child: StreamBuilder<List<TagConfig>>(
            stream: fs.getTagsConfig(),
            builder: (context, snapshot) {
              final tags = snapshot.data ?? const <TagConfig>[];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showTagDialog(ctx),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear tag'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => fs.seedDefaultManualTags(),
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Crear sugeridos'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => fs.recomputeAutomaticTags(),
                        icon: const Icon(Icons.sync),
                        label: const Text('Recalcular automáticos'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 430,
                    child: tags.isEmpty
                        ? const Center(child: Text('No hay tags configurados.'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: tags.length,
                            itemBuilder: (context, index) {
                              final tag = tags[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _parseColor(tag.color),
                                  child: Icon(
                                    tag.tipo == 'automatico'
                                        ? Icons.bolt
                                        : Icons.sell,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(tag.nombre),
                                subtitle:
                                    Text('${tag.tipo} · ${tag.descripcion}'),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    FutureBuilder<int>(
                                      future: fs.countCofradesWithTag(tag.id),
                                      builder: (context, snap) => Chip(
                                          label: Text('${snap.data ?? 0}')),
                                    ),
                                    Switch(
                                      value: tag.activo,
                                      onChanged: (value) =>
                                          fs.toggleTagConfig(tag.id, value),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () =>
                                          _showTagDialog(ctx, tag: tag),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Eliminar tag',
                                      onPressed: () =>
                                          _confirmDeleteTag(ctx, tag),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showTagDialog(BuildContext context, {TagConfig? tag}) {
    final fs = context.read<FirestoreService>();
    final nombreC = TextEditingController(text: tag?.nombre ?? '');
    final descripcionC = TextEditingController(text: tag?.descripcion ?? '');
    final colorC = TextEditingController(text: tag?.color ?? '#607D8B');
    final rawConditions =
        tag?.criterio['conditions'] ?? tag?.criterio['condiciones'];
    final conditions = rawConditions is List
        ? rawConditions
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : [
            if ((tag?.criterio['campo'] ?? '').toString().isNotEmpty)
              Map<String, dynamic>.from(tag!.criterio)
            else
              {'campo': '', 'operador': '>=', 'valor': ''}
          ];
    var tipo = tag?.tipo ?? 'manual';
    var activo = tag?.activo ?? true;
    var showInPrivateProfile = tag?.showInPrivateProfile ?? false;
    var combinator =
        '${tag?.criterio['combinator'] ?? tag?.criterio['combinador'] ?? 'AND'}';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(tag == null ? 'Crear tag' : 'Editar tag'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreC,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descripcionC,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: colorC,
                    decoration: InputDecoration(
                      labelText: 'Color hex',
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(8),
                        child: CircleAvatar(
                          backgroundColor: _parseColor(colorC.text),
                        ),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      '#607D8B',
                      '#D97706',
                      '#15803D',
                      '#2563EB',
                      '#7C3AED',
                      '#BE123C',
                      '#0F766E',
                    ]
                        .map((hex) => InkWell(
                              onTap: () => setDialogState(() {
                                colorC.text = hex;
                              }),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: _parseColor(hex),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tipo,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'manual', child: Text('Manual')),
                      DropdownMenuItem(
                          value: 'automatico', child: Text('Automático')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => tipo = value ?? 'manual'),
                  ),
                  if (tipo == 'automatico') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: combinator,
                      decoration:
                          const InputDecoration(labelText: 'Combinar con'),
                      items: const [
                        DropdownMenuItem(value: 'AND', child: Text('AND')),
                        DropdownMenuItem(value: 'OR', child: Text('OR')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => combinator = value ?? 'AND'),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<CofradeFieldConfig>>(
                      stream: fs.getCofradeFieldsConfig(),
                      builder: (context, snapshot) {
                        final fields =
                            snapshot.data ?? const <CofradeFieldConfig>[];
                        const computed = [
                          ['anio_alta', 'Año de alta'],
                          ['anio_mayordomia', 'Año de mayordomía'],
                          ['edad', 'Edad'],
                          ['anios_hermandad', 'Años en la hermandad'],
                          ['genero', 'Género'],
                          ['estado', 'Estado'],
                          ['cuotaActiva', 'Cuota activa'],
                          ['gdprPapel', 'GDPR papel'],
                          ['gdprDigitalAccepted', 'GDPR digital'],
                          ['requiresDigitalTutor', 'Requiere tutela digital'],
                          ['tiene_tunica_propia', 'Tiene túnica propia'],
                          [
                            'tiene_datos_obligatorios_pendientes',
                            'Tiene datos obligatorios pendientes'
                          ],
                          ['numero', 'Número de cofrade'],
                          ['es_baja', 'Es baja'],
                          ['es_activo', 'Es activo'],
                          ['tiene_iban', 'Tiene IBAN'],
                          ['tiene_email', 'Tiene email'],
                          ['tiene_telefono_movil', 'Tiene teléfono móvil'],
                        ];
                        final fieldItems = [
                          ...fields.where((field) => field.active).map(
                                (field) => DropdownMenuItem<String>(
                                  value: field.fieldKey,
                                  child: Text(field.label),
                                ),
                              ),
                          ...computed.map((field) => DropdownMenuItem<String>(
                                value: field[0],
                                child: Text('${field[1]} · calculado'),
                              )),
                        ];
                        return Column(
                          children: [
                            ...conditions.asMap().entries.map((entry) {
                              final index = entry.key;
                              final condition = entry.value;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      DropdownButtonFormField<String>(
                                        initialValue:
                                            '${condition['campo']}'.isEmpty
                                                ? null
                                                : '${condition['campo']}',
                                        decoration: const InputDecoration(
                                            labelText: 'Campo'),
                                        items: fieldItems,
                                        onChanged: (value) => setDialogState(
                                            () => condition['campo'] = value),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        initialValue:
                                            '${condition['operador'] ?? '=='}',
                                        decoration: const InputDecoration(
                                            labelText: 'Operador'),
                                        items: const [
                                          DropdownMenuItem(
                                              value: '==',
                                              child: Text('Igual a')),
                                          DropdownMenuItem(
                                              value: '!=',
                                              child: Text('Distinto de')),
                                          DropdownMenuItem(
                                              value: '<', child: Text('<')),
                                          DropdownMenuItem(
                                              value: '<=', child: Text('<=')),
                                          DropdownMenuItem(
                                              value: '>', child: Text('>')),
                                          DropdownMenuItem(
                                              value: '>=', child: Text('>=')),
                                          DropdownMenuItem(
                                              value: 'contains',
                                              child: Text('Contiene')),
                                          DropdownMenuItem(
                                              value: 'empty',
                                              child: Text('Está vacío')),
                                          DropdownMenuItem(
                                              value: 'not_empty',
                                              child: Text('No está vacío')),
                                        ],
                                        onChanged: (value) => setDialogState(
                                            () => condition['operador'] =
                                                value ?? '=='),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        initialValue:
                                            '${condition['valor'] ?? ''}',
                                        decoration: const InputDecoration(
                                            labelText: 'Valor'),
                                        onChanged: (value) =>
                                            condition['valor'] = value,
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: IconButton(
                                          onPressed: conditions.length == 1
                                              ? null
                                              : () => setDialogState(() =>
                                                  conditions.removeAt(index)),
                                          icon:
                                              const Icon(Icons.delete_outline),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => setDialogState(() => conditions
                                        .add({
                                      'campo': '',
                                      'operador': '==',
                                      'valor': ''
                                    })),
                                icon: const Icon(Icons.add),
                                label: const Text('Añadir condición'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar en perfil privado'),
                    value: showInPrivateProfile,
                    onChanged: (value) =>
                        setDialogState(() => showInPrivateProfile = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activo'),
                    value: activo,
                    onChanged: (value) => setDialogState(() => activo = value),
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
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);
                if (nombreC.text.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('El nombre del tag es obligatorio.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final hex = colorC.text.trim();
                if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('El color debe tener formato #RRGGBB.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final criterio = tipo == 'automatico'
                    ? {
                        'combinator': combinator,
                        'conditions': conditions
                            .map((condition) => {
                                  'campo': '${condition['campo'] ?? ''}',
                                  'operador':
                                      '${condition['operador'] ?? '=='}',
                                  'valor': num.tryParse(
                                          '${condition['valor'] ?? ''}'
                                              .trim()) ??
                                      '${condition['valor'] ?? ''}'.trim(),
                                })
                            .toList(),
                      }
                    : <String, dynamic>{};
                try {
                  await fs.saveTagConfig(TagConfig(
                    id: tag?.id ?? '',
                    nombre: nombreC.text.trim(),
                    descripcion: descripcionC.text.trim(),
                    tipo: tipo,
                    color: colorC.text.trim(),
                    activo: activo,
                    showInPrivateProfile: showInPrivateProfile,
                    criterio: criterio,
                  ));
                  if (ctx.mounted) navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('Tag guardado correctamente.')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error guardando tag: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTag(BuildContext context, TagConfig tag) async {
    final fs = context.read<FirestoreService>();
    final count = await fs.countCofradesWithTag(tag.id);
    if (!context.mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar tag "${tag.nombre}"'),
        content: Text(
          count > 0
              ? 'Esta tag está asociada a $count cofrades. Si la eliminas, se eliminará también su asociación.'
              : 'La tag se eliminará del catálogo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final auth = context.read<AuthService>();
      await fs.deleteTagConfig(
        tag.id,
        changedBy: auth.cofrade?.id ?? 'system',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tag eliminada correctamente.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar la tag.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _parseColor(String value) {
    final hex = value.replaceAll('#', '').trim();
    final parsed = int.tryParse('FF$hex', radix: 16);
    return Color(parsed ?? 0xFF607D8B);
  }

  void _showFieldsConfig(BuildContext context) {
    final fs = context.read<FirestoreService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configuración de campos'),
        content: SizedBox(
          width: 760,
          child: StreamBuilder<List<CofradeFieldConfig>>(
            stream: fs.getCofradeFieldsConfig(),
            builder: (context, snapshot) {
              final fields = snapshot.data ?? const <CofradeFieldConfig>[];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showFieldConfigDialog(ctx),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear campo'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => fs.seedDefaultCofradeFieldsConfig(),
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Crear campos base'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 430,
                    child: fields.isEmpty
                        ? const Center(
                            child: Text('No hay campos configurados.'))
                        : ListView.builder(
                            itemCount: fields.length,
                            itemBuilder: (context, index) {
                              final field = fields[index];
                              return ListTile(
                                leading: Icon(field.required
                                    ? Icons.star
                                    : Icons.short_text),
                                title: Text(field.label),
                                subtitle: Text(
                                    '${field.fieldKey} · ${field.type} · ${field.active ? "activo" : "inactivo"}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _showFieldConfigDialog(ctx, field: field),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showFieldConfigDialog(BuildContext context,
      {CofradeFieldConfig? field}) {
    final fs = context.read<FirestoreService>();
    final keyC = TextEditingController(text: field?.fieldKey ?? '');
    final labelC = TextEditingController(text: field?.label ?? '');
    final optionsC =
        TextEditingController(text: field?.options.join(', ') ?? '');
    var type = field?.type ?? 'string';
    var required = field?.required ?? false;
    var editableByCofrade = field?.editableByCofrade ?? true;
    var visibleInPrivate = field?.visibleInPrivateProfile ?? true;
    var active = field?.active ?? true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(field == null ? 'Crear campo' : 'Editar campo'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: keyC,
                    enabled: field == null,
                    decoration:
                        const InputDecoration(labelText: 'Clave Firestore'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: labelC,
                    decoration: const InputDecoration(labelText: 'Etiqueta'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'string', child: Text('Texto')),
                      DropdownMenuItem(value: 'number', child: Text('Número')),
                      DropdownMenuItem(
                          value: 'boolean', child: Text('Booleano')),
                      DropdownMenuItem(value: 'date', child: Text('Fecha')),
                      DropdownMenuItem(
                          value: 'select', child: Text('Selector')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => type = value ?? 'string'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: optionsC,
                    decoration: const InputDecoration(
                        labelText: 'Opciones separadas por coma'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Obligatorio'),
                    value: required,
                    onChanged: (value) =>
                        setDialogState(() => required = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Editable por cofrade'),
                    value: editableByCofrade,
                    onChanged: (value) =>
                        setDialogState(() => editableByCofrade = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Visible en perfil privado'),
                    value: visibleInPrivate,
                    onChanged: (value) =>
                        setDialogState(() => visibleInPrivate = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activo'),
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
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
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);
                try {
                  await fs.saveCofradeFieldConfig(CofradeFieldConfig(
                    id: field?.id ?? '',
                    fieldKey: keyC.text.trim(),
                    label: labelC.text.trim(),
                    type: type,
                    required: required,
                    editableByCofrade: editableByCofrade,
                    visibleInPrivateProfile: visibleInPrivate,
                    visibleInAdmin: true,
                    options: optionsC.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                    active: active,
                    order: field?.order ?? 0,
                  ));
                  if (ctx.mounted) navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Campo guardado.')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error guardando campo: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoleAudit(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final changedBy = context.read<AuthService>().cofrade?.id ?? 'unknown';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seguridad y permisos'),
        content: SizedBox(
          width: 760,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Administra roles y permisos por módulo. '
                      'El Administrador Sistema es inmutable desde la UI.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddRoleUserDialog(ctx),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Añadir usuario'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 420,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: fs.watchRoleAuditEntries(),
                  builder: (context, snapshot) {
                    final rows =
                        snapshot.data ?? const <Map<String, dynamic>>[];
                    if (rows.isEmpty) {
                      return const Center(
                          child: Text('No hay roles especiales configurados.'));
                    }
                    return ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final roles = (row['roles'] as List?) ?? const [];
                        final isService = row['es_cuenta_servicio'] == true;
                        return ListTile(
                          leading: Icon(isService
                              ? Icons.settings_applications
                              : Icons.security),
                          title: Text(
                              '${row['nombre'] ?? ''} ${row['apellidos'] ?? ''}'),
                          subtitle: Text(
                              '${row['id']} · rol=${row['rol'] ?? "cofrade"} · roles=${roles.join(", ")}'),
                          trailing: isService
                              ? const Chip(label: Text('Inmutable'))
                              : IconButton(
                                  icon: const Icon(Icons.tune),
                                  onPressed: () {
                                    fs
                                        .getCofrade('${row['id']}')
                                        .then((cofrade) {
                                      if (!mounted || cofrade == null) return;
                                      _showPermissionsDialog(
                                        this.context,
                                        cofrade,
                                        changedBy,
                                      );
                                    });
                                  },
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showCofradeAudit(BuildContext context, Cofrade cofrade) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Auditoría · ${cofrade.nombreCompleto}'),
        content: SizedBox(
          width: 700,
          height: 420,
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('audit_logs')
                .where('target_id', isEqualTo: cofrade.id)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                    'No se ha podido cargar la auditoría en este momento.');
              }
              final docs = [...(snapshot.data?.docs ?? [])];
              docs.sort((a, b) {
                final at = a.data()['changed_at'];
                final bt = b.data()['changed_at'];
                if (at is Timestamp && bt is Timestamp) {
                  return bt.compareTo(at);
                }
                return 0;
              });
              if (docs.isEmpty) {
                return const Center(child: Text('Sin auditoría registrada.'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(_humanAuditAction('${data['action'] ?? ''}')),
                    subtitle: Text(
                      'Por ${data['changed_by'] ?? '-'} · ${_formatAuditDate(data['changed_at'])}',
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _humanAuditAction(String action) {
    const labels = {
      'private_document_deleted': 'Documento particular eliminado',
      'private_document_uploaded': 'Documento particular subido',
      'gdpr_document_uploaded': 'Documento GDPR subido',
      'gdpr_document_replaced': 'Documento GDPR sustituido',
      'gdpr_document_deleted': 'Documento GDPR eliminado',
      'google_login': 'Acceso mediante Google',
      'conversation_closed': 'Conversación cerrada',
      'conversation_reopened': 'Conversación reabierta',
      'private_conversation_message_sent': 'Mensaje enviado',
      'private_conversation_started': 'Conversación iniciada',
      'cofrade_field_updated': 'Datos del cofrade actualizados',
      'cofrade_deactivated': 'Cofrade dado de baja',
      'cofrade_reactivated_previous_number':
          'Cofrade reactivado con número anterior',
      'cofrade_reactivated_new_number': 'Cofrade reactivado con nuevo número',
      'auto_tags_recalculated': 'Tags automáticas recalculadas',
      'auth_profile_selected': 'Perfil seleccionado al acceder',
    };
    return labels[action] ??
        action
            .replaceAll('_', ' ')
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(' ');
  }

  String _formatAuditDate(Object? value) {
    if (value is Timestamp) return _formatTimestamp(value);
    return '-';
  }

  String _formatTimestamp(Timestamp value) {
    final date = value.toDate();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  static const _adminModules = [
    'cofrades',
    'solicitudes',
    'tesoreria',
    'loteria',
    'tunicas',
    'festividad',
    'tags',
    'campos_configurables',
    'seguridad_roles',
    'novedades',
    'proveedores',
    'tablon',
  ];

  static const _availableRoles = [
    'Admin',
    'Junta',
    'Tesorería',
    'Secretario',
  ];

  void _showAddRoleUserDialog(BuildContext context) {
    final fs = context.read<FirestoreService>();
    var search = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Añadir usuario a roles'),
          content: SizedBox(
            width: 640,
            height: 480,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText:
                        'Buscar por nombre, apellidos, número, email o teléfono',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setDialogState(() => search = value.toLowerCase()),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<Cofrade>>(
                    stream: fs.watchAllCofradesForAdmin(),
                    builder: (context, snapshot) {
                      final rows = (snapshot.data ?? [])
                          .where((c) =>
                              !c.esCuentaServicio &&
                              !c.id.startsWith('ADM-') &&
                              [
                                c.nombre,
                                c.apellidos,
                                c.nombreCompleto,
                                c.numero?.toString() ?? '',
                                c.email,
                                c.telefonoMovil,
                              ].join(' ').toLowerCase().contains(search))
                          .toList()
                        ..sort(_compareCofradesForAdminList);
                      return ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final cofrade = rows[index];
                          return ListTile(
                            title: Text(cofrade.nombreCompleto),
                            subtitle: Text(
                                'Nº ${cofrade.numero ?? "-"} · ${cofrade.email}'),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showPermissionsDialog(
                                context,
                                cofrade,
                                context.read<AuthService>().cofrade?.id ??
                                    'unknown',
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionsDialog(
    BuildContext context,
    Cofrade cofrade,
    String changedBy,
  ) {
    final fs = context.read<FirestoreService>();
    final actorRole = context.read<AuthService>().cofrade?.rol ?? 'admin';
    final roles =
        cofrade.roles.where((role) => role.toLowerCase() != 'cofrade').toSet();
    final permissions = <String, Map<String, bool>>{};
    for (final module in _adminModules) {
      final existing =
          (cofrade.adminPermissions[module] as Map?)?.cast<String, dynamic>();
      permissions[module] = {
        'read': existing?['read'] == true,
        'write': existing?['write'] == true,
      };
    }
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Permisos · ${cofrade.nombreCompleto}'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: _availableRoles.map((role) {
                      final selected = roles.contains(role);
                      return FilterChip(
                        label: Text(role),
                        selected: selected,
                        onSelected: (value) => setDialogState(() {
                          if (value) {
                            roles.add(role);
                          } else {
                            roles.remove(role);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 28),
                  ..._adminModules.map((module) {
                    final value = permissions[module]!;
                    return Row(
                      children: [
                        Expanded(child: Text(module)),
                        Checkbox(
                          value: value['read'],
                          onChanged: (checked) => setDialogState(() {
                            final next = checked ?? false;
                            value['read'] = next;
                            if (!next) value['write'] = false;
                          }),
                        ),
                        const Text('Leer'),
                        Checkbox(
                          value: value['write'],
                          onChanged: (checked) => setDialogState(() {
                            final next = checked ?? false;
                            value['write'] = next;
                            if (next) value['read'] = true;
                          }),
                        ),
                        const Text('Editar'),
                        const Tooltip(
                          message: 'Editar incluye permiso de lectura',
                          child: Icon(Icons.info_outline, size: 16),
                        ),
                      ],
                    );
                  }),
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
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await fs.updateRolesAndPermissions(
                    cofrade: cofrade,
                    roles: roles.toList()..sort(),
                    permissions: permissions,
                    changedBy: changedBy,
                    changedByRole: actorRole,
                  );
                  if (ctx.mounted) navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Permisos actualizados.')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error actualizando permisos: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askBajaCause(BuildContext context, Cofrade cofrade) async {
    final controller = TextEditingController();
    final fs = context.read<FirestoreService>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dar de baja'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Causa de baja'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: fs.previewBajaNumbering(cofrade.id),
                builder: (context, snapshot) {
                  final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (rows.isEmpty) {
                    return const Text(
                      'No hay cofrades posteriores que recalcular.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    );
                  }
                  return SizedBox(
                    height: 180,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Se recalcularán ${rows.length} números:'),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView(
                            children: rows
                                .take(20)
                                .map((row) => Text(
                                      '${row['nombre']} · ${row['oldNumber']} → ${row['newNumber']}',
                                      style: const TextStyle(fontSize: 12),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
              final cause = controller.text.trim();
              if (cause.isEmpty) return;
              Navigator.pop(ctx, cause);
            },
            child: const Text('Confirmar baja'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _askReactivationMode(
    BuildContext context,
    Cofrade cofrade,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cómo quieres reactivar este cofrade?'),
        content: Text(
          'Número anterior registrado: ${cofrade.numeroAnterior ?? "-"}. '
          'Puedes recuperar su número anterior o asignarle el siguiente número libre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Recuperar número anterior'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Asignar nuevo número'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminGdprDocumentationBlock(Cofrade cofrade) {
    final fs = context.read<FirestoreService>();
    final actor = context.read<AuthService>().cofrade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documentación GDPR',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<Map<String, dynamic>?>(
          stream: fs.watchGdprPaperDocument(cofrade.id),
          builder: (context, snapshot) {
            final doc = snapshot.data;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(doc == null
                      ? 'No consta GDPR en papel'
                      : 'Consta GDPR en papel'),
                  backgroundColor: (doc == null ? Colors.orange : Colors.green)
                      .withAlpha(24),
                  labelStyle: TextStyle(
                    color: doc == null
                        ? Colors.orange.shade800
                        : Colors.green.shade800,
                  ),
                ),
                if (doc != null &&
                    (doc['downloadUrl'] ?? '').toString().isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await fs.createAuditLog(
                        action: 'gdpr_document_viewed_by_admin',
                        targetId: cofrade.id,
                        targetType: 'cofrade',
                        targetNombre: cofrade.nombreCompleto,
                        changedBy: actor?.id ?? 'admin',
                        metadata: {'document_id': doc['id']},
                      );
                      try {
                        final storagePath = '${doc['storagePath'] ?? ''}';
                        final url = storagePath.isNotEmpty
                            ? await context
                                .read<StorageService>()
                                .getDownloadUrlFromPath(storagePath)
                            : '${doc['downloadUrl']}';
                        await launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'No se ha podido abrir el documento por permisos.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ver'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _uploadAdminGdprDocument(cofrade),
                  icon: const Icon(Icons.upload_file),
                  label: Text(doc == null ? 'Subir GDPR' : 'Sustituir GDPR'),
                ),
                if (doc != null)
                  TextButton.icon(
                    onPressed: () async {
                      await fs.deleteGdprPaperDocument(
                        cofradeId: cofrade.id,
                        documentId: '${doc['id']}',
                        performedBy: actor?.id ?? 'admin',
                      );
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _uploadAdminGdprDocument(Cofrade cofrade) async {
    final storage = context.read<StorageService>();
    final fs = context.read<FirestoreService>();
    final actor = context.read<AuthService>().cofrade;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (picked == null || picked.files.single.bytes == null) return;
    try {
      final uploaded = await storage.uploadFile(
        path: 'cofrades/${cofrade.id}/documents/gdpr',
        bytes: picked.files.single.bytes!,
        fileName: picked.files.single.name,
        allowedExtensions: {'pdf', 'jpg', 'jpeg', 'png'},
        maxSizeBytes: 10 * 1024 * 1024,
      );
      await fs.saveGdprPaperDocument(
        cofradeId: cofrade.id,
        upload: uploaded,
        performedBy: actor?.id ?? 'admin',
        source: 'admin_panel',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento GDPR actualizado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error subiendo GDPR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAdminPrivateDocumentsBlock(Cofrade cofrade) {
    final fs = context.read<FirestoreService>();
    final actor = context.read<AuthService>().cofrade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Documentos particulares',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: fs.watchPrivateDocuments(cofrade.id),
          builder: (context, snapshot) {
            final docs = snapshot.data ?? const <Map<String, dynamic>>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (docs.isEmpty)
                  const Text('No hay documentos particulares activos.'),
                ...docs.map((doc) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text('${doc['title'] ?? doc['fileName'] ?? ''}'),
                      subtitle: Text(
                          '${doc['type'] ?? 'Otro'} · ${doc['visibleToCofrade'] == true ? 'Visible para el cofrade' : 'Solo administración'}'),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          if ((doc['downloadUrl'] ?? '').toString().isNotEmpty)
                            IconButton(
                              tooltip: 'Ver',
                              onPressed: () => launchUrl(
                                Uri.parse('${doc['downloadUrl']}'),
                                mode: LaunchMode.externalApplication,
                              ),
                              icon: const Icon(Icons.open_in_new),
                            ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () => fs.deletePrivateDocument(
                              cofradeId: cofrade.id,
                              documentId: '${doc['id']}',
                              performedBy: actor?.id ?? 'admin',
                            ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _uploadAdminPrivateDocument(cofrade),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Subir documento particular'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _uploadAdminPrivateDocument(Cofrade cofrade) async {
    final titleController = TextEditingController();
    final commentsController = TextEditingController();
    var type = 'Otro';
    var visibleToCofrade = true;
    final config = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Documento particular'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  'GDPR',
                  'DNI',
                  'Autorización',
                  'Justificante',
                  'Otro'
                ]
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => type = value ?? 'Otro'),
              ),
              SwitchListTile(
                value: visibleToCofrade,
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible para el cofrade'),
                onChanged: (value) =>
                    setDialogState(() => visibleToCofrade = value),
              ),
              TextField(
                controller: commentsController,
                decoration:
                    const InputDecoration(labelText: 'Comentarios internos'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, {
                      'title': titleController.text.trim(),
                      'type': type,
                      'visibleToCofrade': visibleToCofrade,
                      'comments': commentsController.text.trim(),
                    }),
                child: const Text('Elegir archivo')),
          ],
        ),
      ),
    );
    if (config == null) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
      withData: true,
    );
    if (picked == null || picked.files.single.bytes == null) return;
    try {
      final storage = context.read<StorageService>();
      final fs = context.read<FirestoreService>();
      final actor = context.read<AuthService>().cofrade;
      final uploaded = await storage.uploadFile(
        path: 'cofrades/${cofrade.id}/documents/private',
        bytes: picked.files.single.bytes!,
        fileName: picked.files.single.name,
        allowedExtensions: {'pdf', 'jpg', 'jpeg', 'png', 'docx'},
        maxSizeBytes: 15 * 1024 * 1024,
      );
      await fs.savePrivateDocument(
        cofradeId: cofrade.id,
        upload: uploaded,
        title: '${config['title']}',
        type: '${config['type']}',
        visibleToCofrade: config['visibleToCofrade'] == true,
        comments: '${config['comments']}',
        performedBy: actor?.id ?? 'admin',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento particular subido.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error subiendo documento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditCofradeDialog(Cofrade cofrade) {
    context
        .read<FirestoreService>()
        .syncGdprPaperStatus(
          cofradeId: cofrade.id,
          changedBy: context.read<AuthService>().cofrade?.id ?? 'admin',
        )
        .catchError((error) {
      debugPrint('[AdminCofrades] GDPR sync before edit failed: $error');
    });
    final nombreC = TextEditingController(text: cofrade.nombre);
    final apellidosC = TextEditingController(text: cofrade.apellidos);
    final emailC = TextEditingController(text: cofrade.email);
    final emailSecC =
        TextEditingController(text: cofrade.emailSecundario ?? '');
    final dniC = TextEditingController(text: cofrade.dni ?? '');
    final telefonoMovilC = TextEditingController(text: cofrade.telefonoMovil);
    final telefonoFijoC = TextEditingController(text: cofrade.telefonoFijo);
    final telefonoSecC =
        TextEditingController(text: cofrade.telefonoSecundario ?? '');
    final domicilioC = TextEditingController(text: cofrade.domicilio);
    final localidadC = TextEditingController(text: cofrade.localidad);
    final codigoPostalC = TextEditingController(text: cofrade.codigoPostal);
    final ibanC = TextEditingController(text: cofrade.iban ?? '');
    final titularIbanC = TextEditingController(text: cofrade.titularIban ?? '');
    final comentariosC = TextEditingController(text: cofrade.comentarios ?? '');
    final numeroC =
        TextEditingController(text: cofrade.numero?.toString() ?? '');
    final estaturaC =
        TextEditingController(text: cofrade.estatura?.toString() ?? '');
    final anioAltaC =
        TextEditingController(text: cofrade.anioAlta?.toString() ?? '');
    final aniosHermandadC =
        TextEditingController(text: cofrade.aniosHermandad?.toString() ?? '');
    final anioMayordomiaC =
        TextEditingController(text: cofrade.anioMayordomia?.toString() ?? '');
    final cargoC = TextEditingController(text: cofrade.cargo ?? '');
    final dniTutorC = TextEditingController(text: cofrade.dniTutor ?? '');
    final tutorNameC = TextEditingController(text: cofrade.digitalTutorName);
    final tutorEmailC = TextEditingController(text: cofrade.digitalTutorEmail);
    final tutorPhoneC = TextEditingController(text: cofrade.digitalTutorPhone);
    final parentescoTutorC =
        TextEditingController(text: cofrade.digitalTutorRelationship);
    final causaBajaC = TextEditingController(text: cofrade.causaBaja ?? '');

    String estado = ['Activo', 'Pendiente', 'Baja'].contains(cofrade.estado)
        ? cofrade.estado
        : 'Activo';
    String genero = cofrade.genero == 'H'
        ? 'Hombre'
        : cofrade.genero == 'M'
            ? 'Mujer'
            : (cofrade.genero ?? '');
    String talla = cofrade.talla ?? '';
    String rol = [
      'cofrade',
      'junta',
      'tesorero',
      'contabilidad',
      'consulta',
      'admin'
    ].contains(cofrade.rol)
        ? cofrade.rol
        : 'cofrade';
    bool tieneCuota = cofrade.tieneCuota;
    bool cuotaMetalico = cofrade.cuotaMetalico;
    bool cuotaDomiciliada = cofrade.cuotaDomiciliada;
    bool gdprFirmado = cofrade.gdprFirmado || cofrade.gdprPapel;
    bool gdprFirmadoDigital = cofrade.gdprFirmadoDigital;
    bool tieneTunicaPropia = cofrade.tieneTunicaPropia;
    bool notificacionesActivas = cofrade.notificacionesActivas;
    bool requiresDigitalTutor = cofrade.requiresDigitalTutor;
    var tagsManual = List<String>.from(cofrade.tagsManual);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Editar: ${cofrade.nombreCompleto}'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Datos personales',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: numeroC,
                      decoration: const InputDecoration(
                          labelText: 'N\u00famero de cofrade'),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextField(
                      controller: nombreC,
                      decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: apellidosC,
                      decoration:
                          const InputDecoration(labelText: 'Apellidos')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: dniC,
                      decoration: const InputDecoration(labelText: 'DNI')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue:
                        ['Hombre', 'Mujer'].contains(genero) ? genero : null,
                    decoration: const InputDecoration(labelText: 'G\u00e9nero'),
                    items: const [
                      DropdownMenuItem(value: 'Hombre', child: Text('Hombre')),
                      DropdownMenuItem(value: 'Mujer', child: Text('Mujer')),
                    ],
                    onChanged: (v) => setDialogState(() => genero = v ?? ''),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                      controller: estaturaC,
                      decoration:
                          const InputDecoration(labelText: 'Estatura (cm)'),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue:
                        ['XS', 'S', 'M', 'L', 'XL', 'XXL'].contains(talla)
                            ? talla
                            : null,
                    decoration: const InputDecoration(labelText: 'Talla'),
                    items: const [
                      DropdownMenuItem(value: 'XS', child: Text('XS')),
                      DropdownMenuItem(value: 'S', child: Text('S')),
                      DropdownMenuItem(value: 'M', child: Text('M')),
                      DropdownMenuItem(value: 'L', child: Text('L')),
                      DropdownMenuItem(value: 'XL', child: Text('XL')),
                      DropdownMenuItem(value: 'XXL', child: Text('XXL')),
                    ],
                    onChanged: (v) => setDialogState(() => talla = v ?? ''),
                  ),
                  const Divider(height: 28),
                  const Text('Contacto',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: emailC,
                      decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: emailSecC,
                      decoration:
                          const InputDecoration(labelText: 'Email secundario')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: telefonoMovilC,
                      decoration: const InputDecoration(
                          labelText: 'Tel\u00e9fono m\u00f3vil')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: telefonoFijoC,
                      decoration: const InputDecoration(
                          labelText: 'Tel\u00e9fono fijo')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: telefonoSecC,
                      decoration: const InputDecoration(
                          labelText: 'Tel\u00e9fono secundario')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: domicilioC,
                      decoration:
                          const InputDecoration(labelText: 'Domicilio')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: localidadC,
                      decoration:
                          const InputDecoration(labelText: 'Localidad')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: codigoPostalC,
                      decoration: const InputDecoration(
                          labelText: 'C\u00f3digo postal')),
                  const Divider(height: 28),
                  const Text('Cofrad\u00eda',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: estado,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'Activo', child: Text('Activo')),
                      DropdownMenuItem(
                          value: 'Pendiente', child: Text('Pendiente')),
                      DropdownMenuItem(value: 'Baja', child: Text('Baja')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => estado = v ?? 'Activo'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: rol,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: const [
                      DropdownMenuItem(
                          value: 'cofrade', child: Text('Cofrade')),
                      DropdownMenuItem(value: 'junta', child: Text('Junta')),
                      DropdownMenuItem(
                          value: 'tesorero', child: Text('Tesorero')),
                      DropdownMenuItem(
                          value: 'contabilidad', child: Text('Contabilidad')),
                      DropdownMenuItem(
                          value: 'consulta', child: Text('Consulta')),
                      DropdownMenuItem(
                          value: 'admin', child: Text('Administrador')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => rol = v ?? 'cofrade'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                      controller: cargoC,
                      decoration: const InputDecoration(labelText: 'Cargo')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: anioAltaC,
                      decoration:
                          const InputDecoration(labelText: 'A\u00f1o de alta'),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextField(
                      controller: aniosHermandadC,
                      decoration: const InputDecoration(
                          labelText: 'A\u00f1os de hermandad'),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextField(
                      controller: anioMayordomiaC,
                      decoration: const InputDecoration(
                          labelText: 'A\u00f1o de mayordom\u00eda'),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextField(
                      controller: causaBajaC,
                      decoration:
                          const InputDecoration(labelText: 'Causa de baja')),
                  const Divider(height: 28),
                  const Text('Econom\u00eda',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: ibanC,
                      decoration: const InputDecoration(labelText: 'IBAN')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: titularIbanC,
                      decoration:
                          const InputDecoration(labelText: 'Titular IBAN')),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Tiene cuota'),
                    value: tieneCuota,
                    onChanged: (v) => setDialogState(() => tieneCuota = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Cuota en met\u00e1lico'),
                    value: cuotaMetalico,
                    onChanged: (v) => setDialogState(() => cuotaMetalico = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Cuota domiciliada'),
                    value: cuotaDomiciliada,
                    onChanged: (v) =>
                        setDialogState(() => cuotaDomiciliada = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 28),
                  const Text('GDPR y T\u00fanica',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('GDPR firmado (papel)'),
                    value: gdprFirmado,
                    subtitle: cofrade.gdprPapel
                        ? const Text(
                            'Consta documento GDPR en papel. Elimina el documento para marcarlo como no firmado.',
                          )
                        : null,
                    onChanged: cofrade.gdprPapel
                        ? null
                        : (v) => setDialogState(() => gdprFirmado = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('GDPR firmado (digital)'),
                    value: gdprFirmadoDigital,
                    onChanged: (v) =>
                        setDialogState(() => gdprFirmadoDigital = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Tiene t\u00fanica propia'),
                    value: tieneTunicaPropia,
                    onChanged: (v) =>
                        setDialogState(() => tieneTunicaPropia = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 28),
                  const Text('Tutela',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Requiere tutela digital'),
                    value: requiresDigitalTutor,
                    onChanged: (v) =>
                        setDialogState(() => requiresDigitalTutor = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                      controller: tutorNameC,
                      decoration:
                          const InputDecoration(labelText: 'Nombre del tutor')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: tutorEmailC,
                      decoration:
                          const InputDecoration(labelText: 'Email del tutor')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: tutorPhoneC,
                      decoration: const InputDecoration(
                          labelText: 'Teléfono del tutor')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: dniTutorC,
                      decoration:
                          const InputDecoration(labelText: 'DNI del tutor')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: parentescoTutorC,
                      decoration: const InputDecoration(
                          labelText: 'Parentesco del tutor')),
                  const Divider(height: 28),
                  const Text('Tags manuales',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  StreamBuilder<List<TagConfig>>(
                    stream: context.read<FirestoreService>().getTagsConfig(),
                    builder: (context, tagSnap) {
                      final tags = (tagSnap.data ?? const <TagConfig>[])
                          .where((tag) => tag.activo && tag.tipo == 'manual')
                          .toList();
                      if (tags.isEmpty) {
                        return const Text('No hay tags manuales configurados.');
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags.map((tag) {
                          final selected = tagsManual.contains(tag.id);
                          return FilterChip(
                            label: Text(tag.nombre),
                            selected: selected,
                            selectedColor: _parseColor(tag.color).withAlpha(45),
                            backgroundColor:
                                _parseColor(tag.color).withAlpha(20),
                            labelStyle:
                                TextStyle(color: _parseColor(tag.color)),
                            onSelected: (value) => setDialogState(() {
                              if (value) {
                                tagsManual.add(tag.id);
                              } else {
                                tagsManual.remove(tag.id);
                              }
                            }),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const Divider(height: 28),
                  const Text('Otros',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Notificaciones activas'),
                    value: notificacionesActivas,
                    onChanged: (v) =>
                        setDialogState(() => notificacionesActivas = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                      controller: comentariosC,
                      decoration:
                          const InputDecoration(labelText: 'Comentarios'),
                      maxLines: 3),
                  const Divider(height: 28),
                  _buildAdminGdprDocumentationBlock(cofrade),
                  _buildAdminPrivateDocumentsBlock(cofrade),
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
                try {
                  final data = <String, dynamic>{
                    'nombre': nombreC.text.trim(),
                    'apellidos': apellidosC.text.trim(),
                    'email': emailC.text.trim(),
                    'email_secundario': emailSecC.text.trim(),
                    'dni': dniC.text.trim().toUpperCase(),
                    'genero': genero,
                    'estatura': int.tryParse(estaturaC.text.trim()),
                    'talla': talla,
                    'telefono_movil': telefonoMovilC.text.trim(),
                    'telefono_fijo': telefonoFijoC.text.trim(),
                    'telefono_secundario': telefonoSecC.text.trim(),
                    'domicilio': domicilioC.text.trim(),
                    'localidad': localidadC.text.trim(),
                    'codigo_postal': codigoPostalC.text.trim(),
                    'estado': estado,
                    'rol': rol,
                    'cargo': cargoC.text.trim(),
                    'anio_alta': int.tryParse(anioAltaC.text.trim()),
                    'anios_hermandad':
                        int.tryParse(aniosHermandadC.text.trim()),
                    'anio_mayordomia':
                        int.tryParse(anioMayordomiaC.text.trim()),
                    'causa_baja': causaBajaC.text.trim(),
                    'numero': int.tryParse(numeroC.text.trim()),
                    'iban': ibanC.text.trim(),
                    'titular_iban': titularIbanC.text.trim(),
                    'tiene_cuota': tieneCuota,
                    'cuota_metalico': cuotaMetalico,
                    'cuota_domiciliada': cuotaDomiciliada,
                    'gdpr_firmado': gdprFirmado,
                    'gdpr_firmado_digital': gdprFirmadoDigital,
                    'tiene_tunica_propia': tieneTunicaPropia,
                    'requiresDigitalTutor': requiresDigitalTutor,
                    'tutelado_digital': requiresDigitalTutor,
                    'digitalTutorName': tutorNameC.text.trim(),
                    'digitalTutorEmail': tutorEmailC.text.trim(),
                    'digitalTutorPhone': tutorPhoneC.text.trim(),
                    'digitalTutorDni': dniTutorC.text.trim(),
                    'digitalTutorRelationship': parentescoTutorC.text.trim(),
                    'dni_tutor': dniTutorC.text.trim(),
                    'parentesco_tutor': parentescoTutorC.text.trim(),
                    'notificaciones_activas': notificacionesActivas,
                    'comentarios': comentariosC.text.trim(),
                    'tags_manual': tagsManual,
                    'tags_auto': cofrade.tagsAuto,
                  };
                  await context.read<FirestoreService>().updateCofrade(
                        cofrade.id,
                        data,
                        changedBy: context.read<AuthService>().cofrade?.id ??
                            'unknown',
                        changedByRole:
                            context.read<AuthService>().cofrade?.rol ?? 'admin',
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('${cofrade.nombreCompleto} actualizado.')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(String action, Cofrade cofrade) async {
    final firestoreService = context.read<FirestoreService>();
    final actor = context.read<AuthService>().cofrade;
    final changedBy = actor?.id ?? 'unknown';
    final changedByRole = actor?.rol ?? 'unknown';

    switch (action) {
      case 'baja':
        final causa = await _askBajaCause(context, cofrade);
        if (causa == null) return;
        await firestoreService.darDeBajaCofrade(
          cofradeId: cofrade.id,
          causaBaja: causa,
          changedBy: changedBy,
          changedByRole: changedByRole,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${cofrade.nombreCompleto} dado de baja.')),
          );
        }
        break;
      case 'reactivar':
        final previous = await _askReactivationMode(context, cofrade);
        if (previous == null) return;
        await firestoreService.reactivarCofrade(
          cofradeId: cofrade.id,
          recuperarNumeroAnterior: previous,
          changedBy: changedBy,
          changedByRole: changedByRole,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${cofrade.nombreCompleto} reactivado.')),
          );
        }
        break;
      case 'hacer_admin':
        await firestoreService.setAdminRole(
          cofrade,
          enabled: true,
          changedBy: changedBy,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${cofrade.nombreCompleto} es ahora administrador.')),
          );
        }
        break;
      case 'quitar_admin':
        await firestoreService.setAdminRole(
          cofrade,
          enabled: false,
          changedBy: changedBy,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${cofrade.nombreCompleto} ya no es administrador.')),
          );
        }
        break;
      case 'editar':
        _showEditCofradeDialog(cofrade);
        break;
      case 'gestionar_tags':
        _showEditCofradeDialog(cofrade);
        break;
      case 'auditoria':
        _showCofradeAudit(context, cofrade);
        break;
      case 'mensaje':
        _showAdminConversationDialog(context, cofrade);
        break;
      case 'revisar_cambios':
        await firestoreService.markProfileChangesReviewed(
          cofrade: cofrade,
          changedBy: changedBy,
          changedByRole: changedByRole,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cambios de perfil revisados.')),
          );
        }
        break;
      case 'reactivar_consentimiento':
        final payload = await _askConsentReactivation(context);
        if (payload == null) return;
        await firestoreService.reacceptDigitalConsentByAdmin(
          cofrade: cofrade,
          changedBy: changedBy,
          changedByRole: changedByRole,
          reason: payload['reason']!,
          notes: payload['notes']!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Consentimiento reactivado.')),
          );
        }
        break;
    }
  }

  Future<Map<String, String>?> _askConsentReactivation(
      BuildContext context) async {
    final notesController = TextEditingController();
    var reason = 'Petición presencial';
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reactivar consentimiento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta acción volverá a marcar el consentimiento de este cofrade como aceptado. Solo debe hacerse si existe petición expresa y verificable del cofrade, tutor o representante. Esta acción quedará auditada.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: const [
                  DropdownMenuItem(
                      value: 'Petición presencial',
                      child: Text('Petición presencial')),
                  DropdownMenuItem(
                      value: 'Petición por email',
                      child: Text('Petición por email')),
                  DropdownMenuItem(
                      value: 'Petición telefónica',
                      child: Text('Petición telefónica')),
                  DropdownMenuItem(
                      value: 'Error administrativo',
                      child: Text('Error administrativo')),
                  DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                ],
                onChanged: (value) =>
                    setDialogState(() => reason = value ?? reason),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Observaciones'),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final notes = notesController.text.trim();
                if (notes.isEmpty) return;
                Navigator.pop(ctx, {'reason': reason, 'notes': notes});
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminConversationDialog(BuildContext context, Cofrade cofrade) {
    final subjectC = TextEditingController();
    final bodyC = TextEditingController();
    final replyC = TextEditingController();
    final fs = context.read<FirestoreService>();
    final auth = context.read<AuthService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mensajes · ${cofrade.nombreCompleto}'),
        content: SizedBox(
          width: 720,
          height: 520,
          child: Column(
            children: [
              TextField(
                controller: subjectC,
                decoration: const InputDecoration(labelText: 'Asunto'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bodyC,
                decoration: const InputDecoration(labelText: 'Mensaje'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (subjectC.text.trim().isEmpty ||
                        bodyC.text.trim().isEmpty) {
                      return;
                    }
                    await fs.startConversation(
                      cofradeId: cofrade.id,
                      subject: subjectC.text,
                      body: bodyC.text,
                      createdBy: auth.cofrade?.id ?? 'admin',
                      createdByRole: auth.cofrade?.rol ?? 'admin',
                    );
                    subjectC.clear();
                    bodyC.clear();
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Iniciar conversación'),
                ),
              ),
              const Divider(height: 24),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: fs.watchConversations(cofrade.id),
                  builder: (context, snapshot) {
                    final conversations =
                        snapshot.data ?? const <Map<String, dynamic>>[];
                    if (conversations.isEmpty) {
                      return const Center(
                          child: Text('Sin conversaciones abiertas.'));
                    }
                    return ListView(
                      children: conversations.map((conv) {
                        final id = '${conv['id']}';
                        return ExpansionTile(
                          title: Text('${conv['subject'] ?? 'Sin asunto'}'),
                          subtitle: Text('${conv['status'] ?? 'abierto'}'),
                          children: [
                            SizedBox(
                              height: 180,
                              child: StreamBuilder<List<Map<String, dynamic>>>(
                                stream: fs.watchConversationMessages(
                                    cofrade.id, id),
                                builder: (context, msgSnap) {
                                  final messages = msgSnap.data ??
                                      const <Map<String, dynamic>>[];
                                  return ListView(
                                    children: messages
                                        .map((msg) => ListTile(
                                              dense: true,
                                              title:
                                                  Text('${msg['body'] ?? ''}'),
                                              subtitle: Text(
                                                  '${msg['createdByRole'] ?? ''} · ${msg['createdBy'] ?? ''}'),
                                            ))
                                        .toList(),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: replyC,
                                      decoration: const InputDecoration(
                                          labelText: 'Responder'),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      if (replyC.text.trim().isEmpty) return;
                                      await fs.replyConversation(
                                        cofradeId: cofrade.id,
                                        conversationId: id,
                                        body: replyC.text,
                                        createdBy: auth.cofrade?.id ?? 'admin',
                                        createdByRole:
                                            auth.cofrade?.rol ?? 'admin',
                                      );
                                      replyC.clear();
                                    },
                                    icon: const Icon(Icons.send),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String label;
  final String value;

  const _MiniKpi({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _DataQualityChip extends StatelessWidget {
  final String status;
  final List<String> missing;
  final bool pendingReview;

  const _DataQualityChip({
    required this.status,
    this.missing = const [],
    this.pendingReview = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'COMPLETE' => Colors.green.shade700,
      _ => Colors.orange.shade700,
    };
    final label = switch (status) {
      'COMPLETE' => 'Perfil completo',
      _ => 'Perfil incompleto',
    };
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Chip(
          label: Text(label),
          visualDensity: VisualDensity.compact,
          backgroundColor: color.withAlpha(20),
          labelStyle: TextStyle(color: color, fontSize: 11),
        ),
        if (pendingReview)
          Tooltip(
            message: 'Hay cambios de perfil pendientes de revisión',
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.orange.shade700,
              ),
            ),
          ),
      ],
    );
    if (status != 'COMPLETE' && missing.isNotEmpty) {
      return Tooltip(
        message: 'Faltan: ${missing.join(", ")}',
        child: chip,
      );
    }
    return chip;
  }
}

class _SharedEmailInfoSection extends StatelessWidget {
  final Cofrade cofrade;
  final List<Cofrade> peers;
  final String Function(Cofrade) statusLabel;

  const _SharedEmailInfoSection({
    required this.cofrade,
    required this.peers,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (cofrade.email.trim().isEmpty || peers.length < 2) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Email compartido',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${cofrade.email} está asociado a ${peers.length} perfiles.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...peers.map(
              (peer) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${peer.nombreCompleto} · Nº ${peer.numero ?? "-"} · ${statusLabel(peer)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentSection extends StatelessWidget {
  final String title;
  final int count;
  final List<Widget> children;

  const _IncidentSection({
    required this.title,
    required this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: count > 0,
        title: Text('$title ($count)'),
        children: children.isEmpty
            ? [
                const ListTile(
                  title: Text('Sin incidencias'),
                )
              ]
            : children,
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final Map<String, String> rows;

  const _InfoSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title),
        children: rows.entries
            .map((entry) => ListTile(
                  dense: true,
                  title: Text(entry.key),
                  trailing: SizedBox(
                    width: 360,
                    child: Text(
                      entry.value.isEmpty ? '-' : entry.value,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
