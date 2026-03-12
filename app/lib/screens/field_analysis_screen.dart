import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class FieldAnalysisScreen extends StatefulWidget {
  final Field field;
  const FieldAnalysisScreen({super.key, required this.field});
  @override
  State<FieldAnalysisScreen> createState() => _FieldAnalysisScreenState();
}

class _FieldAnalysisScreenState extends State<FieldAnalysisScreen> {
  FieldAnalysis? _analysis;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() { _loading = true; _error = null; });
    try {
      final a = await ApiService().analyzeField(widget.field.id!);
      setState(() { _analysis = a; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Analysis failed. Check connection.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.field.name),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _analyze),
        ],
      ),
      body: _loading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _analyze)
              : _AnalysisBody(analysis: _analysis!),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(color: Color(0xFF2E7D32)),
      const SizedBox(height: 16),
      const Text('Querying satellite data...', style: TextStyle(
          fontSize: 15, color: Color(0xFF6B7280))),
      const SizedBox(height: 6),
      Text('This may take 5–10 seconds', style: TextStyle(
          fontSize: 12, color: Colors.grey[400])),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Color(0xFFBDBDBD)),
      const SizedBox(height: 12),
      Text(error, style: const TextStyle(color: Color(0xFF6B7280))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  );
}

class _AnalysisBody extends StatelessWidget {
  final FieldAnalysis analysis;
  const _AnalysisBody({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final ins = analysis.insights;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Data source badge
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: analysis.gee ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Icon(analysis.gee ? Icons.satellite_alt : Icons.science,
                    size: 14,
                    color: analysis.gee ? const Color(0xFF2E7D32) : const Color(0xFFF57C00)),
                const SizedBox(width: 5),
                Text(
                  analysis.gee ? 'Live Satellite Data' : 'Simulated Data',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: analysis.gee ? const Color(0xFF2E7D32) : const Color(0xFFF57C00)),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Text('${analysis.areaAcres.toStringAsFixed(2)} acres',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ]),

          const SizedBox(height: 16),

          // Env data row
          Row(children: [
            _EnvCard('🌧', '${analysis.env['rainfall']?.toStringAsFixed(0)}mm', 'Rainfall'),
            const SizedBox(width: 8),
            _EnvCard('🌡', '${analysis.env['temp']?.toStringAsFixed(1)}°C', 'Temp'),
            const SizedBox(width: 8),
            _EnvCard('🪨', '${analysis.env['soil']?.toStringAsFixed(0)}%', 'Clay'),
          ]),

          const SizedBox(height: 16),

          // Insights grid
          const _SectionTitle('Field Insights'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _InsightCard(
                emoji: '🌱',
                title: 'Crop Health',
                value: '${ins.healthScore}/100',
                sub: 'Peak NDVI ${ins.peakNdvi.toStringAsFixed(2)}',
                color: ins.healthScore > 60 ? const Color(0xFF2E7D32) : const Color(0xFFF57C00),
              ),
              _InsightCard(
                emoji: '💧',
                title: 'Water Stress',
                value: ins.waterStress ? 'Detected' : 'None',
                sub: ins.waterStress ? 'Consider irrigation' : 'Moisture adequate',
                color: ins.waterStress ? Colors.red : const Color(0xFF2E7D32),
              ),
              _InsightCard(
                emoji: '🌾',
                title: 'Est. Yield',
                value: ins.yieldEstimate != null
                    ? '${ins.yieldEstimate!.toStringAsFixed(0)} qtl'
                    : '—',
                sub: 'Based on NDVI × area',
                color: const Color(0xFFF57C00),
              ),
              _InsightCard(
                emoji: '⚠️',
                title: 'Pest Risk',
                value: ins.pestRisk,
                sub: ins.pestRisk == 'High' ? 'Check for pests' : 'Low activity',
                color: ins.pestRisk == 'High'
                    ? Colors.red
                    : ins.pestRisk == 'Medium'
                        ? const Color(0xFFF57C00)
                        : const Color(0xFF2E7D32),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Best sow window
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Row(children: [
              const Text('📅', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Best Sowing Window',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: Color(0xFF1A3A1A))),
                Text(ins.bestSowMonth,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                        color: Color(0xFF2E7D32))),
                Text('Peak crop growth: ${ins.peakMonth}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ]),
          ),

          const SizedBox(height: 20),

          // NDVI chart
          const _SectionTitle('NDVI Time Series — Last 12 Months'),
          const SizedBox(height: 6),
          const Text('Monthly maximum vegetation index',
              style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
          const SizedBox(height: 12),
          _NdviChart(points: analysis.ndvi),

          // NDVI legend
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 6, children: const [
            _NdviLegend(Color(0xFF2E7D32), '0.6+ Healthy'),
            _NdviLegend(Color(0xFF8BC34A), '0.4–0.6 Moderate'),
            _NdviLegend(Color(0xFFF57C00), '0.2–0.4 Sparse'),
            _NdviLegend(Colors.red, '<0.2 Bare/Stress'),
          ]),

          const SizedBox(height: 20),

          // Crop recommendations
          const _SectionTitle('Crop Recommendations'),
          const SizedBox(height: 10),
          ...analysis.crops.map((c) => _CropCard(crop: c)),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ── NDVI Chart ─────────────────────────────────────────────────────────────────

class _NdviChart extends StatelessWidget {
  final List<NdviPoint> points;
  const _NdviChart({required this.points});

  Color _ndviColor(double v) {
    if (v >= 0.6) return const Color(0xFF2E7D32);
    if (v >= 0.4) return const Color(0xFF8BC34A);
    if (v >= 0.2) return const Color(0xFFF57C00);
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final valid = points.where((p) => p.ndvi != null).toList();
    if (valid.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFF5F5F0),
            borderRadius: BorderRadius.circular(12)),
        child: const Text('No NDVI data available',
            style: TextStyle(color: Color(0xFF9E9E9E))),
      );
    }

    final spots = points.asMap().entries
        .where((e) => e.value.ndvi != null)
        .map((e) => FlSpot(e.key.toDouble(), e.value.ndvi!))
        .toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E4DC)),
      ),
      child: LineChart(
        LineChartData(
          minY: 0, maxY: 1.0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.2,
            getDrawingHorizontalLine: (_) => FlLine(
                color: const Color(0xFFF0EDE8), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 0.2,
                getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox();
                  final month = points[i].month.split(' ')[0]; // "Jun"
                  return Text(month, style: const TextStyle(
                      fontSize: 9, color: Color(0xFF9E9E9E)));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF2E7D32),
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: _ndviColor(spot.y),
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0x222E7D32),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final i = s.spotIndex;
                return LineTooltipItem(
                  '${points[i].month}\nNDVI: ${s.y.toStringAsFixed(3)}',
                  const TextStyle(fontSize: 11, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
          color: Color(0xFF1A3A1A)));
}

class _EnvCard extends StatelessWidget {
  final String emoji, value, label;
  const _EnvCard(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E4DC)),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w700, color: Color(0xFF1A3A1A))),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
      ]),
    ),
  );
}

class _InsightCard extends StatelessWidget {
  final String emoji, title, value, sub;
  final Color color;
  const _InsightCard({required this.emoji, required this.title,
      required this.value, required this.sub, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE8E4DC)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
      Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 11,
            color: Color(0xFF9E9E9E), fontWeight: FontWeight.w500)),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w800, color: color)),
        Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
      ]),
    ]),
  );
}

class _NdviLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _NdviLegend(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(
        color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
  ]);
}

class _CropCard extends StatelessWidget {
  final CropRec crop;
  const _CropCard({required this.crop});

  Color get _color {
    if (crop.suitability == 'high') return const Color(0xFF2E7D32);
    if (crop.suitability == 'medium') return const Color(0xFFF57C00);
    return const Color(0xFF9E9E9E);
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Text(crop.emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(crop.crop, style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w700, color: _color)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(crop.suitability, style: TextStyle(
                  fontSize: 10, color: _color, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(crop.reason, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Row(children: [
            _DateChip('Sow', crop.sowing),
            const SizedBox(width: 8),
            _DateChip('Harvest', crop.harvest),
          ]),
        ])),
      ]),
    ),
  );
}

class _DateChip extends StatelessWidget {
  final String label, value;
  const _DateChip(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F0),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text('$label: $value', style: const TextStyle(
        fontSize: 11, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
  );
}
