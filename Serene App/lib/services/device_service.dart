import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceService {
  final String baseUrl;
  DeviceService({this.baseUrl = 'http://localhost:8080'});

  Future<List<Map<String, dynamic>>> listDevices() async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/devices'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['devices'] as List).cast<Map<String, dynamic>>();
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> registerDevice(
    Map<String, dynamic> device,
  ) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/devices'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(device),
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> updateDevice(
    String id,
    Map<String, dynamic> patch,
  ) async {
    try {
      final resp = await http.patch(
        Uri.parse('$baseUrl/devices/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(patch),
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
