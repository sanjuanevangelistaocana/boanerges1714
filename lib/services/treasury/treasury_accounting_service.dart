import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';

class TreasuryAccountingService {
  final TreasuryRepository repository;

  TreasuryAccountingService({TreasuryRepository? repository})
      : repository = repository ?? TreasuryRepository();

  Stream<List<TreasuryAccountingMovement>> getAccountingMovementsByYear(
          int year) =>
      repository.getAccountingMovementsByYear(year);
}
