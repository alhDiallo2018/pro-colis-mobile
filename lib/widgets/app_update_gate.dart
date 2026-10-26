import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_update_provider.dart';

/// Au-dessus du routeur et du verrouillage biométrique : une notification ou
/// un lien profond ne doit pas masquer une mise à jour obligatoire.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate(
      {super.key,
      required this.child,
      required this.backButtonDispatcher,
      this.openStore});
  final Widget child;
  final BackButtonDispatcher backButtonDispatcher;
  final Future<bool> Function(Uri)? openStore;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  late final ChildBackButtonDispatcher _backDispatcher;
  Timer? _timer;
  bool _opening = false;
  bool _returningFromStore = false;
  String? _storeError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _backDispatcher = widget.backButtonDispatcher
        .createChildBackButtonDispatcher()
      ..addCallback(_onBack);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) {
      unawaited(ref.read(appUpdateProvider.notifier).refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      // Ouvrir le store ne prouve pas que la mise à jour a été installée.
      // Toujours relire la version et la politique au retour, même avant 1 min.
      final force =
          _returningFromStore || ref.read(appUpdateProvider).mandatory;
      _returningFromStore = false;
      unawaited(ref.read(appUpdateProvider.notifier).refresh(force: force));
    } else {
      _timer?.cancel();
    }
  }

  bool get _starting =>
      ref.read(appUpdateProvider.notifier).supported &&
      !ref.read(appUpdateProvider).initialized;

  // Le gate est au-dessus des routes : PopScope seul ne capterait pas Retour.
  Future<bool> _onBack() async =>
      _starting || ref.read(appUpdateProvider).showPrompt;

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _backDispatcher.removeCallback(_onBack);
    widget.backButtonDispatcher.forget(_backDispatcher);
    super.dispose();
  }

  Future<void> _openStore() async {
    final url = ref.read(appUpdateProvider).policy?.storeUrl;
    if (url == null || _opening) return;
    setState(() {
      _opening = true;
      _storeError = null;
    });
    try {
      _returningFromStore = true;
      final opened = await (widget.openStore?.call(url) ??
          launchUrl(url, mode: LaunchMode.externalApplication));
      if (!opened) throw StateError('Ouverture du store refusée');
    } catch (error, stack) {
      _returningFromStore = false;
      debugPrint('[AppUpdate] Ouverture du store : ${error.runtimeType}');
      debugPrintStack(stackTrace: stack);
      if (mounted)
        setState(() => _storeError =
            'Impossible d’ouvrir le Play Store. Vérifiez votre connexion et réessayez.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = ref.watch(appUpdateProvider);
    final starting = _starting;
    final blocking = starting || update.showPrompt;
    // Attendre que le routeur enfant ait enregistré son callback avant de
    // prendre la priorité, y compris au démarrage avec une politique en cache.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_starting || ref.read(appUpdateProvider).showPrompt) {
        _backDispatcher.takePriority();
      } else {
        widget.backButtonDispatcher.forget(_backDispatcher);
      }
    });

    final policy = update.policy;
    final notes = policy?.notesFor(
            WidgetsBinding.instance.platformDispatcher.locale.languageCode) ??
        '';
    final title = update.mandatory
        ? 'Mise à jour obligatoire'
        : 'Une mise à jour est disponible';
    final description = update.mandatory
        ? 'Votre version de SendProcolis n’est plus prise en charge. Mettez l’application à jour pour continuer.'
        : 'Découvrez les dernières améliorations de SendProcolis.';

    final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Nouveautés', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(notes),
          ],
          if (policy != null && update.installed != null) ...[
            const SizedBox(height: 20),
            Text(
                'Version installée : ${update.installed!.version}\nVersion disponible : ${policy.latest.version}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (update.checkFailed) ...[
            const SizedBox(height: 16),
            const Text(
                'La vérification est indisponible. Vérifiez votre connexion et réessayez.'),
          ],
          if (_storeError != null) ...[
            const SizedBox(height: 16),
            Text(_storeError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ]);
    final storeButton = FilledButton.icon(
        onPressed: _opening ? null : _openStore,
        icon: const Icon(Icons.system_update_alt),
        label: Text(_opening ? 'Ouverture…' : 'Mettre à jour'));
    final retryButton = TextButton(
        onPressed: update.checking
            ? null
            : () => ref.read(appUpdateProvider.notifier).refresh(force: true),
        child: Text(update.checking ? 'Vérification…' : 'Réessayer'));

    return Stack(children: [
      // La saisie est conservée mais inaccessible au tactile, clavier et
      // lecteur d'écran tant que le contrôle ou la demande sont affichés.
      ExcludeFocus(
          excluding: blocking,
          child: ExcludeSemantics(
              excluding: blocking,
              child: IgnorePointer(ignoring: blocking, child: widget.child))),
      if (update.mandatory)
        Positioned.fill(
            child: Scaffold(
          body: SafeArea(
              child: Center(
                  child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.system_update_rounded,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 28),
                      Text(title,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      content,
                      const SizedBox(height: 28),
                      storeButton,
                      const SizedBox(height: 12),
                      retryButton,
                    ])),
          ))),
        ))
      else if (starting)
        const Positioned.fill(
            child: Scaffold(
                body: Center(
                    child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Vérification de la version…'),
          ],
        ))))
      else if (update.showPrompt) ...[
        const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Colors.black54)),
        Positioned.fill(
            child: SafeArea(
                child: FocusScope(
          autofocus: true,
          child: AlertDialog(
            scrollable: true,
            icon: const Icon(Icons.system_update_rounded),
            title: Text(title),
            content: content,
            actions: [
              TextButton(
                  onPressed: () =>
                      ref.read(appUpdateProvider.notifier).dismiss(),
                  child: const Text('Plus tard')),
              if (update.checkFailed) retryButton,
              storeButton,
            ],
          ),
        ))),
      ],
    ]);
  }
}

/// L'utilisateur peut retrouver une mise à jour même après « Plus tard ».
class AppUpdateSettingsTile extends ConsumerWidget {
  const AppUpdateSettingsTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android)
      return const SizedBox.shrink();
    final update = ref.watch(appUpdateProvider);
    final available = update.installed != null &&
        (update.policy?.hasUpdate(update.installed!) ?? false);
    return ListTile(
      leading: const Icon(Icons.system_update),
      title: Text(available ? 'Mise à jour disponible' : 'Mises à jour'),
      subtitle: Text(available
          ? 'Version ${update.policy!.latest.version}'
          : 'Vérifier la version de l’application'),
      trailing: const Icon(Icons.chevron_right),
      onTap: update.checking
          ? null
          : () async {
              await ref.read(appUpdateProvider.notifier).checkNow();
              if (!context.mounted) return;
              final result = ref.read(appUpdateProvider);
              if (!result.showPrompt)
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result.checkFailed
                      ? 'Vérification impossible. Réessayez plus tard.'
                      : 'Votre application est à jour.'),
                ));
            },
    );
  }
}
