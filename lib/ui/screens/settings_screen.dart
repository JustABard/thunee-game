import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../state/providers/config_provider.dart';

/// Settings screen for configuring house rules
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final configNotifier = ref.read(configProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          // Reset to defaults button
          TextButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Settings?'),
                  content: const Text('This will restore all settings to their default values.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await configNotifier.resetToDefaults();
              }
            },
            icon: const Icon(Icons.restore),
            label: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Special Game Modes Section
          _SectionHeader(title: 'Special Game Modes'),
          _ToggleTile(
            title: 'Royals',
            subtitle: 'Reversed ranking: Q > K > 10 > A > 9 > J',
            value: config.enableRoyals,
            onChanged: (value) => configNotifier.updateSetting(enableRoyals: value),
          ),
          _ToggleTile(
            title: 'Blind Thunee',
            subtitle: 'Call Thunee after 4 cards dealt, reveal after 4 tricks won',
            value: config.enableBlindThunee,
            onChanged: (value) => configNotifier.updateSetting(enableBlindThunee: value),
          ),
          _ToggleTile(
            title: 'Blind Royals',
            subtitle: 'Call Royals after 4 cards dealt, reveal after 4 tricks won',
            value: config.enableBlindRoyals,
            onChanged: (value) => configNotifier.updateSetting(enableBlindRoyals: value),
          ),
          _ToggleTile(
            title: 'Kunuck',
            subtitle: 'Last trick call that extends match to 13 balls',
            value: config.enableKunuck,
            onChanged: (value) => configNotifier.updateSetting(enableKunuck: value),
          ),

          const SizedBox(height: 24),

          // Bidding Rules Section
          _SectionHeader(title: 'Bidding Rules'),
          _ToggleTile(
            title: 'Call Over Teammates',
            subtitle: 'Allow players to outbid their own partners',
            value: config.enableCallOverTeammates,
            onChanged: (value) => configNotifier.updateSetting(enableCallOverTeammates: value),
          ),
          _ToggleTile(
            title: 'Call & Loss Rule',
            subtitle: 'Losing trump team gives +2 balls instead of normal scoring',
            value: config.enableCallAndLoss,
            onChanged: (value) => configNotifier.updateSetting(enableCallAndLoss: value),
          ),

          const SizedBox(height: 24),

          // Jodi Rules Section
          _SectionHeader(title: 'Jodi Rules'),
          _ToggleTile(
            title: 'First & Third Trick Only',
            subtitle: 'Restrict Jodi calls to tricks 1 and 3 only',
            value: config.enableFirstThirdOnlyJodiCalls,
            onChanged: (value) => configNotifier.updateSetting(enableFirstThirdOnlyJodiCalls: value),
          ),

          const SizedBox(height: 24),

          // Scoring Configuration Section
          _SectionHeader(title: 'Scoring Configuration'),
          _SliderTile(
            title: 'Blind Thunee Success Balls',
            value: config.blindThuneeSuccessBalls.toDouble(),
            min: 4,
            max: 10,
            divisions: 6,
            onChanged: (value) => configNotifier.updateSetting(blindThuneeSuccessBalls: value.toInt()),
          ),
          _SliderTile(
            title: 'Blind Royals Success Balls',
            value: config.blindRoyalsSuccessBalls.toDouble(),
            min: 4,
            max: 10,
            divisions: 6,
            onChanged: (value) => configNotifier.updateSetting(blindRoyalsSuccessBalls: value.toInt()),
          ),
          _SliderTile(
            title: 'Match Target (Balls to Win)',
            value: config.matchTarget.toDouble(),
            min: 10,
            max: 15,
            divisions: 5,
            onChanged: (value) => configNotifier.updateSetting(matchTarget: value.toInt()),
          ),

          const SizedBox(height: 24),

          // Info card
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'About Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'These settings only affect new matches. Ongoing matches will continue with their original settings.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
