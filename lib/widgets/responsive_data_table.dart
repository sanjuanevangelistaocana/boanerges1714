import 'package:flutter/material.dart';
import 'package:boanerges1714/config/responsive.dart';

typedef ResponsiveSortCallback = void Function(
  int columnIndex,
  bool ascending,
);

typedef ResponsiveRowSelectionCallback = void Function(
  int rowIndex,
  bool selected,
);

class ResponsiveTableColumn {
  final String label;
  final Widget? heading;
  final int mobilePriority;
  final bool numeric;
  final void Function(int columnIndex, bool ascending)? onSort;

  const ResponsiveTableColumn({
    required this.label,
    this.heading,
    this.mobilePriority = 0,
    this.numeric = false,
    this.onSort,
  });
}

class ResponsiveTableRow {
  final List<Widget> cells;
  final Widget? actions;
  final bool selected;
  final ValueChanged<bool?>? onSelectChanged;

  const ResponsiveTableRow({
    required this.cells,
    this.actions,
    this.selected = false,
    this.onSelectChanged,
  });
}

class ResponsiveDataTable extends StatelessWidget {
  final List<ResponsiveTableColumn> columns;
  final List<ResponsiveTableRow> rows;
  final int maxMobilePriority;
  final double columnSpacing;
  final double? headingRowHeight;
  final int? sortColumnIndex;
  final bool sortAscending;
  final ResponsiveSortCallback? onSort;
  final bool showCheckboxColumn;
  final Widget? header;
  final Widget? headerActions;
  final Widget? emptyState;

  const ResponsiveDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.maxMobilePriority = 2,
    this.columnSpacing = 56,
    this.headingRowHeight,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
    this.showCheckboxColumn = false,
    this.header,
    this.headerActions,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    final tableContent = LayoutBuilder(
      builder: (context, constraints) {
        if (rows.isEmpty && emptyState != null) {
          return emptyState!;
        }
        if (!context.responsive.isMobile) {
          return DataTable(
            columnSpacing: columnSpacing,
            headingRowHeight: headingRowHeight,
            sortColumnIndex: sortColumnIndex,
            sortAscending: sortAscending,
            showCheckboxColumn: showCheckboxColumn ||
                rows.any((row) => row.onSelectChanged != null),
            columns: columns
                .map(
                  (column) => DataColumn(
                    label: column.heading ?? Text(column.label),
                    numeric: column.numeric,
                    onSort: column.onSort ??
                        (onSort == null
                            ? null
                            : (index, ascending) => onSort!(index, ascending)),
                  ),
                )
                .toList(),
            rows: rows
                .map(
                  (row) => DataRow(
                    selected: row.selected,
                    onSelectChanged: row.onSelectChanged,
                    cells: row.cells.map((cell) => DataCell(cell)).toList(),
                  ),
                )
                .toList(),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows
              .map(
                (row) => _ResponsiveDataCard(
                  columns: columns,
                  row: row,
                  maxMobilePriority: maxMobilePriority,
                ),
              )
              .toList(),
        );
      },
    );
    if (header == null && headerActions == null) return tableContent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null || headerActions != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header != null) Expanded(child: header!),
              if (headerActions != null) ...[
                if (header != null) const SizedBox(width: 12),
                headerActions!,
              ],
            ],
          ),
        tableContent,
      ],
    );
  }
}

class _ResponsiveDataCard extends StatelessWidget {
  final List<ResponsiveTableColumn> columns;
  final ResponsiveTableRow row;
  final int maxMobilePriority;

  const _ResponsiveDataCard({
    required this.columns,
    required this.row,
    required this.maxMobilePriority,
  });

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (var index = 0;
        index < columns.length && index < row.cells.length;
        index++) {
      final column = columns[index];
      if (column.mobilePriority > maxMobilePriority) continue;
      cells.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 112,
                child: Text(
                  column.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: row.cells[index]),
            ],
          ),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...cells,
            if (row.onSelectChanged != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: row.selected,
                onChanged: row.onSelectChanged,
                title: const Text('Seleccionar fila'),
              ),
            if (row.actions != null) ...[
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: row.actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
