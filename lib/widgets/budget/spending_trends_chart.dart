import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// Line chart widget for spending trends over time
class SpendingTrendsChart extends StatelessWidget {
  final Map<DateTime, double> trends;
  final double height;

  const SpendingTrendsChart({
    super.key,
    required this.trends,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No spending trends available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    final sortedDates = trends.keys.toList()..sort();
    final maxValue = trends.values.isEmpty ? 100.0 : trends.values.reduce((a, b) => a > b ? a : b);
    final minValue = trends.values.isEmpty ? 0.0 : trends.values.reduce((a, b) => a < b ? a : b);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxValue > 0 ? maxValue / 5 : 100,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: sortedDates.length > 7 ? (sortedDates.length / 7).ceil() : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sortedDates.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('MM/dd').format(sortedDates[index]),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: maxValue > 0 ? maxValue / 5 : 100,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '\$${value.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          minX: 0,
          maxX: (sortedDates.length - 1).toDouble(),
          minY: minValue * 0.9,
          maxY: maxValue * 1.1,
          lineBarsData: [
            LineChartBarData(
              spots: sortedDates.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), trends[entry.value] ?? 0.0);
              }).toList(),
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

