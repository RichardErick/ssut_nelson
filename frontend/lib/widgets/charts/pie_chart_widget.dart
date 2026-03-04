import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EstadosPieChart extends StatefulWidget {
  final Map<String, dynamic> data;

  const EstadosPieChart({
    super.key,
    required this.data,
  });

  @override
  State<EstadosPieChart> createState() => _EstadosPieChartState();
}

class _EstadosPieChartState extends State<EstadosPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return Center(
        child: Text(
          'Sin datos para mostrar',
          style: GoogleFonts.inter(color: Colors.grey),
        ),
      );
    }

    final entries = widget.data.entries.toList();
    final total = entries.fold<double>(
      0,
      (sum, entry) => sum + (entry.value as num).toDouble(),
    );

    final colors = [
      Colors.green,
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.red,
    ];

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final isTouched = index == touchedIndex;
                  final fontSize = isTouched ? 16.0 : 12.0;
                  final radius = isTouched ? 70.0 : 60.0;
                  final value = (data.value as num).toDouble();
                  final percentage = total > 0 ? (value / total * 100) : 0;

                  return PieChartSectionData(
                    color: colors[index % colors.length],
                    value: value,
                    title: '${percentage.toStringAsFixed(1)}%',
                    radius: radius,
                    titleStyle: GoogleFonts.inter(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
              duration: const Duration(milliseconds: 250),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              final value = (data.value as num).toDouble();
              final percentage = total > 0 ? (value / total * 100) : 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.key,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${value.toInt()} (${percentage.toStringAsFixed(1)}%)',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
