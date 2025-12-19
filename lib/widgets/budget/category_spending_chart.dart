import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/budget_analytics_service.dart';

/// Pie chart widget for category spending breakdown
class CategorySpendingChart extends StatelessWidget {
  final List<CategorySpending> categorySpending;
  final double height;

  const CategorySpendingChart({
    super.key,
    required this.categorySpending,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (categorySpending.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No spending data available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: _buildSections(context),
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              // Optional: Handle tap for details
            },
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return categorySpending.map((category) {
      final color = _parseColor(category.color, colorScheme.primary);
      
      return PieChartSectionData(
        value: category.amount,
        title: '${category.percentage.toStringAsFixed(0)}%',
        color: color,
        radius: 60,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: _getContrastColor(color, context),
        ),
      );
    }).toList();
  }

  Color _parseColor(String colorString, Color fallback) {
    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
      return fallback;
    } catch (e) {
      return fallback;
    }
  }

  Color _getContrastColor(Color color, BuildContext context) {
    // Calculate luminance to determine if text should be black or white
    final luminance = color.computeLuminance();
    final theme = Theme.of(context);
    return luminance > 0.5 ? theme.colorScheme.onSurface : theme.colorScheme.onPrimary;
  }
}

