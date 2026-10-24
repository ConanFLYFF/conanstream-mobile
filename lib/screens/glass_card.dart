import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color borderColor;
  final double borderRadius;
  final double opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor = const Color(0xFF00E5FF),
    this.borderRadius = 20.0,
    this.opacity = 0.08,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool isHovered = false;
  bool isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bool isActive = isHovered || isFocused;

    return RepaintBoundary(
      child: Focus(
        onFocusChange: (hasFocus) {
          setState(() {
            isFocused = hasFocus;
          });
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
               event.logicalKey == LogicalKeyboardKey.space)) {
            if (widget.onTap != null) {
              widget.onTap!();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedScale(
            scale: isActive ? 1.02 : 1.0, // Échelle légèrement adoucie pour plus de fluidité
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: widget.borderColor.withOpacity(isActive ? 0.4 : 0.15),
                    blurRadius: isActive ? 15 : 8,
                    spreadRadius: isActive ? 1 : 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // Réduction du flou pour un gain énorme en performance mobile
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap,
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(isActive ? widget.opacity + 0.05 : widget.opacity),
                          borderRadius: BorderRadius.circular(widget.borderRadius),
                          border: Border.all(
                            color: isActive ? widget.borderColor : widget.borderColor.withOpacity(0.5),
                            width: isActive ? 1.8 : 1.0,
                          ),
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}