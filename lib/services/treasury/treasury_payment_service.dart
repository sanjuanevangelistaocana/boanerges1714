import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';

class TreasuryPaymentService {
  final TreasuryRepository repository;

  TreasuryPaymentService({TreasuryRepository? repository})
      : repository = repository ?? TreasuryRepository();

  Stream<List<TreasuryPayment>> getPaymentsByYear(int year) =>
      repository.getPaymentsByYear(year);
}
