import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(24.0),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAF7).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: const Color(0xFFEDD8F0).withValues(alpha: 0.6),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB89FD8).withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }
    return cardContent;
  }
}
