import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/persistence/game_state_persistence.dart';
import 'package:trgou/game/providers/game_controller_provider.dart';
import 'package:trgou/screens/game_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final savedGameAsync = ref.watch(savedGameStateProvider);
    final hasSavedGame = savedGameAsync.valueOrNull != null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerLow,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 48),
                Text(
                  'Royal Game of Ur',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Spacer(),
                _HomeCard(
                  title: 'Play vs Bot',
                  subtitle: 'Challenge the computer',
                  icon: Icons.smart_toy_rounded,
                  onTap: () => _navigateToNewGame(context, ref, GameMode.bot),
                ),
                const SizedBox(height: 16),
                _HomeCard(
                  title: 'Hotseat',
                  subtitle: 'Two players, one device',
                  icon: Icons.people_rounded,
                  onTap: () => _navigateToNewGame(context, ref, GameMode.hotseat),
                ),
                const SizedBox(height: 16),
                _HomeCard(
                  title: 'Continue',
                  subtitle: 'Resume your last game',
                  icon: Icons.play_arrow_rounded,
                  enabled: hasSavedGame,
                  onTap: () => _navigateToContinue(context, ref),
                ),
                const SizedBox(height: 16),
                _HomeCard(
                  title: 'Rules',
                  subtitle: 'How to play',
                  icon: Icons.menu_book_rounded,
                  enabled: false,
                  onTap: () {},
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToNewGame(BuildContext context, WidgetRef ref, GameMode mode) {
    ref.read(gameControllerProvider.notifier).resetBoard();
    ref.read(gameControllerProvider.notifier).setGameMode(mode);
    ref.invalidate(savedGameStateProvider);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const GameScreen(),
      ),
    );
  }

  void _navigateToContinue(BuildContext context, WidgetRef ref) async {
    final saved = await loadGameState();
    if (saved != null && context.mounted) {
      ref.read(gameControllerProvider.notifier).loadState(saved);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => const GameScreen(),
        ),
      );
    }
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleColor = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.5);
    final subtitleColor = enabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    final iconColor = enabled
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    final arrowColor = enabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: iconColor,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: arrowColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
