// lib/widgets/format_chip.dart

import 'package:flutter/material.dart';
import '../theme.dart';

class FormatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const FormatChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSel  = kAccent.withOpacity(0.15);
    final bgDef  = isDark ? kDarkHover : kLightBgSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? bgSel : bgDef,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kAccent : (isDark ? kDarkBorder : kLightBorder),
            width: selected ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? kAccent
                                : (isDark ? kDarkTextSec : kLightTextSec)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: selected ? kAccent
                                    : (isDark ? kDarkText : kLightText))),
          ],
        ),
      ),
    );
  }
}
