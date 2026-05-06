import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trgou/app_settings/app_settings_provider.dart';
import 'package:trgou/game/ai/ai_config.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/providers/game_controller_provider.dart';
import 'package:trgou/screens/game_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _pushGameAndRefreshContinue(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    ).then((_) {
      if (context.mounted) {
        ref.invalidate(hasRestorableGameProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final AsyncValue<bool> canContinue = ref.watch(hasRestorableGameProvider);
    final bool hasSavedMatch = canContinue.maybeWhen(
      data: (value) => value,
      orElse: () => false,
    );

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (settings.debugEnabled)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Chip(
                avatar: Icon(Icons.bug_report_outlined, size: 18),
                label: Text('Debug layer enabled'),
              ),
            ),
          _HomeCard(
            icon: Icons.smart_toy,
            title: 'Against AI',
            subtitle: 'Pick a default, adaptive, or style-tuned opponent.',
            onTap: () async {
              final _AiOpponentChoice? choice =
                  await _showAiOpponentPickerDialog(context);
              if (!context.mounted || choice == null) {
                return;
              }
              switch (choice) {
                case _AiOpponentChoice.defaultAi:
                  debugPrint('[HomeScreen] Starting AI match (default).');
                  ref.read(gameStateProvider.notifier).startAiMatch(
                        seed: settings.configuredSeed,
                      );
                case _AiOpponentChoice.bayesian:
                  debugPrint('[HomeScreen] Starting AI match (bayesian).');
                  ref.read(gameStateProvider.notifier).startAiMatch(
                        aiStyleOverride: AIStyleOverride.bayesian,
                        seed: settings.configuredSeed,
                      );
                case _AiOpponentChoice.aggressive:
                  debugPrint('[HomeScreen] Starting AI match (aggressive).');
                  ref.read(gameStateProvider.notifier).startAiMatch(
                        aiStyleOverride: AIStyleOverride.aggressive,
                        seed: settings.configuredSeed,
                      );
                case _AiOpponentChoice.defensive:
                  debugPrint('[HomeScreen] Starting AI match (defensive).');
                  ref.read(gameStateProvider.notifier).startAiMatch(
                        aiStyleOverride: AIStyleOverride.defensive,
                        seed: settings.configuredSeed,
                      );
                case _AiOpponentChoice.progressive:
                  debugPrint('[HomeScreen] Starting AI match (progressive).');
                  ref.read(gameStateProvider.notifier).startAiMatch(
                        aiStyleOverride: AIStyleOverride.progressive,
                        seed: settings.configuredSeed,
                      );
              }
              _pushGameAndRefreshContinue(context, ref);
            },
          ),
          const SizedBox(height: 5),
          _HomeCard(
            icon: Icons.play_arrow,
            title: 'Hotseat',
            subtitle: 'Play against another player on the same device.',
            onTap: () {
              debugPrint('[HomeScreen] Starting Hotseat match.');
              ref
                  .read(gameStateProvider.notifier)
                  .reset(mode: GameMode.hotseat, seed: settings.configuredSeed);
              _pushGameAndRefreshContinue(context, ref);
            },
          ),
          const SizedBox(height: 5),
          _HomeCard(
            icon: Icons.replay_sharp,
            title: 'Continue Match',
            subtitle: hasSavedMatch
                ? 'Resume your previous match.'
                : 'No saved match yet.',
            onTap: hasSavedMatch
                ? () async {
                    debugPrint('[HomeScreen] Continuing existing match.');
                    final bool restored = await ref
                        .read(gameStateProvider.notifier)
                        .loadPersistedState();
                    if (!context.mounted) {
                      return;
                    }
                    if (!restored) {
                      ref.invalidate(hasRestorableGameProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No saved match found yet.'),
                        ),
                      );
                      return;
                    }
                    _pushGameAndRefreshContinue(context, ref);
                  }
                : null,
          ),
          const SizedBox(height: 5),
          _HomeCard(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: _settingsSubtitle(settings),
            onTap: () async {
              final _SettingsResult? result = await _showSettingsDialog(
                context,
                initialSeed: settings.configuredSeed,
                initialDebugEnabled: settings.debugEnabled,
              );
              if (!context.mounted) {
                return;
              }
              if (result == null) {
                return;
              }

              ref.read(appSettingsProvider.notifier).updateSeed(result.seed);
              ref
                  .read(appSettingsProvider.notifier)
                  .setDebugEnabled(result.debugEnabled);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _settingsSavedMessage(
                      seed: result.seed,
                      debugEnabled: result.debugEnabled,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _settingsSubtitle(AppSettingsState settings) {
    final String seedText = settings.configuredSeed == null
        ? 'Seed: auto'
        : 'Seed: ${settings.configuredSeed}';
    final String debugText = settings.debugEnabled ? 'Debug: on' : 'Debug: off';
    return '$seedText, $debugText';
  }

  String _settingsSavedMessage({
    required int? seed,
    required bool debugEnabled,
  }) {
    final String seedMessage = seed == null
        ? 'Seed set to auto-generated'
        : 'Seed set to $seed';
    final String debugMessage = debugEnabled ? 'debug on' : 'debug off';
    return '$seedMessage, $debugMessage.';
  }

  Future<_AiOpponentChoice?> _showAiOpponentPickerDialog(
    BuildContext context,
  ) {
    return showDialog<_AiOpponentChoice>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Choose AI opponent'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: const Text('Default'),
                  subtitle: const Text('Standard balanced AI.'),
                  onTap: () => Navigator.pop(
                    dialogContext,
                    _AiOpponentChoice.defaultAi,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('Bayesian'),
                  subtitle: const Text(
                    'Adaptive AI that learns from move outcomes.',
                  ),
                  onTap: () => Navigator.pop(
                    dialogContext,
                    _AiOpponentChoice.bayesian,
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.flash_on_outlined),
                  title: const Text('Aggressive'),
                  subtitle: const Text('Prioritises pressure and captures.'),
                  onTap: () => Navigator.pop(
                    dialogContext,
                    _AiOpponentChoice.aggressive,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Defensive'),
                  subtitle: const Text('Prioritises safety and blocking.'),
                  onTap: () => Navigator.pop(
                    dialogContext,
                    _AiOpponentChoice.defensive,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.trending_up),
                  title: const Text('Progressive'),
                  subtitle: const Text('Prioritises advancing towards the goal.'),
                  onTap: () => Navigator.pop(
                    dialogContext,
                    _AiOpponentChoice.progressive,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<_SettingsResult?> _showSettingsDialog(
    BuildContext context, {
    required int? initialSeed,
    required bool initialDebugEnabled,
  }) async {
    final TextEditingController seedController = TextEditingController();
    if (initialSeed != null) {
      seedController.text = initialSeed.toString();
    }
    bool debugEnabled = initialDebugEnabled;

    return showDialog<_SettingsResult?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: seedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Seed',
                      hintText: 'Leave blank to use auto-generated seed',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Debug Layer'),
                    subtitle: const Text(
                      'Shows diagnostics across game UI and AI details.',
                    ),
                    value: debugEnabled,
                    onChanged: (bool value) {
                      setDialogState(() {
                        debugEnabled = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final String rawValue = seedController.text.trim();
                    int? parsedSeed;
                    if (rawValue.isNotEmpty) {
                      parsedSeed = int.tryParse(rawValue);
                      if (parsedSeed == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Seed must be a valid integer.'),
                          ),
                        );
                        return;
                      }
                    }
                    Navigator.of(dialogContext).pop(
                      _SettingsResult(
                        seed: parsedSeed,
                        debugEnabled: debugEnabled,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

enum _AiOpponentChoice {
  defaultAi,
  bayesian,
  aggressive,
  defensive,
  progressive,
}

class _SettingsResult {
  final int? seed;
  final bool debugEnabled;

  const _SettingsResult({
    required this.seed,
    required this.debugEnabled,
  });
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final double screenWidth = screenSize.width;
    final bool enabled = onTap != null;
    final Color? iconColor = enabled
        ? null
        : Theme.of(context).disabledColor;
    final TextStyle? titleStyle = enabled
        ? null
        : Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).disabledColor,
            );
    final TextStyle? subtitleStyle = enabled
        ? null
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).disabledColor,
            );

    return Center(
      child: Card(
        clipBehavior: Clip.hardEdge,
        color: enabled ? null : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: screenWidth - 20,
            height: 100,
            child: Center(
              child: ListTile(
                leading: Icon(icon, size: 40, color: iconColor),
                title: Text(title, style: titleStyle),
                subtitle: Text(subtitle, style: subtitleStyle),
                trailing: Icon(
                  Icons.chevron_right,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
