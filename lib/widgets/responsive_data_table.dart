import 'package:flutter/material.dart';
import 'package:boanerges1714/config/responsive.dart';

class ResponsiveTableColumn {
  final String label;
  final Widget? heading;
  final int mobilePriority;
  final bool numeric;

  const ResponsiveTableColumn({
    required this.label,
    this.heading,
    this.mobilePriority = 0,
    this.numeric = false,
  });
}

class ResponsiveTableRow {
  final List<Widget> cells;
  final Widget? actions;

  const ResponsiveTableRow({
    required this.cells,
    this.actions,
  });
}

class ResponsiveDataTable extends StatelessWidget {
  final List<ResponsiveTableColumn> columns;
  final List<ResponsiveTableRow> rows;
  final int maxMobilePriority;
  final double columnSpacing;
  final double? headingRowHeight;

  const ResponsiveDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.maxMobilePriority = 2,
    this.columnSpacing = 56,
    this.headingRowHeight,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!context.responsive.isMobile) {
          return DataTable(
            columnSpacing: columnSpacing,
            headingRowHeight: headingRowHeight,
            columns: columns
                .map(
                  (column) => DataColumn(
                    label: column.heading ?? Text(column.label),
                    numeric: column.numeric,
                  ),
                )
                .toList(),
            rows: rows
                .map(
                  (row) => DataRow(
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
