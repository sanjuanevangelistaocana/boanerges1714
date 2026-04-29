import 'package:boanerges1714/models/treasury.dart';
import 'package:boanerges1714/services/treasury/treasury_repository.dart';

class TreasurySettingsService {
  final TreasuryRepository repository;

  TreasurySettingsService({TreasuryRepository? repository})
      : repository = repository ?? TreasuryRepository();

  Stream<TreasurySettings?> watchActiveSettings() =>
      repository.watchActiveSettings();

  Future<TreasurySettings?> getActiveSettings() =>
      repository.getActiveSettings();

  Future<TreasurySettings?> getSettingsByYear(int year) =>
      repository.getSettingsByYear(year);

  Stream<TreasurySettings?> watchSettingsByYear(int year) =>
      repository.watchSettingsByYear(year);

  Future<String> saveSettings(TreasurySettings settings, {String? changedBy}) =>
      repository.saveSettings(settings, changedBy: changedBy);
}
