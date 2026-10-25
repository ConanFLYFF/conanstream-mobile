import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color borderColor;
  final double borderRadius;
  final double blur;
  final double opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor = const Color(0xFF00E5FF),
    this.borderRadius = 16.0,
    this.blur = 10.0,
    this.opacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.25),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: borderColor.withOpacity(0.8),
                    width: 1.5,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}