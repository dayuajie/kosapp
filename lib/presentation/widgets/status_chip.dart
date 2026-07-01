import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final bool isPositive;

  const StatusChip({super.key, required this.label, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? const Color(0xFF16A34A) : const Color(0xFFEF4444);
    final bg = isPositive ? const Color(0xFF16A34A).withOpacity(0.14) : const Color(0xFFEF4444).withOpacity(0.14);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
      ),
    );
  }
}

