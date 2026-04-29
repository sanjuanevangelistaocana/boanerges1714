import 'package:boanerges1714/services/treasury/treasury_repository.dart';

class TreasuryAuditService {
  final TreasuryRepository repository;

  TreasuryAuditService({TreasuryRepository? repository})
      : repository = repository ?? TreasuryRepository();

  Future<void> createAuditLog({
    required String entityType,
    required String entityId,
    required String action,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? changedBy,
  }) {
    return repository.createAuditLog(
      entityType: entityType,
      entityId: entityId,
      action: action,
      oldValue: oldValue,
      newValue: newValue,
      changedBy: changedBy,
    );
  }
}
