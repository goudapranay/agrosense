import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class PolygonMapScreen extends StatefulWidget {
  const PolygonMapScreen({super.key});
  @override
  State<PolygonMapScreen> createState() => _PolygonMapScreenState();
}

class _PolygonMapScreenState extends State<PolygonMapScreen> {
  final List<LatLng> _points = [];
  final MapController _ctrl = MapController();
  bool _locating = false;

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8));
      _ctrl.move(LatLng(pos.latitude, pos.longitude), 17);
    } catch (_) {} finally {
      setState(() => _locating = false);
    }
  }

  void _undo() {
    if (_points.isNotEmpty) setState(() => _points.removeLast());
  }

  double _areaAcres() {
    if (_points.length < 3) return 0;
    double area = 0;
    int n = _points.length;
    for (int i = 0; i < n; i++) {
      int j = (i + 1) % n;
      area += _points[i].longitude * _points[j].latitude;
      area -= _points[j].longitude * _points[i].latitude;
    }
    area = area.abs() / 2;
    double sqKm = area * 111.32 * 111.32 *
        (3.14159 / 180 * _points[0].latitude).abs().clamp(0.1, 1.0);
    return sqKm * 247.105;
  }

  void _confirm() {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mark at least 3 corner points')));
      return;
    }
    final polygon = _points.map((p) => [p.latitude, p.longitude]).toList();
    Navigator.pop(context, polygon);
  }

  @override
  Widget build(BuildContext context) {
    final area = _areaAcres();
    final markers = _points.asMap().entries.map((e) => Marker(
      point: e.value,
      width: 36, height: 36,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(child: Text('${e.key + 1}',
            style: const TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.w700))),
      ),
    )).toList();

    final polygonLayer = _points.length >= 3
        ? PolygonLayer(polygons: [
            Polygon(
              points: [..._points, _points.first],
              color: const Color(0x332E7D32),
              borderColor: const Color(0xFF2E7D32),
              borderStrokeWidth: 2.5,
            ),
          ])
        : const PolygonLayer(polygons: []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw Field Boundary'),
        actions: [
          if (_points.isNotEmpty)
            IconButton(icon: const Icon(Icons.undo), onPressed: _undo,
                tooltip: 'Undo last point'),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _ctrl,
            options: MapOptions(
              initialCenter: const LatLng(17.385, 78.4867),
              initialZoom: 15,
              onTap: (_, pos) => setState(() => _points.add(pos)),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.agrosense.app',
              ),
              polygonLayer,
              MarkerLayer(markers: markers),
            ],
          ),

          // Top info banner
          Positioned(
            top: 12, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                const Icon(Icons.touch_app, color: Color(0xFF2E7D32), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _points.isEmpty
                      ? 'Tap field corners to draw boundary'
                      : _points.length < 3
                          ? 'Add ${3 - _points.length} more point(s)'
                          : '${_points.length} points  •  ${area.toStringAsFixed(2)} acres',
                  style: TextStyle(
                    fontSize: 13,
                    color: _points.length >= 3 ? const Color(0xFF2E7D32) : const Color(0xFF374151),
                    fontWeight: _points.length >= 3 ? FontWeight.w600 : FontWeight.normal,
                  ),
                )),
              ]),
            ),
          ),

          // Controls
          Positioned(
            right: 16, bottom: 100,
            child: Column(children: [
              _MapBtn(icon: Icons.my_location,
                  loading: _locating, onTap: _goToMyLocation),
              const SizedBox(height: 8),
              _MapBtn(icon: Icons.add, onTap: () =>
                  _ctrl.move(_ctrl.camera.center, _ctrl.camera.zoom + 1)),
              const SizedBox(height: 4),
              _MapBtn(icon: Icons.remove, onTap: () =>
                  _ctrl.move(_ctrl.camera.center, _ctrl.camera.zoom - 1)),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            if (_points.isNotEmpty) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _points.clear()),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: Color(0xFFBDBDBD)),
                    foregroundColor: const Color(0xFF6B7280),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _points.length >= 3 ? _confirm : null,
                child: Text(_points.length < 3
                    ? 'Mark ${3 - _points.length} more point(s)'
                    : 'Confirm Field (${area.toStringAsFixed(1)} ac)'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;
  const _MapBtn({required this.icon, required this.onTap, this.loading = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: loading
          ? const Center(child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32))))
          : Icon(icon, size: 20, color: const Color(0xFF374151)),
    ),
  );
}
