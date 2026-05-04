import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';

class TreasuryBankValidationService {
  final TreasuryRepository repository;

  TreasuryBankValidationService({TreasuryRepository? repository})
      : repository = repository ?? TreasuryRepository();

  Stream<List<TreasuryBankValidation>> getBankValidationsByYear(int year) =>
      repository.getBankValidationsByYear(year);

  Stream<List<TreasuryBankValidation>> watchMyBankValidations(
    String authUid, {
    String? cofradeId,
  }) =>
      repository.watchMyBankValidations(authUid, cofradeId: cofradeId);

  Future<TreasuryBankValidationInitializationResult> initializeBankValidations({
    required int year,
    required String changedBy,
  }) {
    return repository.initializeBankValidations(
      year: year,
      changedBy: changedBy,
    );
  }

  Future<TreasuryBankValidationInitializationResult>
      publishBankValidationCampaign({
    required int year,
    required String changedBy,
  }) {
    return repository.publishBankValidationCampaign(
      year: year,
      changedBy: changedBy,
    );
  }

  Future<void> confirmBankValidation({
    required String validationId,
    required String updatedBy,
  }) {
    return repository.confirmBankValidation(
      validationId: validationId,
      updatedBy: updatedBy,
    );
  }

  Future<void> modifyBankValidationIban({
    required String validationId,
    required String newIban,
    required String updatedBy,
  }) {
    return repository.modifyBankValidationIban(
      validationId: validationId,
      newIban: newIban,
      updatedBy: updatedBy,
    );
  }

  Future<int> lockClosedBankValidations({
    required int year,
    required String lockedBy,
  }) {
    return repository.lockClosedBankValidations(
      year: year,
      lockedBy: lockedBy,
    );
  }

  Future<int> closeBankValidationCampaign({
    required int year,
    required String closedBy,
  }) {
    return repository.closeBankValidationCampaign(
      year: year,
      closedBy: closedBy,
    );
  }
}
