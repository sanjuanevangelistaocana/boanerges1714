import 'dart:typed_data';

import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/storage_service.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TreasuryPdfService {
  final TreasuryRepository repository;
  final StorageService storageService;

  TreasuryPdfService({
    TreasuryRepository? repository,
    StorageService? storageService,
  })  : repository = repository ?? TreasuryRepository(),
        storageService = storageService ?? StorageService();

  Future<String> generateAndUploadInvoicePdf({
    required String invoiceId,
    required String generatedBy,
  }) async {
    final invoice = await repository.getInvoice(invoiceId);
    if (invoice == null) throw Exception('Factura no encontrada.');
    final lines = await repository.getInvoiceLinesOnce(invoiceId);
    if (lines.isEmpty) {
      throw Exception('No se puede generar PDF de una factura sin líneas.');
    }
    final bytes = await _buildInvoicePdf(invoice, lines);
    final path = 'treasury/invoices/${invoice.year}/${invoice.id}.pdf';
    final upload = await storageService.uploadBytesAtPath(
      fullPath: path,
      bytes: bytes,
      contentType: 'application/pdf',
      customMetadata: {
        'invoiceId': invoice.id,
        'invoiceNumber': invoice.invoiceNumber,
      },
    );
    final url = upload['url'] ?? '';
    await repository.markInvoicePdfGenerated(
      invoiceId: invoice.id,
      pdfUrl: url,
      generatedBy: generatedBy,
    );
    return url;
  }

  Future<Uint8List> _buildInvoicePdf(
    TreasuryInvoice invoice,
    List<TreasuryInvoiceLine> lines,
  ) async {
    final doc = pw.Document();
    final issuedAt = DateTime.now();
    final total = lines.fold<double>(0, (sum, line) => sum + line.amount);
    final paymentMethod =
        invoice.paymentMethod == 'cash' ? 'Efectivo' : 'Domiciliación bancaria';
    const red = PdfColor.fromInt(0xff8f1d21);
    const lightRed = PdfColor.fromInt(0xfff7ecec);
    const ink = PdfColor.fromInt(0xff2b2b2b);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 34, 42, 34),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 18),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: red, width: 2)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 74,
                  height: 74,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: lightRed,
                    border: pw.Border.all(color: red, width: 1.4),
                  ),
                  child: pw.Text(
                    'SJ',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: red,
                    ),
                  ),
                ),
                pw.SizedBox(width: 18),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'COFRADIA SAN JUAN EVANGELISTA',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: ink,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Ocaña · Toledo',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 16),
                      pw.Text(
                        'FACTURA DE CUOTA ANUAL',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: red,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  width: 170,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _meta('Factura', invoice.invoiceNumber),
                      _meta('Año', '${invoice.year}'),
                      _meta('Fecha emisión', _date(issuedAt)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _infoBox(
                  title: 'Pagador',
                  rows: [
                    ('Titular', invoice.holderName),
                    (
                      'IBAN',
                      invoice.ibanMasked.isEmpty
                          ? 'No domiciliado'
                          : invoice.ibanMasked
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: _infoBox(
                  title: 'Datos de cobro',
                  rows: [
                    ('Forma de pago', paymentMethod),
                    ('Concepto', 'Cuotas ${invoice.year}'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Text(
            'Detalle de la factura',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: ink,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.8),
              1: pw.FlexColumnWidth(3),
              2: pw.FixedColumnWidth(92),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: red),
                children: [
                  _cell('Cofrade', header: true),
                  _cell('Concepto', header: true),
                  _cell('Importe', header: true, alignRight: true),
                ],
              ),
              ...lines.map((line) {
                return pw.TableRow(
                  children: [
                    _cell(line.cofradeNumber == null
                        ? line.cofradeName
                        : '${line.cofradeName} (${line.cofradeNumber})'),
                    _cell(line.concept),
                    _cell('${line.amount.toStringAsFixed(2)} EUR',
                        alignRight: true),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 230,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: const pw.BoxDecoration(color: lightRed),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    pw.Text(
                      '${total.toStringAsFixed(2)} EUR',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 15,
                        color: red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 44),
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Documento generado digitalmente por el módulo de Tesorería',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  invoice.invoiceNumber,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _meta(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(value),
        ],
      ),
    );
  }

  pw.Widget _infoBox({
    required String title,
    required List<(String, String)> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...rows.map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '${row.$1}: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(text: row.$2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _cell(
    String text, {
    bool header = false,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 9.5,
          color: header ? PdfColors.white : PdfColors.black,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
