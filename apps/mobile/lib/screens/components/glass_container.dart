import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glassTheme = Theme.of(context).extension<GlassThemeExtension>();
    final baseColor = glassTheme?.baseColor ?? Colors.white.withOpacity(0.6);
    final blurSigma = glassTheme?.blurSigma ?? 12.0;
    final borderColor = glassTheme?.borderColor ?? Colors.white.withOpacity(0.2);

    Widget container = Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      container = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: container,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: container,
      ),
    );
  }
}
