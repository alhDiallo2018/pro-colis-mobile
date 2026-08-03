import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/pc_components.dart';

/// Remplace l'ancienne page marketing par un diagnostic court qui oriente
/// immédiatement l'utilisateur vers le parcours Send ProColis correspondant.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _questionCount = 3;

  int _currentStep = 0;
  _OnboardingGoal? _goal;
  _OnboardingExperience? _experience;
  _OnboardingPriority? _priority;

  bool get _isResultStep => _currentStep == _questionCount;

  bool get _canContinue {
    return switch (_currentStep) {
      0 => _goal != null,
      1 => _experience != null,
      2 => _priority != null,
      _ => false,
    };
  }

  void _continue() {
    if (!_canContinue) return;
    setState(() => _currentStep += 1);
  }

  void _goBack() {
    if (_currentStep == 0) return;
    setState(() => _currentStep -= 1);
  }

  void _restart() {
    setState(() {
      _currentStep = 0;
      _goal = null;
      _experience = null;
      _priority = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const _OnboardingTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProgressHeader(
                          currentStep: _currentStep,
                          questionCount: _questionCount,
                          isResult: _isResultStep,
                        ),
                        const SizedBox(height: 24),

                        // AnimatedSwitcher conserve un changement d'étape
                        // lisible sans multiplier les animations décoratives.
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final offset = Tween<Offset>(
                              begin: const Offset(0.035, 0),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: offset,
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(_currentStep),
                            child: _buildStep(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _QuestionStep(
          eyebrow: 'Commençons par votre besoin',
          title: 'Que souhaitez-vous faire sur Send ProColis ?',
          description:
              'Choisissez votre objectif principal. Nous vous montrerons uniquement les informations utiles.',
          children: [
            _ResponsiveChoiceGrid(
              children: _OnboardingGoal.values.map((goal) {
                return _ChoiceCard(
                  icon: goal.icon,
                  title: goal.title,
                  description: goal.description,
                  selected: _goal == goal,
                  onTap: () => setState(() => _goal = goal),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _QuestionActions(
              canContinue: _canContinue,
              onContinue: _continue,
            ),
          ],
        );
      case 1:
        return _QuestionStep(
          eyebrow: 'Votre expérience',
          title: 'Connaissez-vous déjà Send ProColis ?',
          description:
              'Votre réponse nous permet d’adapter le niveau de détail du guide.',
          children: [
            _ChoiceCard(
              icon: Icons.explore_rounded,
              title: 'C’est ma première fois',
              description: 'Je souhaite être accompagné à chaque étape.',
              selected: _experience == _OnboardingExperience.firstTime,
              onTap: () => setState(
                () => _experience = _OnboardingExperience.firstTime,
              ),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              icon: Icons.bolt_rounded,
              title: 'Je connais déjà',
              description: 'Je veux accéder rapidement aux actions utiles.',
              selected: _experience == _OnboardingExperience.returning,
              onTap: () => setState(
                () => _experience = _OnboardingExperience.returning,
              ),
            ),
            const SizedBox(height: 24),
            _QuestionActions(
              canContinue: _canContinue,
              onBack: _goBack,
              onContinue: _continue,
            ),
          ],
        );
      case 2:
        return _QuestionStep(
          eyebrow: 'Votre priorité',
          title: 'Qu’est-ce qui compte le plus pour vous ?',
          description:
              'Nous mettrons cette priorité en avant dans votre parcours conseillé.',
          children: [
            _ChoiceCard(
              icon: Icons.assistant_direction_rounded,
              title: 'Être guidé pas à pas',
              description:
                  'Comprendre les actions et savoir quoi faire ensuite.',
              selected: _priority == _OnboardingPriority.guidance,
              onTap: () => setState(
                () => _priority = _OnboardingPriority.guidance,
              ),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              icon: Icons.speed_rounded,
              title: 'Aller à l’essentiel',
              description:
                  'Réaliser mon opération le plus rapidement possible.',
              selected: _priority == _OnboardingPriority.speed,
              onTap: () => setState(
                () => _priority = _OnboardingPriority.speed,
              ),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              icon: Icons.verified_user_rounded,
              title: 'Garder le contrôle',
              description:
                  'Comparer, vérifier et suivre chaque étape avec confiance.',
              selected: _priority == _OnboardingPriority.control,
              onTap: () => setState(
                () => _priority = _OnboardingPriority.control,
              ),
            ),
            const SizedBox(height: 24),
            _QuestionActions(
              canContinue: _canContinue,
              onBack: _goBack,
              onContinue: _continue,
              continueLabel: 'Afficher mon guide',
              continueIcon: Icons.auto_awesome_rounded,
            ),
          ],
        );
      default:
        final recommendation = _buildRecommendation(
          goal: _goal!,
          experience: _experience!,
          priority: _priority!,
        );
        return _RecommendationView(
          recommendation: recommendation,
          onBack: _goBack,
          onRestart: _restart,
        );
    }
  }
}

enum _OnboardingGoal {
  send(
    title: 'Envoyer un colis',
    description: 'Créer un envoi, recevoir des offres et suivre la livraison.',
    icon: Icons.inventory_2_rounded,
  ),
  drive(
    title: 'Livrer des colis',
    description:
        'Trouver des missions, proposer un prix et gérer mes livraisons.',
    icon: Icons.local_shipping_rounded,
  );

  final String title;
  final String description;
  final IconData icon;

  const _OnboardingGoal({
    required this.title,
    required this.description,
    required this.icon,
  });
}

enum _OnboardingExperience { firstTime, returning }

enum _OnboardingPriority { guidance, speed, control }

class _GuidanceStep {
  final IconData icon;
  final String title;
  final String description;

  const _GuidanceStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _Recommendation {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final String tip;
  final String primaryLabel;
  final String primaryRoute;
  final List<_GuidanceStep> steps;

  const _Recommendation({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.tip,
    required this.primaryLabel,
    required this.primaryRoute,
    required this.steps,
  });
}

/// Matrice de recommandation centralisée : les textes communs restent liés au
/// métier choisi, puis le titre et le conseil final sont adaptés à la priorité.
/// Cette séparation évite de disperser la logique de personnalisation dans l'UI.
_Recommendation _buildRecommendation({
  required _OnboardingGoal goal,
  required _OnboardingExperience experience,
  required _OnboardingPriority priority,
}) {
  final isFirstTime = experience == _OnboardingExperience.firstTime;

  switch (goal) {
    case _OnboardingGoal.send:
      return _Recommendation(
        icon: Icons.inventory_2_rounded,
        eyebrow: 'Parcours expéditeur',
        title: switch (priority) {
          _OnboardingPriority.guidance =>
            'Envoyez votre premier colis, pas à pas',
          _OnboardingPriority.speed => 'Publiez votre colis rapidement',
          _OnboardingPriority.control =>
            'Comparez les offres et gardez le contrôle',
        },
        description: isFirstTime
            ? 'Send ProColis vous accompagne de la déclaration du colis jusqu’à sa remise au destinataire.'
            : 'Accédez directement à la création du colis et publiez-le en libre service.',
        tip: switch (priority) {
          _OnboardingPriority.guidance =>
            'Préparez les coordonnées du destinataire, le poids et une photo du colis.',
          _OnboardingPriority.speed =>
            'Ajoutez un trajet et un prix clair pour recevoir des offres pertinentes plus vite.',
          _OnboardingPriority.control =>
            'Vérifiez le profil, le score et le prix du chauffeur avant d’accepter une offre.',
        },
        primaryLabel: 'Créer un compte expéditeur',
        primaryRoute: '/register?role=client',
        steps: const [
          _GuidanceStep(
            icon: Icons.edit_note_rounded,
            title: 'Déclarez votre colis',
            description:
                'Indiquez le trajet, le contenu, le poids et votre prix.',
          ),
          _GuidanceStep(
            icon: Icons.sell_rounded,
            title: 'Comparez les offres',
            description:
                'Des chauffeurs vérifiés proposent leur prix et leur trajet.',
          ),
          _GuidanceStep(
            icon: Icons.location_searching_rounded,
            title: 'Suivez la livraison',
            description:
                'Consultez le statut jusqu’à la confirmation par code PIN.',
          ),
        ],
      );
    case _OnboardingGoal.drive:
      return _Recommendation(
        icon: Icons.local_shipping_rounded,
        eyebrow: 'Parcours chauffeur',
        title: switch (priority) {
          _OnboardingPriority.guidance =>
            'Démarrez votre activité avec un parcours clair',
          _OnboardingPriority.speed =>
            'Trouvez rapidement des colis sur votre trajet',
          _OnboardingPriority.control =>
            'Choisissez vos missions en toute confiance',
        },
        description: isFirstTime
            ? 'Créez votre profil chauffeur, complétez vos justificatifs puis accédez aux colis disponibles.'
            : 'Retrouvez le libre service, proposez une offre et suivez vos missions actives.',
        tip: switch (priority) {
          _OnboardingPriority.guidance =>
            'Un profil complet et des documents lisibles facilitent la validation de votre compte.',
          _OnboardingPriority.speed =>
            'Renseignez vos trajets habituels pour repérer rapidement les colis compatibles.',
          _OnboardingPriority.control =>
            'Vérifiez le colis, le trajet et la rémunération avant de faire une offre.',
        },
        primaryLabel: 'Créer un compte chauffeur',
        primaryRoute: '/register?role=driver',
        steps: const [
          _GuidanceStep(
            icon: Icons.badge_rounded,
            title: 'Complétez votre profil',
            description:
                'Ajoutez vos informations, votre véhicule et vos documents.',
          ),
          _GuidanceStep(
            icon: Icons.travel_explore_rounded,
            title: 'Consultez le libre service',
            description:
                'Repérez les colis compatibles avec vos prochains trajets.',
          ),
          _GuidanceStep(
            icon: Icons.handshake_rounded,
            title: 'Gérez vos missions',
            description:
                'Faites une offre puis mettez à jour chaque statut de livraison.',
          ),
        ],
      );
  }
}

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const AppLogo(size: 38),
                const SizedBox(width: 10),
                RichText(
                  text: TextSpan(
                    style: AppFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: AppTheme.slate900,
                    ),
                    children: [
                      TextSpan(text: 'Send '),
                      TextSpan(
                        text: 'ProColis',
                        style: TextStyle(color: AppTheme.amber500),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Se connecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int currentStep;
  final int questionCount;
  final bool isResult;

  const _ProgressHeader({
    required this.currentStep,
    required this.questionCount,
    required this.isResult,
  });

  @override
  Widget build(BuildContext context) {
    final completedSteps = isResult ? questionCount : currentStep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                boxShadow: AppTheme.brandShadow(),
              ),
              child: Icon(
                isResult ? Icons.check_rounded : Icons.assistant_navigation,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isResult
                        ? 'Votre guide est prêt'
                        : 'Votre guide personnalisé',
                    style: AppFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isResult
                        ? 'Un parcours adapté à vos réponses'
                        : '3 réponses, moins d’une minute',
                    style: AppFonts.manrope(
                      color: AppTheme.slate500,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$completedSteps/$questionCount',
              style: AppFonts.jetBrainsMono(
                color: AppTheme.slate600,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(questionCount, (index) {
            final active =
                index < completedSteps || (!isResult && index == currentStep);
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 5,
                margin: EdgeInsets.only(
                  right: index == questionCount - 1 ? 0 : 7,
                ),
                decoration: BoxDecoration(
                  color: active ? AppTheme.primary : AppTheme.slate200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _QuestionStep extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final List<Widget> children;

  const _QuestionStep({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: AppFonts.plusJakartaSans(
            color: AppTheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: AppFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 28,
            height: 1.18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: AppFonts.manrope(
            color: AppTheme.slate600,
            fontSize: 15,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}

class _ResponsiveChoiceGrid extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveChoiceGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Le questionnaire reste en colonne sur téléphone et passe en grille
        // uniquement lorsque deux cartes gardent une largeur confortable.
        if (constraints.maxWidth < 580) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map(
                (child) => SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $description',
      child: Material(
        color: selected ? AppTheme.teal50 : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.slate200,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected ? AppTheme.softShadow(alpha: 0.07) : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : AppTheme.slate100,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : AppTheme.slate500,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppFonts.plusJakartaSans(
                                color: selected
                                    ? AppTheme.teal700
                                    : AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: selected ? 1 : 0,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primary,
                              size: 21,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: AppFonts.manrope(
                          color: AppTheme.slate600,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionActions extends StatelessWidget {
  final bool canContinue;
  final VoidCallback? onBack;
  final VoidCallback onContinue;
  final String continueLabel;
  final IconData continueIcon;

  const _QuestionActions({
    required this.canContinue,
    required this.onContinue,
    this.onBack,
    this.continueLabel = 'Continuer',
    this.continueIcon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          PcButton(
            'Retour',
            icon: Icons.arrow_back_rounded,
            variant: PcButtonVariant.secondary,
            size: PcButtonSize.lg,
            onPressed: onBack,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: PcButton(
            continueLabel,
            iconTrailing: continueIcon,
            block: true,
            size: PcButtonSize.lg,
            onPressed: canContinue ? onContinue : null,
          ),
        ),
      ],
    );
  }
}

class _RecommendationView extends StatelessWidget {
  final _Recommendation recommendation;
  final VoidCallback onBack;
  final VoidCallback onRestart;

  const _RecommendationView({
    required this.recommendation,
    required this.onBack,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: AppTheme.brandShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  recommendation.icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                recommendation.eyebrow.toUpperCase(),
                style: AppFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                recommendation.title,
                style: AppFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.55,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                recommendation.description,
                style: AppFonts.manrope(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14.5,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Votre parcours conseillé',
          style: AppFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        PcCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              for (var index = 0;
                  index < recommendation.steps.length;
                  index++) ...[
                _GuidanceStepRow(
                  number: index + 1,
                  step: recommendation.steps[index],
                  isLast: index == recommendation.steps.length - 1,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.amber50,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.amber100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_rounded,
                color: AppTheme.amber600,
                size: 22,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bon à savoir',
                      style: AppFonts.plusJakartaSans(
                        color: AppTheme.amber700,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      recommendation.tip,
                      style: AppFonts.manrope(
                        color: AppTheme.slate700,
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PcButton(
          recommendation.primaryLabel,
          iconTrailing: Icons.arrow_forward_rounded,
          block: true,
          size: PcButtonSize.lg,
          onPressed: () => context.go(recommendation.primaryRoute),
        ),
        const SizedBox(height: 10),
        PcButton(
          'Consulter le centre d’aide',
          icon: Icons.help_outline_rounded,
          block: true,
          variant: PcButtonVariant.secondary,
          onPressed: () => context.go('/help'),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: onBack,
              child: const Text('Modifier ma réponse'),
            ),
            const SizedBox(width: 4),
            Text(
              '•',
              style: AppFonts.manrope(color: AppTheme.slate300),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: onRestart,
              child: const Text('Recommencer'),
            ),
          ],
        ),
      ],
    );
  }
}

class _GuidanceStepRow extends StatelessWidget {
  final int number;
  final _GuidanceStep step;
  final bool isLast;

  const _GuidanceStepRow({
    required this.number,
    required this.step,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.teal50,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$number',
                    style: AppFonts.jetBrainsMono(
                      color: AppTheme.teal700,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: AppTheme.teal100,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.slate100,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      step.icon,
                      color: AppTheme.slate600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: AppFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          step.description,
                          style: AppFonts.manrope(
                            color: AppTheme.slate600,
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
