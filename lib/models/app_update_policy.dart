/// Android ordonne les applications par versionCode, jamais par leur nom.
/// `version` est une étiquette d'affichage (par exemple « 1.0.13 »).
class AppRelease implements Comparable<AppRelease> {
  AppRelease(this.version, this.build) {
    if (version.trim().isEmpty ||
        version.length > 64 ||
        build < 0 ||
        build > 2100000000) {
      throw const FormatException('Version Android invalide');
    }
  }
  final String version;
  final int build;
  String get id => '$version+$build';
  @override
  int compareTo(AppRelease other) => build.compareTo(other.build);
}

class AppUpdatePolicy {
  const AppUpdatePolicy(
      {required this.enabled,
      required this.latest,
      required this.minVersionCode,
      required this.storeUrl,
      required this.releaseNotes,
      required this.remindAfterHours});

  final bool enabled;
  final AppRelease latest;
  final int minVersionCode;
  final Uri storeUrl;
  final Map<String, String> releaseNotes;
  final int remindAfterHours;

  factory AppUpdatePolicy.fromJson(Map<String, dynamic> json) {
    // Une réponse incomplète n'est pas une désactivation : conserver une
    // obligation connue plutôt que la remplacer par des valeurs par défaut.
    if (json['enabled'] is! bool ||
        json['latestVersion'] is! String ||
        json['latestVersionCode'] is! int ||
        json['minVersionCode'] is! int ||
        json['updateUrl'] is! String ||
        json['releaseNotes'] is! Map ||
        json['releaseNotes']['fr'] is! String ||
        json['releaseNotes']['en'] is! String ||
        json['remindAfterHours'] is! int) {
      throw const FormatException('Politique de mise à jour incomplète');
    }
    final latest = AppRelease(json['latestVersion'], json['latestVersionCode']);
    final minimum = json['minVersionCode'] as int;
    final hours = json['remindAfterHours'] as int;
    final url = Uri.tryParse(json['updateUrl']);
    if (minimum < 0 ||
        minimum > latest.build ||
        hours < 1 ||
        hours > 720 ||
        (json['enabled'] && latest.build == 0) ||
        url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty) {
      throw const FormatException('Politique de mise à jour incohérente');
    }
    return AppUpdatePolicy(
        enabled: json['enabled'],
        latest: latest,
        minVersionCode: minimum,
        storeUrl: url,
        remindAfterHours: hours,
        releaseNotes: Map<String, String>.unmodifiable({
          'fr': json['releaseNotes']['fr'],
          'en': json['releaseNotes']['en'],
        }));
  }

  String notesFor(String languageCode) {
    final preferred = releaseNotes[languageCode]?.trim() ?? '';
    if (preferred.isNotEmpty) return preferred;
    final french = releaseNotes['fr']?.trim() ?? '';
    return french.isNotEmpty ? french : (releaseNotes['en'] ?? '');
  }

  bool requiresUpdate(AppRelease installed) =>
      enabled && installed.build < minVersionCode;
  bool hasUpdate(AppRelease installed) =>
      enabled && installed.build < latest.build;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'latestVersion': latest.version,
        'latestVersionCode': latest.build,
        'minVersionCode': minVersionCode,
        'updateUrl': storeUrl.toString(),
        'releaseNotes': releaseNotes,
        'remindAfterHours': remindAfterHours,
      };
}
