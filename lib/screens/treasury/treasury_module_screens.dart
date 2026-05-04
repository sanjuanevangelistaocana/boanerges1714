import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/cofrade.dart';
import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';

class IndividualTrackingScreen extends StatefulWidget {
  const IndividualTrackingScreen({super.key});

  @override
  State<IndividualTrackingScreen> createState() =>
      _IndividualTrackingScreenState();
}

class _IndividualTrackingScreenState extends State<IndividualTrackingScreen> {
  String? _cofradeId;
  int? _year;
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  String _costCenterFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TreasuryRepository>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_search, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text('Seguimiento individual',
                    style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Cofrade>>(
              stream: repository.watchCofradesForTreasuryTracking(),
              builder: (context, cofradeSnap) {
                final cofrades = cofradeSnap.data ?? const [];
                if (cofrades.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No hay cofrades disponibles.'),
                    ),
                  );
                }
                final selected = cofrades.firstWhere(
                  (c) => c.id == (_cofradeId ?? cofrades.first.id),
                  orElse: () => cofrades.first,
                );
                _cofradeId ??= selected.id;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 360,
                          child: DropdownButtonFormField<String>(
                            initialValue: selected.id,
                            decoration: const InputDecoration(
                              labelText: 'Cofrade / persona',
                              prefixIcon: Icon(Icons.person),
                            ),
                            items: cofrades
                                .map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.nombreCompleto),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _cofradeId = value),
                          ),
                        ),
                        StreamBuilder<List<int>>(
                          stream: repository.watchAvailableTreasuryYears(),
                          builder: (context, yearSnap) {
                            final years =
                                yearSnap.data ?? [DateTime.now().year];
                            return SizedBox(
                              width: 220,
                              child: DropdownButtonFormField<int?>(
                                initialValue: _year,
                                decoration: const InputDecoration(
                                  labelText: 'Histórico',
                                  prefixIcon: Icon(Icons.history),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Todos los ejercicios'),
                                  ),
                                  ...years.map((year) => DropdownMenuItem<int?>(
                                        value: year,
                                        child: Text('Ejercicio $year'),
                                      )),
                                ],
                                onChanged: (value) =>
                                    setState(() => _year = value),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<TreasuryCostCenter>>(
                      stream: repository.watchCostCenters(),
                      builder: (context, centerSnap) {
                        final centers =
                            centerSnap.data ?? const <TreasuryCostCenter>[];
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 220,
                              child: DropdownButtonFormField<String>(
                                initialValue: _typeFilter,
                                decoration: const InputDecoration(
                                  labelText: 'Tipo movimiento',
                                  prefixIcon: Icon(Icons.filter_list),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'all', child: Text('Todos')),
                                  DropdownMenuItem(
                                      value: 'invoice', child: Text('Factura')),
                                  DropdownMenuItem(
                                      value: 'payment', child: Text('Cobro')),
                                  DropdownMenuItem(
                                      value: 'rejected',
                                      child: Text('Rechazo')),
                                  DropdownMenuItem(
                                      value: 'income', child: Text('Ingreso')),
                                  DropdownMenuItem(
                                      value: 'expense', child: Text('Gasto')),
                                ],
                                onChanged: (value) => setState(
                                    () => _typeFilter = value ?? 'all'),
                              ),
                            ),
                            SizedBox(
                              width: 200,
                              child: DropdownButtonFormField<String>(
                                initialValue: _statusFilter,
                                decoration: const InputDecoration(
                                  labelText: 'Estado',
                                  prefixIcon: Icon(Icons.rule),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'all', child: Text('Todos')),
                                  DropdownMenuItem(
                                      value: 'pending',
                                      child: Text('Pendiente')),
                                  DropdownMenuItem(
                                      value: 'confirmed',
                                      child: Text('Confirmado')),
                                  DropdownMenuItem(
                                      value: 'returned',
                                      child: Text('Devuelto')),
                                  DropdownMenuItem(
                                      value: 'cancelled',
                                      child: Text('Anulado')),
                                ],
                                onChanged: (value) => setState(
                                    () => _statusFilter = value ?? 'all'),
                              ),
                            ),
                            SizedBox(
                              width: 260,
                              child: DropdownButtonFormField<String>(
                                initialValue: _costCenterFilter,
                                decoration: const InputDecoration(
                                  labelText: 'Centro / subcentro',
                                  prefixIcon: Icon(Icons.account_tree),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                      value: 'all', child: Text('Todos')),
                                  ...centers.map((center) => DropdownMenuItem(
                                        value: center.id,
                                        child: Text(center.name),
                                      )),
                                ],
                                onChanged: (value) => setState(
                                    () => _costCenterFilter = value ?? 'all'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<TreasurySettings?>(
                      stream: _year == null
                          ? Stream<TreasurySettings?>.value(null)
                          : repository.watchSettingsByYear(_year!),
                      builder: (context, settingsSnap) {
                        final settings = settingsSnap.data;
                        final start = _year == null
                            ? null
                            : settings?.fiscalStartDate ?? DateTime(_year!);
                        final end = _year == null
                            ? null
                            : settings?.fiscalEndDate ??
                                DateTime(_year!, 12, 31);
                        return StreamBuilder<List<TreasuryInvoice>>(
                          stream: repository.getInvoicesForCofrade(selected.id),
                          builder: (context, invoiceSnap) {
                            return StreamBuilder<List<TreasuryPayment>>(
                              stream:
                                  repository.getPaymentsForCofrade(selected.id),
                              builder: (context, paymentSnap) {
                                return StreamBuilder<
                                    List<TreasuryAccountingMovement>>(
                                  stream: repository
                                      .getAccountingMovementsForPerson(
                                    personId: selected.id,
                                    start: start,
                                    end: end,
                                  ),
                                  builder: (context, movementSnap) {
                                    final invoices = _filterInvoices(
                                      invoiceSnap.data ?? const [],
                                      start,
                                      end,
                                    );
                                    final payments = _filterPayments(
                                      paymentSnap.data ?? const [],
                                      start,
                                      end,
                                    );
                                    final movements = _filterMovements(
                                        movementSnap.data ?? const []);
                                    return _IndividualTrackingDetail(
                                      cofrade: selected,
                                      invoices: invoices,
                                      payments: payments,
                                      movements: movements,
                                    );
                                  },
                                );
                              },
                            );
                          },
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

  List<TreasuryInvoice> _filterInvoices(
    List<TreasuryInvoice> invoices,
    DateTime? start,
    DateTime? end,
  ) {
    if (_year == null) return invoices;
    return invoices.where((invoice) => invoice.year == _year).toList();
  }

  List<TreasuryPayment> _filterPayments(
    List<TreasuryPayment> payments,
    DateTime? start,
    DateTime? end,
  ) {
    if (start == null || end == null) return payments;
    return payments.where((payment) {
      final date =
          payment.resultDate ?? payment.paymentDate ?? payment.createdAt;
      if (date == null) return true;
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  List<TreasuryAccountingMovement> _filterMovements(
    List<TreasuryAccountingMovement> movements,
  ) {
    return movements.where((movement) {
      if (_statusFilter != 'all' && movement.status != _statusFilter) {
        return false;
      }
      if (_costCenterFilter != 'all' &&
          movement.costCenterId != _costCenterFilter &&
          movement.subCostCenterId != _costCenterFilter) {
        return false;
      }
      if (_typeFilter == 'invoice') return movement.origin == 'facturacion';
      if (_typeFilter == 'payment') {
        return movement.status == 'confirmed' || movement.origin == 'manual';
      }
      if (_typeFilter == 'rejected') return movement.status == 'returned';
      if (_typeFilter == 'income') return movement.type == 'income';
      if (_typeFilter == 'expense') return movement.type == 'expense';
      return true;
    }).toList();
  }
}

class _IndividualTrackingDetail extends StatelessWidget {
  final Cofrade cofrade;
  final List<TreasuryInvoice> invoices;
  final List<TreasuryPayment> payments;
  final List<TreasuryAccountingMovement> movements;

  const _IndividualTrackingDetail({
    required this.cofrade,
    required this.invoices,
    required this.payments,
    required this.movements,
  });

  @override
  Widget build(BuildContext context) {
    final totalInvoiced =
        invoices.fold<double>(0, (total, item) => total + item.totalAmount);
    final totalPaid = payments
        .where((p) => p.status == 'paid')
        .fold<double>(0, (total, item) => total + item.amount);
    final totalRejected = payments
        .where((p) => p.status == 'rejected')
        .fold<double>(0, (total, item) => total + item.amount);
    final pending = (totalInvoiced - totalPaid).clamp(0, double.infinity);
    final status = totalRejected > 0
        ? 'Impagado'
        : pending > 0
            ? 'Pendiente'
            : movements.any((m) => m.status == 'pending')
                ? 'Con movimientos abiertos'
                : 'Al corriente';
    final allRows = <_TrackingMovementRow>[
      ...invoices.map((invoice) => _TrackingMovementRow(
            date: invoice.generatedAt ?? invoice.createdAt,
            type: 'Factura',
            concept: invoice.concept.isEmpty
                ? invoice.invoiceNumber
                : invoice.concept,
            amount: invoice.totalAmount,
            status: invoice.status,
            method: invoice.paymentMethod,
            origin: 'Facturación y Cobros',
            reference: invoice.invoiceNumber,
          )),
      ...payments.map((payment) => _TrackingMovementRow(
            date:
                payment.resultDate ?? payment.paymentDate ?? payment.createdAt,
            type: payment.status == 'rejected' ? 'Rechazo' : 'Cobro',
            concept:
                payment.notes.isEmpty ? payment.invoiceNumber : payment.notes,
            amount: payment.amount,
            status: payment.status,
            method: payment.method,
            origin: payment.method == 'bank_remittance' ? 'Remesa' : 'Manual',
            reference: payment.reference,
          )),
      ...movements.map((movement) => _TrackingMovementRow(
            date: movement.date ?? movement.createdAt,
            type: movement.type == 'expense'
                ? 'Gasto contable'
                : 'Ingreso contable',
            concept: movement.concept.isEmpty
                ? movement.description
                : movement.concept,
            amount: movement.amount,
            status: movement.status,
            method: movement.paymentMethod,
            costCenter: movement.costCenterId,
            subCostCenter: movement.subCostCenterId,
            origin: movement.origin,
            reference: movement.reference,
          )),
    ]..sort((a, b) =>
        (b.date ?? DateTime(1900)).compareTo(a.date ?? DateTime(1900)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cofrade.nombreCompleto,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Identificador: ${cofrade.numero?.toString() ?? cofrade.id} · Método habitual: ${cofrade.cuotaDomiciliada ? 'Domiciliación' : cofrade.cuotaMetalico ? 'Efectivo' : 'No definido'}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _TrackingStatusCard(status: status),
                    _AccountingKpi(
                        label: 'Facturado',
                        value: totalInvoiced,
                        color: AppTheme.primaryColor),
                    _AccountingKpi(
                        label: 'Cobrado',
                        value: totalPaid,
                        color: AppTheme.accentColor),
                    _AccountingKpi(
                        label: 'Pendiente',
                        value: pending.toDouble(),
                        color: Colors.amber.shade800),
                    _AccountingKpi(
                        label: 'Rechazado',
                        value: totalRejected,
                        color: Colors.red.shade700),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Estado de cuenta: $status',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Detalle de movimientos',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (allRows.isEmpty)
                  const Text('No hay movimientos para esta selección.')
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 560),
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Fecha')),
                            DataColumn(label: Text('Tipo')),
                            DataColumn(label: Text('Concepto')),
                            DataColumn(label: Text('Importe')),
                            DataColumn(label: Text('Estado')),
                            DataColumn(label: Text('Método')),
                            DataColumn(label: Text('Centro')),
                            DataColumn(label: Text('Origen')),
                            DataColumn(label: Text('Referencia')),
                          ],
                          rows: allRows
                              .map((row) => DataRow(cells: [
                                    DataCell(Text(_fmt(row.date))),
                                    DataCell(Text(row.type)),
                                    DataCell(Text(row.concept)),
                                    DataCell(Text(
                                        '${row.amount.toStringAsFixed(2)} €')),
                                    DataCell(Text(row.status)),
                                    DataCell(Text(row.method)),
                                    DataCell(Text(row.subCostCenter.isEmpty
                                        ? row.costCenter
                                        : '${row.costCenter} / ${row.subCostCenter}')),
                                    DataCell(Text(row.origin)),
                                    DataCell(Text(row.reference)),
                                  ]))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _fmt(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _TrackingStatusCard extends StatelessWidget {
  final String status;

  const _TrackingStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'Al corriente'
        ? AppTheme.accentColor
        : status == 'Impagado'
            ? Colors.red.shade700
            : Colors.amber.shade800;
    return SizedBox(
      width: 245,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Estado',
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Text(
                status,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingMovementRow {
  final DateTime? date;
  final String type;
  final String concept;
  final double amount;
  final String status;
  final String method;
  final String costCenter;
  final String subCostCenter;
  final String origin;
  final String reference;

  const _TrackingMovementRow({
    required this.date,
    required this.type,
    required this.concept,
    required this.amount,
    required this.status,
    this.method = '',
    this.costCenter = '',
    this.subCostCenter = '',
    required this.origin,
    this.reference = '',
  });
}

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  int _year = DateTime.now().year;
  bool _seedingCenters = false;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TreasuryRepository>();
    final auth = context.watch<AuthService>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Contabilidad',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                SizedBox(
                  width: 130,
                  child: TextFormField(
                    initialValue: '$_year',
                    decoration: const InputDecoration(
                      labelText: 'Año',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) setState(() => _year = parsed);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<TreasurySettings?>(
              stream: repository.watchSettingsByYear(_year),
              builder: (context, snap) {
                final settings = snap.data;
                return _FiscalYearCard(
                  year: _year,
                  settings: settings,
                  canManage: auth.canManageTreasury,
                  onSave: (start, end) => _saveFiscalYear(
                    repository,
                    settings,
                    start,
                    end,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<TreasurySettings?>(
              stream: repository.watchSettingsByYear(_year),
              builder: (context, settingsSnap) {
                final settings = settingsSnap.data;
                final start = settings?.fiscalStartDate ?? DateTime(_year);
                final end = settings?.fiscalEndDate ?? DateTime(_year, 12, 31);
                return StreamBuilder<List<TreasuryAccountingMovement>>(
                  stream: repository.getAccountingMovementsInRange(
                    start: start,
                    end: end,
                  ),
                  builder: (context, snap) {
                    final movements = snap.data ?? const [];
                    final income = movements
                        .where((m) => m.type == 'income')
                        .fold<double>(0, (total, item) => total + item.amount);
                    final expense = movements
                        .where((m) => m.type == 'expense')
                        .fold<double>(0, (total, item) => total + item.amount);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _AccountingKpi(
                                label: 'Ingresos',
                                value: income,
                                color: Colors.green),
                            _AccountingKpi(
                                label: 'Gastos',
                                value: expense,
                                color: Colors.red),
                            _AccountingKpi(
                              label: 'Resultado',
                              value: income - expense,
                              color: income - expense >= 0
                                  ? AppTheme.accentColor
                                  : Colors.red,
                            ),
                            _AccountingKpi(
                              label: 'Movimientos',
                              value: movements.length.toDouble(),
                              color: AppTheme.primaryColor,
                              isMoney: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<List<TreasuryCostCenter>>(
                          stream: repository.watchCostCenters(),
                          builder: (context, centerSnap) {
                            final centers =
                                centerSnap.data ?? const <TreasuryCostCenter>[];
                            return _BalanceDetailCard(
                              movements: movements,
                              centers: centers,
                              canManage: auth.canManageTreasury,
                              onEdit: (movement) => _editAccountingMovement(
                                repository,
                                centers,
                                movement,
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<TreasuryCostCenter>>(
              stream: repository.watchCostCenters(),
              builder: (context, snap) {
                final centers = snap.data ?? const <TreasuryCostCenter>[];
                return Column(
                  children: [
                    _AccountingActionsCard(
                      canManage: auth.canManageTreasury,
                      centers: centers,
                      onCreateMovement: () =>
                          _createAccountingMovement(repository, centers),
                    ),
                    const SizedBox(height: 16),
                    _BudgetOverviewCard(centers: centers),
                    const SizedBox(height: 16),
                    _CostCentersCard(
                      centers: centers,
                      canManage: auth.canManageTreasury,
                      seeding: _seedingCenters,
                      onSeedDefaults: () => _seedDefaultCostCenters(repository),
                      onSave: (center, parentId) =>
                          _saveCostCenter(center, repository, parentId),
                      onDelete: (center) =>
                          _deleteCostCenter(center, repository),
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

  Future<void> _saveCostCenter(
    TreasuryCostCenter? center,
    TreasuryRepository repository,
    String parentId,
  ) async {
    final auth = context.read<AuthService>();
    final nameController = TextEditingController(text: center?.name ?? '');
    final descriptionController =
        TextEditingController(text: center?.description ?? '');
    final budgetController = TextEditingController(
      text: (center?.budgetAmount ?? 0).toStringAsFixed(2),
    );
    var isActive = center?.isActive ?? true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title:
              Text(center == null ? 'Crear centro de coste' : 'Editar centro'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: budgetController,
                  decoration: const InputDecoration(
                    labelText: 'Presupuesto previsto',
                    suffixText: '€',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: isActive,
                  onChanged: (value) => setLocalState(() => isActive = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    final budget =
        double.tryParse(budgetController.text.replaceAll(',', '.')) ?? 0;
    nameController.dispose();
    descriptionController.dispose();
    budgetController.dispose();
    if (confirmed != true || name.isEmpty) return;
    await repository.saveCostCenter(
      id: center?.id ?? '',
      name: name,
      description: description,
      parentId: center?.parentId ?? parentId,
      budgetAmount: budget,
      isActive: isActive,
      changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
    );
  }

  Future<void> _seedDefaultCostCenters(TreasuryRepository repository) async {
    final auth = context.read<AuthService>();
    setState(() => _seedingCenters = true);
    try {
      final created = await repository.seedDefaultCostCenters(
        changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Centros creados: $created.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _seedingCenters = false);
    }
  }

  Future<void> _deleteCostCenter(
    TreasuryCostCenter center,
    TreasuryRepository repository,
  ) async {
    final auth = context.read<AuthService>();
    try {
      await repository.deleteCostCenter(
        id: center.id,
        changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Centro eliminado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _saveFiscalYear(
    TreasuryRepository repository,
    TreasurySettings? settings,
    DateTime start,
    DateTime end,
  ) async {
    final auth = context.read<AuthService>();
    final next = (settings ??
            TreasurySettings(
              id: '$_year',
              year: _year,
              annualFeeAmount: 0,
            ))
        .copyWith(fiscalStartDate: start, fiscalEndDate: end);
    await repository.saveSettings(
      next,
      changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
    );
  }

  Future<void> _createAccountingMovement(
    TreasuryRepository repository,
    List<TreasuryCostCenter> centers,
  ) async {
    final auth = context.read<AuthService>();
    if (centers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea centros de coste antes.')),
      );
      return;
    }
    final rootCenters = centers.where((c) => c.parentId.isEmpty).toList();
    final cofrades = await repository.watchCofradesForTreasuryTracking().first;
    var type = 'income';
    var paymentMethod = 'cash';
    var status = 'confirmed';
    var personType = 'none';
    var centerId = rootCenters.first.id;
    var subCenterId = '';
    var date = DateTime.now();
    var cofradeQuery = '';
    final conceptController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final personNameController = TextEditingController();
    final personIdController = TextEditingController();
    final referenceController = TextEditingController();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final subCenters =
              centers.where((center) => center.parentId == centerId).toList();
          return AlertDialog(
            title: const Text('Nuevo movimiento contable'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: type,
                            decoration:
                                const InputDecoration(labelText: 'Tipo'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'income', child: Text('Ingreso')),
                              DropdownMenuItem(
                                  value: 'expense', child: Text('Gasto')),
                            ],
                            onChanged: (value) =>
                                setLocalState(() => type = value ?? 'income'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: amountController,
                            decoration: const InputDecoration(
                              labelText: 'Importe',
                              suffixText: '€',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: conceptController,
                      decoration: const InputDecoration(labelText: 'Concepto'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      decoration:
                          const InputDecoration(labelText: 'Descripción'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: centerId,
                            decoration: const InputDecoration(
                                labelText: 'Centro de coste'),
                            items: rootCenters
                                .map((center) => DropdownMenuItem(
                                      value: center.id,
                                      child: Text(center.name),
                                    ))
                                .toList(),
                            onChanged: (value) => setLocalState(() {
                              centerId = value ?? centerId;
                              subCenterId = '';
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                subCenterId.isEmpty ? null : subCenterId,
                            decoration: const InputDecoration(
                                labelText: 'Subcentro opcional'),
                            items: subCenters
                                .map((center) => DropdownMenuItem(
                                      value: center.id,
                                      child: Text(center.name),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setLocalState(() => subCenterId = value ?? ''),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: paymentMethod,
                            decoration: const InputDecoration(
                                labelText: 'Medio de pago'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'cash', child: Text('Efectivo')),
                              DropdownMenuItem(
                                  value: 'bizum', child: Text('Bizum')),
                              DropdownMenuItem(
                                  value: 'transfer',
                                  child: Text('Transferencia')),
                              DropdownMenuItem(
                                  value: 'bank_remittance',
                                  child: Text('Domiciliación')),
                              DropdownMenuItem(
                                  value: 'card', child: Text('Tarjeta')),
                              DropdownMenuItem(
                                  value: 'other', child: Text('Otro')),
                            ],
                            onChanged: (value) => setLocalState(
                                () => paymentMethod = value ?? 'cash'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: status,
                            decoration:
                                const InputDecoration(labelText: 'Estado'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'pending', child: Text('Pendiente')),
                              DropdownMenuItem(
                                  value: 'confirmed',
                                  child: Text('Confirmado')),
                              DropdownMenuItem(
                                  value: 'cancelled', child: Text('Anulado')),
                            ],
                            onChanged: (value) => setLocalState(
                                () => status = value ?? 'confirmed'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: personType,
                            decoration: const InputDecoration(
                                labelText: 'Persona asociada'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'none',
                                  child: Text('Sin persona asociada')),
                              DropdownMenuItem(
                                  value: 'cofrade', child: Text('Cofrade')),
                              DropdownMenuItem(
                                  value: 'external',
                                  child: Text('Persona externa')),
                              DropdownMenuItem(
                                  value: 'provider',
                                  child: Text('Proveedor / entidad')),
                            ],
                            onChanged: (value) => setLocalState(() {
                              personType = value ?? 'none';
                              personNameController.clear();
                              personIdController.clear();
                              cofradeQuery = '';
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: personType == 'cofrade'
                              ? TextFormField(
                                  initialValue: cofradeQuery,
                                  decoration: const InputDecoration(
                                    labelText: 'Buscar cofrade',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  onChanged: (value) =>
                                      setLocalState(() => cofradeQuery = value),
                                )
                              : TextFormField(
                                  controller: personNameController,
                                  decoration: const InputDecoration(
                                      labelText: 'Nombre persona/entidad'),
                                ),
                        ),
                      ],
                    ),
                    if (personType == 'cofrade') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: personIdController.text.isEmpty
                            ? null
                            : personIdController.text,
                        decoration: const InputDecoration(
                          labelText: 'Cofrade asociado',
                          prefixIcon: Icon(Icons.badge),
                        ),
                        items: _filterCofrades(cofrades, cofradeQuery)
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    '${c.nombreCompleto}${(c.dni ?? '').isEmpty ? '' : ' · ${c.dni}'}',
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) => setLocalState(() {
                          final selected = cofrades.firstWhere(
                            (c) => c.id == value,
                            orElse: () => cofrades.first,
                          );
                          personIdController.text = selected.id;
                          personNameController.text = selected.nombreCompleto;
                        }),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: personIdController,
                        decoration: const InputDecoration(
                          labelText:
                              'ID persona/proveedor opcional para seguimiento',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: referenceController,
                      decoration:
                          const InputDecoration(labelText: 'Referencia'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event),
                      title: const Text('Fecha'),
                      subtitle: Text(
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(_year - 2),
                          lastDate: DateTime(_year + 2, 12, 31),
                        );
                        if (picked != null) {
                          setLocalState(() => date = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
    final concept = conceptController.text.trim();
    final description = descriptionController.text.trim();
    final personName = personNameController.text.trim();
    final personId = personIdController.text.trim();
    final reference = referenceController.text.trim();
    conceptController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    personNameController.dispose();
    personIdController.dispose();
    referenceController.dispose();
    if (confirmed != true || amount == null || amount <= 0 || concept.isEmpty) {
      return;
    }
    await repository.saveAccountingMovement(
      movement: TreasuryAccountingMovement(
        id: '',
        year: _year,
        type: type,
        amount: amount,
        date: date,
        costCenterId: centerId,
        subCostCenterId: subCenterId,
        concept: concept,
        description: description,
        paymentMethod: paymentMethod,
        status: status,
        personType: personType,
        personId: personId,
        personName: personName,
        origin: 'contabilidad',
        reference: reference,
        createdBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
      ),
      changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
    );
  }

  Future<void> _editAccountingMovement(
    TreasuryRepository repository,
    List<TreasuryCostCenter> centers,
    TreasuryAccountingMovement movement,
  ) async {
    final auth = context.read<AuthService>();
    final rootCenters = centers.where((c) => c.parentId.isEmpty).toList();
    if (rootCenters.isEmpty) return;
    final cofrades = await repository.watchCofradesForTreasuryTracking().first;
    var centerId = movement.costCenterId.isEmpty
        ? rootCenters.first.id
        : movement.costCenterId;
    var subCenterId = movement.subCostCenterId;
    var status = movement.status;
    var personType = movement.personType.isEmpty ? 'none' : movement.personType;
    var cofradeQuery = movement.personName;
    final conceptController = TextEditingController(text: movement.concept);
    final descriptionController =
        TextEditingController(text: movement.description);
    final referenceController = TextEditingController(text: movement.reference);
    final personNameController =
        TextEditingController(text: movement.personName);
    final personIdController = TextEditingController(text: movement.personId);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final subCenters =
              centers.where((center) => center.parentId == centerId).toList();
          return AlertDialog(
            title: const Text('Editar movimiento'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: conceptController,
                      decoration: const InputDecoration(labelText: 'Concepto'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      decoration:
                          const InputDecoration(labelText: 'Descripción'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: centerId,
                            decoration: const InputDecoration(
                                labelText: 'Centro de coste'),
                            items: rootCenters
                                .map((center) => DropdownMenuItem(
                                      value: center.id,
                                      child: Text(center.name),
                                    ))
                                .toList(),
                            onChanged: (value) => setLocalState(() {
                              centerId = value ?? centerId;
                              subCenterId = '';
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                subCenterId.isEmpty ? null : subCenterId,
                            decoration: const InputDecoration(
                                labelText: 'Subcentro opcional'),
                            items: subCenters
                                .map((center) => DropdownMenuItem(
                                      value: center.id,
                                      child: Text(center.name),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setLocalState(() => subCenterId = value ?? ''),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: const [
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pendiente')),
                        DropdownMenuItem(
                            value: 'confirmed', child: Text('Confirmado')),
                        DropdownMenuItem(
                            value: 'returned', child: Text('Devuelto')),
                        DropdownMenuItem(
                            value: 'cancelled', child: Text('Anulado')),
                      ],
                      onChanged: (value) =>
                          setLocalState(() => status = value ?? status),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: personType,
                            decoration: const InputDecoration(
                                labelText: 'Persona asociada'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'none',
                                  child: Text('Sin persona asociada')),
                              DropdownMenuItem(
                                  value: 'cofrade', child: Text('Cofrade')),
                              DropdownMenuItem(
                                  value: 'external',
                                  child: Text('Persona externa')),
                              DropdownMenuItem(
                                  value: 'provider',
                                  child: Text('Proveedor / entidad')),
                            ],
                            onChanged: (value) => setLocalState(() {
                              personType = value ?? 'none';
                              personNameController.clear();
                              personIdController.clear();
                              cofradeQuery = '';
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: personType == 'cofrade'
                              ? TextFormField(
                                  initialValue: cofradeQuery,
                                  decoration: const InputDecoration(
                                    labelText: 'Buscar cofrade',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  onChanged: (value) =>
                                      setLocalState(() => cofradeQuery = value),
                                )
                              : TextFormField(
                                  controller: personNameController,
                                  decoration: const InputDecoration(
                                      labelText: 'Nombre persona/entidad'),
                                ),
                        ),
                      ],
                    ),
                    if (personType == 'cofrade') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: personIdController.text.isEmpty
                            ? null
                            : personIdController.text,
                        decoration: const InputDecoration(
                          labelText: 'Cofrade asociado',
                          prefixIcon: Icon(Icons.badge),
                        ),
                        items: _filterCofrades(cofrades, cofradeQuery)
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.nombreCompleto),
                                ))
                            .toList(),
                        onChanged: (value) => setLocalState(() {
                          final selected = cofrades.firstWhere(
                            (c) => c.id == value,
                            orElse: () => cofrades.first,
                          );
                          personIdController.text = selected.id;
                          personNameController.text = selected.nombreCompleto;
                        }),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: referenceController,
                      decoration:
                          const InputDecoration(labelText: 'Referencia'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Factura, remesa, cobro y auditoría de creación se conservan como campos de origen no editables.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar cambios'),
              ),
            ],
          );
        },
      ),
    );
    final concept = conceptController.text.trim();
    final description = descriptionController.text.trim();
    final reference = referenceController.text.trim();
    final personName = personNameController.text.trim();
    final personId = personIdController.text.trim();
    conceptController.dispose();
    descriptionController.dispose();
    referenceController.dispose();
    personNameController.dispose();
    personIdController.dispose();
    if (confirmed != true || concept.isEmpty) return;
    await repository.updateAccountingMovementEditable(
      movementId: movement.id,
      values: {
        'concept': concept,
        'description': description,
        'costCenterId': centerId,
        'subCostCenterId': subCenterId,
        'status': status,
        'reference': reference,
        'personType': personType,
        'personId': personId,
        'personName': personName,
      },
      changedBy: auth.userId ?? auth.cofrade?.id ?? 'unknown',
    );
  }

  List<Cofrade> _filterCofrades(List<Cofrade> cofrades, String query) {
    final normalized = query.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? cofrades
        : cofrades.where((c) {
            final text = [
              c.nombre,
              c.apellidos,
              c.nombreCompleto,
              c.dni ?? '',
              c.telefonoMovil,
              c.telefonoFijo,
            ].join(' ').toLowerCase();
            return text.contains(normalized);
          }).toList();
    return filtered.take(20).toList();
  }
}

class _AccountingKpi extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isMoney;

  const _AccountingKpi({
    required this.label,
    required this.value,
    required this.color,
    this.isMoney = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 245,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Text(
                isMoney
                    ? '${value.toStringAsFixed(2)} €'
                    : value.toStringAsFixed(0),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceDetailCard extends StatelessWidget {
  final List<TreasuryAccountingMovement> movements;
  final List<TreasuryCostCenter> centers;
  final bool canManage;
  final ValueChanged<TreasuryAccountingMovement> onEdit;

  const _BalanceDetailCard({
    required this.movements,
    required this.centers,
    required this.canManage,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<TreasuryAccountingMovement>.from(movements)
      ..sort((a, b) =>
          (b.date ?? DateTime(1900)).compareTo(a.date ?? DateTime(1900)));
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text('Balance anual',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              const Text('No hay movimientos contables en este ejercicio.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final movement = sorted[index];
                    final centerName = _centerName(movement.costCenterId);
                    final subCenterName = _centerName(movement.subCostCenterId);
                    final color = movement.type == 'income'
                        ? AppTheme.accentColor
                        : Colors.red.shade700;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        movement.type == 'income'
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: color,
                      ),
                      title: Text(_movementTypeLabel(movement)),
                      subtitle: Text(
                        '${_fmt(movement.date)} · ${movement.concept}'
                        '\n${centerName.isEmpty ? 'Sin centro' : centerName}'
                        '${subCenterName.isEmpty ? '' : ' / $subCenterName'}'
                        '${movement.personName.isEmpty ? '' : ' · ${movement.personName}'}'
                        '${movement.reference.isEmpty ? '' : ' · Ref. ${movement.reference}'}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        '${movement.amount.toStringAsFixed(2)} €',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      onTap: canManage ? () => onEdit(movement) : null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _centerName(String id) {
    if (id.isEmpty) return '';
    for (final center in centers) {
      if (center.id == id) return center.name;
    }
    return id;
  }

  String _movementTypeLabel(TreasuryAccountingMovement movement) {
    final concept = movement.concept.trim();
    if (concept.isNotEmpty) return concept;
    if (movement.origin == 'remesa' && movement.status == 'returned') {
      return 'Rechazo bancario';
    }
    if (movement.origin == 'remesa') return 'Cobro por remesa';
    if (movement.origin == 'manual' && movement.type == 'income') {
      return 'Cobro manual';
    }
    if (movement.origin == 'facturacion') return 'Factura generada';
    if (movement.type == 'expense') return 'Gasto manual';
    return 'Ingreso manual';
  }
}

class _AccountingActionsCard extends StatelessWidget {
  final bool canManage;
  final List<TreasuryCostCenter> centers;
  final VoidCallback onCreateMovement;

  const _AccountingActionsCard({
    required this.canManage,
    required this.centers,
    required this.onCreateMovement,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.add_chart, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Movimientos contables manuales',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(
                    'Registra ingresos o gastos con centro de coste, persona asociada y estado.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (canManage)
              ElevatedButton.icon(
                onPressed: centers.isEmpty ? null : onCreateMovement,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo movimiento'),
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetOverviewCard extends StatelessWidget {
  final List<TreasuryCostCenter> centers;

  const _BudgetOverviewCard({required this.centers});

  @override
  Widget build(BuildContext context) {
    final roots = centers.where((center) => center.parentId.isEmpty).toList();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text('Presupuesto anual',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            if (roots.isEmpty)
              const Text('No hay presupuesto configurado por centros.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: roots.length,
                  itemBuilder: (context, index) {
                    final root = roots[index];
                    final children = centers
                        .where((center) => center.parentId == root.id)
                        .toList();
                    final planned = root.budgetAmount +
                        children.fold<double>(
                            0, (total, center) => total + center.budgetAmount);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_tree,
                          color: AppTheme.primaryColor),
                      title: Text(root.name),
                      subtitle: Text(
                        '${children.length} subcentro${children.length == 1 ? '' : 's'} · Estado: ${planned > 0 ? 'Dentro de presupuesto' : 'Sin presupuesto'}',
                      ),
                      trailing: Text(
                        '${planned.toStringAsFixed(2)} €',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FiscalYearCard extends StatefulWidget {
  final int year;
  final TreasurySettings? settings;
  final bool canManage;
  final Future<void> Function(DateTime start, DateTime end) onSave;

  const _FiscalYearCard({
    required this.year,
    required this.settings,
    required this.canManage,
    required this.onSave,
  });

  @override
  State<_FiscalYearCard> createState() => _FiscalYearCardState();
}

class _FiscalYearCardState extends State<_FiscalYearCard> {
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _FiscalYearCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year ||
        oldWidget.settings?.updatedAt != widget.settings?.updatedAt) {
      _load();
    }
  }

  void _load() {
    _start = widget.settings?.fiscalStartDate ?? DateTime(widget.year);
    _end = widget.settings?.fiscalEndDate ?? DateTime(widget.year, 12, 31);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.date_range, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ejercicio fiscal',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${_fmt(_start)} - ${_fmt(_end)}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (widget.canManage) ...[
              TextButton.icon(
                onPressed: _saving ? null : () => _pick(true),
                icon: const Icon(Icons.event),
                label: const Text('Inicio'),
              ),
              TextButton.icon(
                onPressed: _saving ? null : () => _pick(false),
                icon: const Icon(Icons.event_busy),
                label: const Text('Fin'),
              ),
              ElevatedButton.icon(
                onPressed:
                    _saving || _start == null || _end == null ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(widget.year),
      firstDate: DateTime(widget.year - 2),
      lastDate: DateTime(widget.year + 2, 12, 31),
    );
    if (picked != null) {
      setState(() {
        if (start) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_start == null || _end == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_start!, _end!);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmt(DateTime? date) {
    if (date == null) return 'Sin definir';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _CostCentersCard extends StatelessWidget {
  final List<TreasuryCostCenter> centers;
  final bool canManage;
  final bool seeding;
  final VoidCallback onSeedDefaults;
  final void Function(TreasuryCostCenter? center, String parentId) onSave;
  final ValueChanged<TreasuryCostCenter> onDelete;

  const _CostCentersCard({
    required this.centers,
    required this.canManage,
    required this.seeding,
    required this.onSeedDefaults,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Centros de coste',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (canManage)
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: seeding ? null : onSeedDefaults,
                        icon: seeding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_fix_high),
                        label: const Text('Crear base'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => onSave(null, ''),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (centers.isEmpty)
              const Text('No hay centros de coste configurados.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount:
                      centers.where((center) => center.parentId.isEmpty).length,
                  itemBuilder: (context, index) {
                    final roots = centers
                        .where((center) => center.parentId.isEmpty)
                        .toList();
                    final center = roots[index];
                    final children = centers
                        .where((child) => child.parentId == center.id)
                        .toList();
                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      leading: Icon(
                        center.isActive
                            ? Icons.check_circle
                            : Icons.pause_circle,
                        color: center.isActive
                            ? AppTheme.accentColor
                            : Colors.grey,
                      ),
                      title: Text(center.name),
                      subtitle: Text(
                        '${center.description.isEmpty ? 'Sin descripción' : center.description} · Presupuesto ${center.budgetAmount.toStringAsFixed(2)} €',
                      ),
                      trailing: canManage
                          ? Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Añadir subcentro',
                                  onPressed: () => onSave(null, center.id),
                                  icon: const Icon(Icons.add),
                                ),
                                IconButton(
                                  tooltip: 'Editar',
                                  onPressed: () => onSave(center, ''),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  onPressed: () => onDelete(center),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            )
                          : null,
                      children: children
                          .map(
                            (child) => ListTile(
                              contentPadding:
                                  const EdgeInsets.only(left: 48, right: 8),
                              leading: Icon(
                                child.isActive
                                    ? Icons.subdirectory_arrow_right
                                    : Icons.pause_circle,
                                color: child.isActive
                                    ? AppTheme.primaryColor
                                    : Colors.grey,
                              ),
                              title: Text(child.name),
                              subtitle: Text(
                                '${child.description.isEmpty ? 'Sin descripción' : child.description} · Presupuesto ${child.budgetAmount.toStringAsFixed(2)} €',
                              ),
                              trailing: canManage
                                  ? Wrap(
                                      spacing: 4,
                                      children: [
                                        IconButton(
                                          tooltip: 'Editar',
                                          onPressed: () => onSave(child, ''),
                                          icon: const Icon(Icons.edit),
                                        ),
                                        IconButton(
                                          tooltip: 'Eliminar',
                                          onPressed: () => onDelete(child),
                                          icon:
                                              const Icon(Icons.delete_outline),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TreasuryControlScreen extends StatelessWidget {
  const TreasuryControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TreasuryRepository>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings,
                    color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text('Soporte y control',
                    style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<TreasuryAuditLog>>(
              stream: repository.watchAuditLogs(),
              builder: (context, snap) {
                return _TreasuryControlCard(
                  title: 'Auditoría',
                  icon: Icons.manage_search,
                  child: _AuditLogList(logs: snap.data ?? const []),
                );
              },
            ),
            const SizedBox(height: 16),
            _TreasuryControlCard(
              title: 'Documentación económica',
              icon: Icons.folder_copy,
              child: _EconomicDocumentationPanel(),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: repository.watchTreasuryNotifications(),
              builder: (context, snap) {
                return _TreasuryControlCard(
                  title: 'Notificaciones económicas',
                  icon: Icons.notifications_active,
                  child: _TreasuryNotificationsList(
                    notifications: snap.data ?? const [],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _TreasuryControlCard(
              title: 'Roles y permisos',
              icon: Icons.verified_user,
              child: _TreasuryPermissionsMatrix(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreasuryControlCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _TreasuryControlCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _AuditLogList extends StatelessWidget {
  final List<TreasuryAuditLog> logs;

  const _AuditLogList({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Text('Todavía no hay acciones auditadas.');
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: logs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final log = logs[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history, color: AppTheme.primaryColor),
            title: Text(_auditActionLabel(log.action)),
            subtitle: Text(
              '${_fmtDateTime(log.changedAt)} · ${log.entityType}/${log.entityId}'
              '${(log.changedBy ?? '').isEmpty ? '' : ' · ${log.changedBy}'}',
            ),
          );
        },
      ),
    );
  }

  String _auditActionLabel(String action) {
    switch (action) {
      case 'generate_final_invoices':
        return 'Generación de facturas';
      case 'generate_remittance':
      case 'generate_remittance_with_unvalidated_records':
        return 'Generación de remesa';
      case 'update_collection_result':
        return 'Cambio de resultado de cobro';
      case 'manual_payment_recorded':
        return 'Cobro manual confirmado';
      case 'create_accounting_movement':
        return 'Alta de ingreso/gasto';
      case 'edit_accounting_movement':
        return 'Edición de movimiento';
      case 'update_cost_center':
      case 'create_cost_center':
      case 'delete_cost_center':
        return 'Cambio de centro/subcentro';
      case 'bank_validation_confirmed':
        return 'Validación bancaria';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  String _fmtDateTime(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _EconomicDocumentationPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const areas = [
      'Facturas',
      'Justificantes de pago',
      'Remesas',
      'Presupuestos',
      'Balances',
      'Donaciones',
      'Gastos',
      'Ingresos',
      'Documentación bancaria',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estructura preparada para vincular documentos a factura, remesa, movimiento, cofrade/persona, centro de coste y ejercicio fiscal.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: areas
              .map((area) => Chip(
                    avatar: const Icon(Icons.description, size: 16),
                    label: Text(area),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _TreasuryNotificationsList extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;

  const _TreasuryNotificationsList({required this.notifications});

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const Text('No hay novedades económicas recientes.');
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = notifications[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.notifications, color: AppTheme.primaryColor),
            title: Text('${item['titulo'] ?? 'Novedad económica'}'),
            subtitle: Text('${item['descripcion'] ?? ''}'),
            trailing: Text('${item['visible_para'] ?? ''}'),
          );
        },
      ),
    );
  }
}

class _TreasuryPermissionsMatrix extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const rows = [
      ['Admin', 'Acceso completo al módulo y configuración'],
      ['Tesorero', 'Facturas, cobros, remesas, contabilidad y presupuestos'],
      ['Contabilidad', 'Movimientos, centros de coste, presupuesto y balance'],
      ['Consulta', 'Solo lectura de paneles e informes'],
      ['Cofrade', 'Facturas, cuotas, movimientos y notificaciones propias'],
    ];
    return Table(
      columnWidths: const {0: FixedColumnWidth(150), 1: FlexColumnWidth()},
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade200),
      ),
      children: rows
          .map(
            (row) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(row[0],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(row[1]),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}
