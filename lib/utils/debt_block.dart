import '../models/cancellation.dart';
import '../services/api_service.dart';

const String clientDebtLimitErrorCode = 'CANCELLATION_DEBT_LIMIT_EXCEEDED';
const String driverDebtLimitErrorCode = 'COMMISSION_DEBT_REQUIRED';

String? apiErrorCode(Map<String, dynamic> response) {
  final raw = response['error'];
  return raw is Map ? raw['code']?.toString() : null;
}

bool isDriverDebtBlockResponse(Map<String, dynamic> response) =>
    apiErrorCode(response) == driverDebtLimitErrorCode;

/// Première dette client payable jointe au refus de création par l'API.
/// L'identifiant et le reliquat viennent exclusivement du backend.
CancellationClientDebt? payableClientDebtFrom(ApiException? error) {
  if (error?.code != clientDebtLimitErrorCode) return null;

  for (final detail in error!.details) {
    final rawDebts = detail['debts'];
    if (rawDebts is! List) continue;
    for (final rawDebt in rawDebts) {
      if (rawDebt is! Map) continue;
      final debt = CancellationClientDebt.fromJson(
        Map<String, dynamic>.from(rawDebt),
      );
      if (debt.hasId && (debt.displayedRemaining ?? 0) > 0) return debt;
    }
  }
  return null;
}
