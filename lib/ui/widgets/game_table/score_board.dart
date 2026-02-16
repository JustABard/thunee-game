import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/models/match_state.dart';

/// Displays current match score (balls)
class ScoreBoard extends StatelessWidget {
  final MatchState matchState;

  const ScoreBoard({super.key, required this.matchState});

  @override
  Widget build(BuildContext context) {
    final team0 = matchState.teams[0];
    final team1 = matchState.teams[1];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ScoreChip(
          label: 'T1',
          score: team0.balls,
          color: Colors.blue,
        ),
        const SizedBox(width: 8),
        Text(
          'vs',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(width: 8),
        _ScoreChip(
          label: 'T2',
          score: team1.balls,
          color: Colors.red,
        ),
      ],
    );
  }
}

class _ScoreChip extends StatefulWidget {
  final String label;
  final int score;
  final Color color;

  const _ScoreChip({
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  State<_ScoreChip> createState() => _ScoreChipState();
}

class _ScoreChipState extends State<_ScoreChip> {
  int? _previousScore;
  bool _shouldAnimate = false;

  @override
  void didUpdateWidget(_ScoreChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      setState(() {
        _previousScore = oldWidget.score;
        _shouldAnimate = true;
      });
      // Reset animation flag after animation completes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _shouldAnimate = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _shouldAnimate
            ? [
                BoxShadow(
                  color: widget.color.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Text(
        '${widget.label}: ${widget.score}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (!_shouldAnimate) return chip;

    return chip
        .animate()
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.3, 1.3),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        )
        .then()
        .scale(
          begin: const Offset(1.3, 1.3),
          end: const Offset(1.0, 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
        );
  }
}
