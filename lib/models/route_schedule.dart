/// Un planning ne transporte que les nouveaux horaires et le sens choisi.
/// Les arrêts et les données métier restent dans le trajet habituel serveur.
List<Map<String, dynamic>> buildRouteDepartures(
    {required DateTime first,
    required int count,
    required int intervalMinutes,
    required int durationMinutes,
    bool reverseFirst = false,
    bool alternate = false}) {
  if (count < 1 || count > 100)
    throw const FormatException('Choisissez entre 1 et 100 départs.');
  if (count > 1 && (intervalMinutes < durationMinutes || intervalMinutes < 1)) {
    throw const FormatException(
        'L’intervalle doit couvrir la durée du trajet pour ce véhicule.');
  }
  return List.generate(
      count,
      (i) => {
            'departureAt': first
                .add(Duration(minutes: i * intervalMinutes))
                .toUtc()
                .toIso8601String(),
            'reverse': alternate && i.isOdd ? !reverseFirst : reverseFirst
          });
}
