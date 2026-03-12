import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'polygon_map_screen.dart';
import 'field_analysis_screen.dart';

class FarmerDetailScreen extends StatefulWidget {
  final Farmer farmer;
  const FarmerDetailScreen({super.key, required this.farmer});
  @override
  State<FarmerDetailScreen> createState() => _FarmerDetailScreenState();
}

class _FarmerDetailScreenState extends State<FarmerDetailScreen> {
  late Farmer _farmer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _farmer = widget.farmer;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final f = await ApiService().getFarmer(_farmer.id!);
      setState(() { _farmer = f; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addField() async {
    final polygon = await Navigator.push<List<List<double>>>(
      context,
      MaterialPageRoute(builder: (_) => const PolygonMapScreen()),
    );
    if (polygon == null || polygon.length < 3) return;

    final nameCtrl = TextEditingController(text: 'Field ${_farmer.fields.length + 1}');
    final cropCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Name this field'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Field name')),
          const SizedBox(height: 12),
          TextField(controller: cropCtrl,
              decoration: const InputDecoration(labelText: 'Current crop (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService().createField(
        farmerId: _farmer.id!,
        name: nameCtrl.text,
        polygon: polygon,
        crop: cropCtrl.text.isEmpty ? null : cropCtrl.text,
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save field')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_farmer.name),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Farmer info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE8F5E9),
                      radius: 28,
                      child: Text(_farmer.name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 22,
                              fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_farmer.name, style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                          if (_farmer.phone != null)
                            _InfoRow(Icons.phone, _farmer.phone!),
                          if (_farmer.village != null)
                            _InfoRow(Icons.location_on, _farmer.village!),
                          _InfoRow(Icons.landscape, '${_farmer.acres} acres total'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                const Text('Fields', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A3A1A))),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addField,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Draw Field'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF2E7D32)),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (_loading)
              const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
            else if (_farmer.fields.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7F0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD4E8D4)),
                ),
                child: Column(children: [
                  const Text('🗺', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  const Text('No fields yet', style: TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF1A3A1A))),
                  const SizedBox(height: 6),
                  const Text('Tap "Draw Field" to mark field boundaries\non the satellite map',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addField,
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text('Draw Field on Map'),
                  ),
                ]),
              )
            else
              ...(_farmer.fields.map((f) => _FieldCard(
                field: f,
                onAnalyze: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => FieldAnalysisScreen(field: f))),
                onDelete: () async {
                  await ApiService().deleteField(f.id!);
                  _refresh();
                },
              ))),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(children: [
      Icon(icon, size: 13, color: const Color(0xFF9E9E9E)),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
    ]),
  );
}

class _FieldCard extends StatelessWidget {
  final Field field;
  final VoidCallback onAnalyze, onDelete;
  const _FieldCard({required this.field, required this.onAnalyze, required this.onDelete});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🗺', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(field.name, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
                Text('${field.areaAcres.toStringAsFixed(2)} acres  •  '
                    '${field.polygon.length} boundary points',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFBDBDBD), size: 20),
              onPressed: onDelete,
            ),
          ]),
          if (field.crop != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Current: ${field.crop}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFF57C00))),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAnalyze,
              icon: const Icon(Icons.satellite_alt, size: 16),
              label: const Text('Analyze Field (NDVI + Advisory)'),
            ),
          ),
        ],
      ),
    ),
  );
}
