import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddFarmerScreen extends StatefulWidget {
  const AddFarmerScreen({super.key});
  @override
  State<AddFarmerScreen> createState() => _AddFarmerScreenState();
}

class _AddFarmerScreenState extends State<AddFarmerScreen> {
  final _name    = TextEditingController();
  final _phone   = TextEditingController();
  final _village = TextEditingController();
  final _acres   = TextEditingController();
  bool _loading  = false;
  String? _error;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService().createFarmer(
        name:    _name.text.trim(),
        phone:   _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        village: _village.text.trim().isEmpty ? null : _village.text.trim(),
        acres:   double.tryParse(_acres.text) ?? 0,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = 'Could not save. Check connection.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Farmer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('👨‍🌾', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text('Farmer Details', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A3A1A))),
            const SizedBox(height: 24),

            _label('Full Name *'),
            TextField(controller: _name, decoration: const InputDecoration(hintText: 'e.g. Ravi Kumar')),
            const SizedBox(height: 16),

            _label('Phone Number'),
            TextField(controller: _phone, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '+91 9876543210')),
            const SizedBox(height: 16),

            _label('Village / Town'),
            TextField(controller: _village,
                decoration: const InputDecoration(hintText: 'e.g. Medak, Telangana')),
            const SizedBox(height: 16),

            _label('Total Land (acres)'),
            TextField(controller: _acres,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: '2.5')),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ],

            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 10),
                      Text('Saving...'),
                    ])
                  : const Text('Save Farmer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
  );
}
