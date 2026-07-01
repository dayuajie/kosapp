import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String rightText;
  final VoidCallback? onRightTap;

  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.rightText,
    this.onRightTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black.withOpacity(0.58),
                    ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onRightTap,
          child: Text(
            rightText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6D5EF6),
                ),
          ),
        ),
      ],
    );
  }
}

