import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'add_farmer_screen.dart';
import 'farmer_detail_screen.dart';

class FarmersScreen extends StatefulWidget {
  const FarmersScreen({super.key});
  @override
  State<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends State<FarmersScreen> {
  List<Farmer> _farmers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final farmers = await ApiService().getFarmers();
      setState(() { _farmers = farmers; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Cannot connect to server'; _loading = false; });
    }
  }

  Future<void> _delete(Farmer f) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${f.name}?'),
        content: const Text('This will remove the farmer and all their fields.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService().deleteFarmer(f.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('🌾', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AgroSense', style: TextStyle(fontSize: 20,
                          fontWeight: FontWeight.w800, color: Color(0xFF1A3A1A))),
                      Text('Smart Crop Advisory', style: TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF2E7D32)),
                    onPressed: _load,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Farmers (${_farmers.length})',
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700, color: Color(0xFF1A3A1A))),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AddFarmerScreen()));
                      _load();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Farmer'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF2E7D32)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
                  : _error != null
                      ? _ErrorView(error: _error!, onRetry: _load)
                      : _farmers.isEmpty
                          ? _EmptyView(onAdd: () async {
                              await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const AddFarmerScreen()));
                              _load();
                            })
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: _farmers.length,
                              itemBuilder: (_, i) => _FarmerCard(
                                farmer: _farmers[i],
                                onTap: () async {
                                  await Navigator.push(context,
                                      MaterialPageRoute(builder: (_) =>
                                          FarmerDetailScreen(farmer: _farmers[i])));
                                  _load();
                                },
                                onDelete: () => _delete(_farmers[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Farmer', style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddFarmerScreen()));
          _load();
        },
      ),
    );
  }
}

class _FarmerCard extends StatelessWidget {
  final Farmer farmer;
  final VoidCallback onTap, onDelete;
  const _FarmerCard({required this.farmer, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE8F5E9),
                radius: 22,
                child: Text(farmer.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(farmer.name, style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Row(children: [
                      if (farmer.village != null) ...[
                        const Icon(Icons.location_on, size: 12, color: Color(0xFF9E9E9E)),
                        const SizedBox(width: 3),
                        Text(farmer.village!, style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9E9E9E))),
                        const SizedBox(width: 10),
                      ],
                      const Icon(Icons.landscape, size: 12, color: Color(0xFF9E9E9E)),
                      const SizedBox(width: 3),
                      Text('${farmer.acres} ac', style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9E9E9E))),
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${farmer.fields.length} fields',
                        style: const TextStyle(fontSize: 11,
                            color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFBDBDBD)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('👨‍🌾', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      const Text('No farmers yet', style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.w700, color: Color(0xFF1A3A1A))),
      const SizedBox(height: 8),
      const Text('Add your first farmer to get started',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add Farmer'),
      ),
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
      const Icon(Icons.wifi_off, size: 48, color: Color(0xFFBDBDBD)),
      const SizedBox(height: 12),
      Text(error, style: const TextStyle(color: Color(0xFF6B7280))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  );
}
