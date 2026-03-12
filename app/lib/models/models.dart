class Farmer {
  final int? id;
  final String name;
  final String? phone, village;
  final double acres;
  final List<Field> fields;

  Farmer({this.id, required this.name, this.phone, this.village,
      this.acres = 0, this.fields = const []});

  factory Farmer.fromJson(Map<String, dynamic> j) => Farmer(
    id:      j['id'],
    name:    j['name'],
    phone:   j['phone'],
    village: j['village'],
    acres:   (j['acres'] ?? 0).toDouble(),
    fields:  (j['fields'] as List? ?? []).map((f) => Field.fromJson(f)).toList(),
  );
}

class Field {
  final int? id;
  final int farmerId;
  final String name;
  final List<List<double>> polygon;
  final double areaAcres;
  final String? crop;

  Field({this.id, required this.farmerId, required this.name,
      required this.polygon, this.areaAcres = 0, this.crop});

  factory Field.fromJson(Map<String, dynamic> j) => Field(
    id:        j['id'],
    farmerId:  j['farmer_id'],
    name:      j['name'] ?? 'Field',
    polygon:   (j['polygon'] is String
        ? (j['polygon'] as String).isNotEmpty
            ? List<List<double>>.from(
                (j['polygon'] as String)
                    .replaceAll('[','').replaceAll(']','')
                    .split(',')
                    .map((s) => double.tryParse(s.trim()) ?? 0)
                    .toList()
                    .fold<List<List<double>>>([], (acc, v) {
                      if (acc.isEmpty || acc.last.length == 2) acc.add([]);
                      acc.last.add(v);
                      return acc;
                    }))
            : []
        : List<List<double>>.from(
            (j['polygon'] as List).map((p) =>
                List<double>.from((p as List).map((v) => (v as num).toDouble()))))),
    areaAcres: (j['area_acres'] ?? 0).toDouble(),
    crop:      j['crop'],
  );
}

class NdviPoint {
  final String month;
  final double? ndvi;
  NdviPoint({required this.month, this.ndvi});
  factory NdviPoint.fromJson(Map<String, dynamic> j) =>
      NdviPoint(month: j['month'], ndvi: j['ndvi']?.toDouble());
}

class Insights {
  final int healthScore;
  final double peakNdvi, avgNdvi;
  final String peakMonth, pestRisk, bestSowMonth;
  final bool waterStress;
  final double? yieldEstimate;

  Insights({required this.healthScore, required this.peakNdvi,
      required this.avgNdvi, required this.peakMonth,
      required this.pestRisk, required this.bestSowMonth,
      required this.waterStress, this.yieldEstimate});

  factory Insights.fromJson(Map<String, dynamic> j) => Insights(
    healthScore:   j['health_score'] ?? 0,
    peakNdvi:      (j['peak_ndvi'] ?? 0).toDouble(),
    avgNdvi:       (j['avg_ndvi'] ?? 0).toDouble(),
    peakMonth:     j['peak_month'] ?? '—',
    pestRisk:      j['pest_risk'] ?? 'Unknown',
    bestSowMonth:  j['best_sow_month'] ?? '—',
    waterStress:   j['water_stress'] ?? false,
    yieldEstimate: j['yield_estimate']?.toDouble(),
  );
}

class CropRec {
  final String crop, emoji, sowing, harvest, suitability, reason;
  CropRec({required this.crop, required this.emoji, required this.sowing,
      required this.harvest, required this.suitability, required this.reason});
  factory CropRec.fromJson(Map<String, dynamic> j) => CropRec(
    crop:        j['crop'],
    emoji:       j['emoji'],
    sowing:      j['sowing'],
    harvest:     j['harvest'],
    suitability: j['suitability'],
    reason:      j['reason'],
  );
}

class FieldAnalysis {
  final int fieldId;
  final double areaAcres;
  final Map<String, double> env;
  final List<NdviPoint> ndvi;
  final Insights insights;
  final List<CropRec> crops;
  final bool gee;

  FieldAnalysis({required this.fieldId, required this.areaAcres,
      required this.env, required this.ndvi, required this.insights,
      required this.crops, required this.gee});

  factory FieldAnalysis.fromJson(Map<String, dynamic> j) => FieldAnalysis(
    fieldId:    j['field_id'],
    areaAcres:  (j['area_acres'] ?? 0).toDouble(),
    env:        Map<String, double>.from(
        (j['env'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble()))),
    ndvi:       (j['ndvi'] as List).map((e) => NdviPoint.fromJson(e)).toList(),
    insights:   Insights.fromJson(j['insights'] ?? {}),
    crops:      (j['crops'] as List).map((e) => CropRec.fromJson(e)).toList(),
    gee:        j['gee'] ?? false,
  );
}
