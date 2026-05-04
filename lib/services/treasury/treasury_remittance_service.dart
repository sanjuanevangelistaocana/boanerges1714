import 'dart:convert';
import 'dart:typed_data';

import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/storage_service.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';
import 'package:excel/excel.dart';

class TreasuryRemittanceService {
  final TreasuryRepository repository;
  final StorageService storageService;

  TreasuryRemittanceService({
    TreasuryRepository? repository,
    StorageService? storageService,
  })  : repository = repository ?? TreasuryRepository(),
        storageService = storageService ?? StorageService();

  Stream<List<TreasuryRemittance>> getRemittancesByYear(int year) {
    return repository.getRemittancesByYear(year);
  }

  Future<List<TreasuryRemittanceRow>> previewRows(int year) {
    return repository.getRemittanceRowsByYear(year);
  }

  Future<TreasuryRemittanceGenerationResult> generateRemittance({
    required int year,
    required String generatedBy,
  }) async {
    final rows = await repository.getRemittanceRowsByYear(year);
    if (rows.isEmpty) {
      throw Exception('No hay facturas domiciliadas disponibles para remesa.');
    }
    final generatedAt = DateTime.now();
    final operationDate = generatedAt;
    final csvBytes = Uint8List.fromList(
      utf8.encode(_toCsv(rows, generatedAt, operationDate)),
    );
    final xlsxBytes = Uint8List.fromList(
      _toXlsx(rows, generatedAt, operationDate),
    );
    final stamp =
        '${generatedAt.year}${generatedAt.month.toString().padLeft(2, '0')}${generatedAt.day.toString().padLeft(2, '0')}_${generatedAt.millisecondsSinceEpoch}';
    final csvUpload = await storageService.uploadBytesAtPath(
      fullPath: 'treasury/remittances/$year/remesa_$stamp.csv',
      bytes: csvBytes,
      contentType: 'text/csv',
      customMetadata: {'year': '$year', 'type': 'treasury_remittance_csv'},
    );
    final xlsxUpload = await storageService.uploadBytesAtPath(
      fullPath: 'treasury/remittances/$year/remesa_$stamp.xlsx',
      bytes: xlsxBytes,
      contentType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      customMetadata: {'year': '$year', 'type': 'treasury_remittance_xlsx'},
    );
    final remittance = await repository.saveGeneratedRemittance(
      year: year,
      rows: rows,
      fileUrlCsv: csvUpload['url'] ?? '',
      fileUrlXlsx: xlsxUpload['url'] ?? '',
      generatedBy: generatedBy,
    );
    return TreasuryRemittanceGenerationResult(
      remittance: remittance,
      rows: rows,
      warnings: rows
          .where((row) => row.hasUnvalidatedRecords)
          .map((row) =>
              '${row.invoiceNumber}: incluye registros sin validación bancaria.')
          .toList(),
    );
  }

  String _toCsv(
    List<TreasuryRemittanceRow> rows,
    DateTime issueDate,
    DateTime operationDate,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(_headers.map(_csv).join(';'));
    for (final row in rows) {
      buffer.writeln(
        row
            .toCells(issueDate: issueDate, operationDate: operationDate)
            .map(_csv)
            .join(';'),
      );
    }
    return buffer.toString();
  }

  List<int> _toXlsx(
    List<TreasuryRemittanceRow> rows,
    DateTime issueDate,
    DateTime operationDate,
  ) {
    final excel = Excel.createExcel();
    final sheet = excel['Remesa'];
    sheet.appendRow(_headers.map((header) => TextCellValue(header)).toList());
    for (final row in rows) {
      sheet.appendRow(
        row
            .toCells(issueDate: issueDate, operationDate: operationDate)
            .map((cell) => TextCellValue(cell))
            .toList(),
      );
    }
    excel.delete('Sheet1');
    return excel.encode() ?? <int>[];
  }

  String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  static const _headers = [
    'Tipo operacion',
    'Esquema',
    'Identificador acreedor',
    'Sufijo',
    'Nombre acreedor',
    'NIF/CIF',
    'Codigo sufijo',
    'Fecha remesa',
    'Nombre entidad',
    'IBAN acreedor',
    'Referencia recibo',
    'Importe recibo',
    'Tipo adeudo',
    'Importe',
    'Fecha operacion',
    'Titular deudor',
    'IBAN deudor',
    'Concepto',
  ];
}
