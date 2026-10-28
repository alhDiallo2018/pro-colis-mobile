/// Codes stables partagés avec le catalogue de l'API.
const vehicleTypes = <String, String>{
  'motorcycle': 'Moto (2 roues)',
  'truck': 'Camion',
  'van': 'Fourgonnette',
  'tricycle': 'Tricycle',
  'bus': 'Bus (Tata, horaire…)',
  'gp': 'GP',
};
String vehicleTypeCode(String? value) {
  final text = (value ?? '').trim().toLowerCase();
  return const {
        'moto': 'motorcycle',
        '2 roues': 'motorcycle',
        '2roues': 'motorcycle',
        'motorbike': 'motorcycle',
        'scooter': 'motorcycle',
        'camion': 'truck',
        'fourgon': 'van',
        'fourgonnette': 'van',
        'minibus': 'bus',
        'autobus': 'bus',
        'tata': 'bus',
        'horaire': 'bus'
      }[text] ??
      text;
}

String vehicleTypeLabel(String? value) =>
    vehicleTypes[vehicleTypeCode(value)] ??
    (value?.isNotEmpty == true ? value! : 'Véhicule non renseigné');
