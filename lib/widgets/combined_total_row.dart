import 'package:flutter/material.dart';
import '../services/bill_processor.dart';

class CombinedTotalRow extends StatelessWidget {
  final double amount;
  final String currency;
  final int selectedCount;
  final int totalCount;
  final VoidCallback? onTap;
  final bool isEnabled;

  const CombinedTotalRow({
    super.key,
    required this.amount,
    required this.currency,
    required this.selectedCount,
    required this.totalCount,
    this.onTap,
    this.isEnabled = true,
  });


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Mobile-optimized layout
    const isCompactMode = true;
    const isVeryCompactMode = false;

    return Semantics(
      label: 'Combined total',
      value: '${BillProcessor.formatCurrency(amount, currency)}, $selectedCount of $totalCount people selected',
      button: true,
      enabled: isEnabled,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          splashColor: colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Calculator icon - fixed size, matching theme
                Icon(
                  Icons.calculate_outlined,
                  size: 24,
                  color: isEnabled 
                    ? colorScheme.primary 
                    : colorScheme.onSurface.withValues(alpha: 0.38),
                ),
                const SizedBox(width: 12),
                
                // People count with icon - right-aligned with padding
                _buildPeopleCount(context, isCompactMode, isVeryCompactMode),
                
                // Flexible spacer
                const Expanded(child: SizedBox()),
                
                // Amount - right-aligned, monospaced
                _buildAmount(context, isEnabled),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeopleCount(BuildContext context, bool isCompactMode, bool isVeryCompactMode) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "X of Y" text
          Text(
            '$selectedCount of $totalCount',
            style: TextStyle(
              color: isEnabled 
                ? colorScheme.onSurface 
                : colorScheme.onSurface.withValues(alpha: 0.38),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFeatures: const [
                FontFeature.tabularFigures(), // Monospaced numbers for alignment
              ],
            ),
          ),
          const SizedBox(width: 8),
          // People icon
          Icon(
            Icons.people_outline,
            size: 20,
            color: isEnabled 
              ? colorScheme.primary 
              : colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ],
      ),
    );
  }

  Widget _buildAmount(BuildContext context, bool isEnabled) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return Text(
      BillProcessor.formatCurrency(amount, currency),
      style: textTheme.titleLarge?.copyWith(
        color: isEnabled 
          ? colorScheme.primary 
          : colorScheme.onSurface.withValues(alpha: 0.38),
        fontWeight: FontWeight.bold,
        fontFeatures: const [
          FontFeature.tabularFigures(), // Monospaced/tabular lining numerals
        ],
      ),
      textAlign: TextAlign.end,
      overflow: TextOverflow.visible, // Never truncate the amount
      maxLines: 1,
    );
  }
}
