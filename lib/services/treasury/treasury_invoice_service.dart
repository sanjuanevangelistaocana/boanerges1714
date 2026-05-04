import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';

class TreasuryInvoiceService {
  final TreasuryRepository repository;

  TreasuryInvoiceService({TreasuryRepository? repository})
      : repository = repository ?? TreasuryRepository();

  Stream<List<TreasuryInvoice>> getInvoicesByYear(int year) =>
      repository.getInvoicesByYear(year);

  Stream<List<TreasuryInvoice>> getInvoicesForCofrade(String cofradeId) =>
      repository.getInvoicesForCofrade(cofradeId);

  Stream<List<TreasuryInvoice>> getInvoicesForAuthUid(String authUid) =>
      repository.getInvoicesForAuthUid(authUid);

  Stream<List<TreasuryFeeDraft>> getFeeDraftsByYear(int year) =>
      repository.getFeeDraftsByYear(year);

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
    return repository.generateFeeDrafts(
      year: year,
      generatedBy: generatedBy,
      forceRegenerate: forceRegenerate,
    );
  }

  Future<void> reviewFeeDraft({
    required String feeDraftId,
    required String changedBy,
  }) {
    return repository.approveFeeDraft(
      feeDraftId: feeDraftId,
      changedBy: changedBy,
    );
  }

  Future<void> updateFeeDraft({
    required String feeDraftId,
    required double amount,
    required String concept,
    required String paymentMethod,
    required String changedBy,
  }) {
    return repository.updateFeeDraft(
      feeDraftId: feeDraftId,
      amount: amount,
      concept: concept,
      paymentMethod: paymentMethod,
      changedBy: changedBy,
    );
  }

  Future<int> reviewAllFeeDrafts({
    required int year,
    required String changedBy,
  }) {
    return repository.approveAllFeeDrafts(
      year: year,
      changedBy: changedBy,
    );
  }

  Future<TreasuryFinalInvoiceGenerationResult> generateFinalInvoices({
    required int year,
    required String generatedBy,
  }) {
    return repository.generateFinalInvoices(
      year: year,
      generatedBy: generatedBy,
    );
  }

  Future<void> markInvoicePdfGenerated({
    required String invoiceId,
    required String pdfUrl,
    required String generatedBy,
  }) {
    return repository.markInvoicePdfGenerated(
      invoiceId: invoiceId,
      pdfUrl: pdfUrl,
      generatedBy: generatedBy,
    );
  }

  Future<void> approveInvoice(String invoiceId, String approvedBy) =>
      repository.approveInvoice(invoiceId, approvedBy);

  Future<void> cancelInvoice(String invoiceId, String cancelledBy) =>
      repository.cancelInvoice(invoiceId, cancelledBy);
}
