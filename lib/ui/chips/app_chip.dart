import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppChipVariant { filled, tonal, outlined, utility }

// Helper function to create a darker, more saturated version of a color
Color _darkenAndSaturate(Color color, {double darkenFactor = 0.2, double saturateFactor = 0.1}) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness - darkenFactor).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation + saturateFactor).clamp(0.0, 1.0))
      .toColor();
}

// Helper function to darken a color by a percentage
Color _darkenColor(Color color, double factor) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - factor).clamp(0.0, 1.0)).toColor();
}

class AppChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? selectedBackgroundColor;
  final Color? ringColor;
  final String? semanticsLabel;
  final double? maxLabelWidth; // NEW: optional hard cap
  final bool isDisabled;
  final AppChipVariant variant;
  final Widget? leading;
  final bool enhancedSelection; // For person chips with enhanced styling
  final bool responsive; // NEW: enable smart fit
  final VoidCallback? onSelectionChanged; // NEW: callback for selection changes

  const AppChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.backgroundColor,
    this.selectedBackgroundColor,
    this.ringColor,
    this.semanticsLabel,
    this.maxLabelWidth, // Remove default value
    this.isDisabled = false,
    this.variant = AppChipVariant.tonal,
    this.leading,
    this.enhancedSelection = false,
    this.responsive = false, // NEW
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    // Determine colors based on variant
    Color bgColor;
    Color textColor;
    Color borderColor;
    List<BoxShadow>? boxShadows;
    
    if (enhancedSelection && variant == AppChipVariant.tonal) {
      // Enhanced styling for person chips
      final baseBgColor = backgroundColor ?? colorScheme.surfaceContainerHighest;
      final baseSelectedBgColor = selectedBackgroundColor ?? colorScheme.primaryContainer;
      
      bgColor = isSelected 
          ? _darkenColor(baseSelectedBgColor, 0.1) // Darken by 10%
          : baseBgColor;
      
      textColor = isDisabled
          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
          : (isSelected 
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant);
      
      borderColor = isSelected 
          ? _darkenAndSaturate(baseSelectedBgColor) // Stronger, saturated version
          : colorScheme.outline;
      
      // Add soft shadow for selected state
      if (isSelected && !isDisabled) {
        boxShadows = [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ];
      }
    } else {
      // Standard styling
      switch (variant) {
        case AppChipVariant.filled:
          bgColor = isSelected 
              ? (selectedBackgroundColor ?? colorScheme.primary)
              : (backgroundColor ?? colorScheme.surfaceContainerHighest);
          textColor = isDisabled
              ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
              : (isSelected 
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant);
          borderColor = isSelected 
              ? Colors.transparent
              : colorScheme.outline;
          break;
        case AppChipVariant.tonal:
          bgColor = isSelected 
              ? (selectedBackgroundColor ?? colorScheme.primaryContainer)
              : (backgroundColor ?? colorScheme.surfaceContainerHighest);
          textColor = isDisabled
              ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
              : (isSelected 
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant);
          borderColor = isSelected 
              ? (ringColor ?? Colors.transparent) // Use ringColor if provided, otherwise transparent
              : colorScheme.outline;
          break;
        case AppChipVariant.outlined:
          bgColor = isSelected 
              ? (selectedBackgroundColor ?? colorScheme.primaryContainer)
              : (backgroundColor ?? Colors.transparent);
          textColor = isDisabled
              ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
              : (isSelected 
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant);
          borderColor = isSelected 
              ? (ringColor ?? colorScheme.primary) // Use ringColor if provided
              : colorScheme.outline;
          break;
        case AppChipVariant.utility:
          bgColor = isSelected 
              ? (selectedBackgroundColor ?? colorScheme.secondary)
              : (backgroundColor ?? colorScheme.surface);
          textColor = isDisabled
              ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
              : (isSelected 
                  ? colorScheme.onSecondary
                  : colorScheme.onSurface);
          borderColor = isSelected 
              ? Colors.transparent
              : colorScheme.outline;
          break;
      }
    }

    // ---- Mobile-optimized sizing ----
    // Fixed width cap for mobile screens
    final double cap = maxLabelWidth ?? 140.0;

    // Base style
    final baseStyle = textTheme.labelLarge!.copyWith(
      color: textColor,
      fontWeight: FontWeight.w700,
    );

    // Smart text fit: try 100%, then 92%, then 85% before ellipsis.
    TextStyle fitStyle = baseStyle;
    if (responsive) {
      fitStyle = _fitStyleToWidth(
        context: context,
        text: label,
        base: baseStyle,
        maxWidth: cap,
        scaleSteps: const [1.0, 0.92, 0.85],
      );
    }

    return Semantics(
      button: true,
      toggled: isSelected,
      label: semanticsLabel ?? label,
      child: AnimatedScale(
        scale: isDisabled ? 1.0 : (isSelected ? 1.02 : 1.0),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 40), // height only; width is intrinsic
          decoration: BoxDecoration(
            color: isDisabled ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) : bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDisabled 
                  ? colorScheme.outline.withValues(alpha: 0.5)
                  : borderColor, 
              width: variant == AppChipVariant.filled && isSelected ? 0 : 1.2
            ),
            boxShadow: boxShadows ?? (isSelected && !isDisabled && variant != AppChipVariant.utility
                ? [
                    BoxShadow(
                      color: (ringColor ?? colorScheme.primary).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              splashColor: textColor.withValues(alpha: 0.1),
              highlightColor: Colors.transparent,
              onTap: isDisabled ? null : () {
                // Trigger haptic feedback if this is a selection change to selected state
                if (onSelectionChanged != null && !isSelected) {
                  HapticFeedback.lightImpact();
                }
                onTap?.call();
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: leading != null && label.isEmpty ? 8 : 14, // Minimal padding for icon-only
                  vertical: 8
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // intrinsic width
                  children: [
                    if (leading != null) ...[
                      if (label.isNotEmpty) // Only add right padding if there's text
                        Padding(
                          padding: const EdgeInsets.only(right: 8), 
                          child: leading!
                        )
                      else
                        leading!, // No padding for icon-only chips
                    ],
                    if (label.isNotEmpty) // Only show text if not empty
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cap),
                        child: Text(
                          label,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          textDirection: Directionality.of(context), // RTL-friendly
                          textHeightBehavior: const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                          style: fitStyle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Measures text and picks the first style that fits maxWidth.
  static TextStyle _fitStyleToWidth({
    required BuildContext context,
    required String text,
    required TextStyle base,
    required double maxWidth,
    required List<double> scaleSteps,
  }) {
    final textDirection = Directionality.of(context);
    for (final scale in scaleSteps) {
      final style = base.copyWith(fontSize: (base.fontSize ?? 14) * scale);
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: textDirection,
      )..layout(maxWidth: maxWidth);
      if (!tp.didExceedMaxLines) return style;
    }
    return base; // fallback; ellipsis will handle overflow
  }
}