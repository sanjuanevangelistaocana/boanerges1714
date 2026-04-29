import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';

class TreasuryInvoiceService {
  final TreasuryRepository repository;

  TreasuryInvoiceService({TreasuryRepository? repository})
      : repository = repository ?? TreasuryRepository();

  Stream<List<TreasuryInvoice>> getInvoicesByYear(int year) =>
      repository.getInvoicesByYear(year);

  Stream<List<TreasuryInvoiceLine>> getInvoiceLinesByYear(int year) =>
      repository.getInvoiceLinesByYear(year);

  Future<TreasuryInvoice?> getInvoice(String invoiceId) =>
      repository.getInvoice(invoiceId);

  Stream<List<TreasuryInvoiceLine>> getInvoiceLines(String invoiceId) =>
      repository.getInvoiceLines(invoiceId);

  Future<TreasuryGenerationResult> generateAnnualFees({
    required int year,
    required String generatedBy,
    bool forceRegenerate = false,
  }) {
    return repository.generateAnnualFees(
      year: year,
      generatedBy: generatedBy,
      forceRegenerate: forceRegenerate,
    );
  }

  Future<void> approveInvoice(String invoiceId, String approvedBy) =>
      repository.approveInvoice(invoiceId, approvedBy);

  Future<void> cancelInvoice(String invoiceId, String cancelledBy) =>
      repository.cancelInvoice(invoiceId, cancelledBy);
}
