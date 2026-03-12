import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

const String kBaseUrl = 'http://10.0.2.2:8000';
// const String kBaseUrl = 'https://agrosense-6wbu.onrender.com';

class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  final _client = http.Client();

  Future<Map<String, dynamic>> _post(String path, Map body) async {
    final res = await _client.post(
      Uri.parse('$kBaseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('${res.statusCode}: ${res.body}');
  }

  Future<dynamic> _get(String path) async {
    final res = await _client.get(Uri.parse('$kBaseUrl$path'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('${res.statusCode}: ${res.body}');
  }

  Future<dynamic> _delete(String path) async {
    final res = await _client.delete(Uri.parse('$kBaseUrl$path'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('${res.statusCode}');
  }

  // Farmers
  Future<List<Farmer>> getFarmers() async {
    final data = await _get('/farmers');
    return (data as List).map((e) => Farmer.fromJson(e)).toList();
  }

  Future<Farmer> getFarmer(int id) async {
    final data = await _get('/farmers/$id');
    return Farmer.fromJson(data);
  }

  Future<Farmer> createFarmer({
    required String name, String? phone, String? village, double acres = 0,
  }) async {
    final data = await _post('/farmers',
        {'name': name, 'phone': phone, 'village': village, 'acres': acres});
    return Farmer.fromJson(data);
  }

  Future<void> deleteFarmer(int id) => _delete('/farmers/$id');

  // Fields
  Future<Field> createField({
    required int farmerId, required String name,
    required List<List<double>> polygon, String? crop,
  }) async {
    final data = await _post('/fields', {
      'farmer_id': farmerId, 'name': name,
      'polygon': polygon, 'crop': crop,
    });
    return Field.fromJson(data);
  }

  Future<void> deleteField(int id) => _delete('/fields/$id');

  // Analysis
  Future<FieldAnalysis> analyzeField(int fieldId) async {
    final data = await _post('/analyze', {'field_id': fieldId});
    return FieldAnalysis.fromJson(data);
  }
}
