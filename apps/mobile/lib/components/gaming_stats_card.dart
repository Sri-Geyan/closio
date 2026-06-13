import 'package:flutter/material.dart';
import '../theme.dart';

class GamingStatsCard extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final String? presence;

  const GamingStatsCard({super.key, this.stats, this.presence});

  @override
  Widget build(BuildContext context) {
    if (presence == null && (stats == null || stats!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ClosioTheme.primaryColor.withOpacity(0.1), ClosioTheme.primaryColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClosioTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videogame_asset, color: ClosioTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('Gaming Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          if (presence != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: presence!.contains('Online') || presence!.contains('Playing') ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      presence!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (stats != null && stats!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildStatChips(),
            ),
          ]
        ],
      ),
    );
  }

  List<Widget> _buildStatChips() {
    List<Widget> chips = [];
    if (stats!.containsKey('steam')) {
      chips.add(_StatChip(icon: Icons.computer, label: '${stats!['steam']['hoursPlayed']} hrs'));
    }
    if (stats!.containsKey('psn')) {
      final t = stats!['psn']['trophies'];
      chips.add(_StatChip(icon: Icons.emoji_events, label: '${t['platinum']} Plat • ${t['gold']} Gold'));
    }
    if (stats!.containsKey('xbox')) {
      chips.add(_StatChip(icon: Icons.gamepad, label: '${stats!['xbox']['gamerscore']} GS'));
    }
    if (stats!.containsKey('riot')) {
      chips.add(_StatChip(icon: Icons.sports_esports, label: stats!['riot']['valorantRank']));
    }
    return chips;
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ClosioTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
