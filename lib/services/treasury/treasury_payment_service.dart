import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';

class TreasuryPaymentService {
  final TreasuryRepository repository;

  TreasuryPaymentService({TreasuryRepository? repository})
      : repository = repository ?? TreasuryRepository();

  Stream<List<TreasuryPayment>> getPaymentsByYear(int year) =>
      repository.getPaymentsByYear(year);

  Stream<List<TreasuryPayment>> getCollectionAttemptsByYear(int year) =>
      repository.getCollectionAttemptsByYear(year);

  Future<void> markPaymentAttempt({
    required String paymentId,
    required String status,
    required String changedBy,
    String rejectionReason = '',
    String method = '',
    String reference = '',
  }) {
    return repository.markPaymentAttempt(
      paymentId: paymentId,
      status: status,
      changedBy: changedBy,
      rejectionReason: rejectionReason,
      method: method,
      reference: reference,
    );
  }

  Future<void> createManualPayment({
    required TreasuryInvoice invoice,
    required String method,
    required String reference,
    required String changedBy,
  }) {
    return repository.createManualPayment(
      invoice: invoice,
      method: method,
      reference: reference,
      changedBy: changedBy,
    );
  }
}
