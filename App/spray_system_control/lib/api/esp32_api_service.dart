// Cette classe isole toute la logique réseau.
// Si demain l'API change, on ne modifie que ce fichier.
import 'dart:async';
import 'dart:developer';
import 'package:http/http.dart' as http;

class Esp32ApiService {
  static const String _baseUrl = 'http://192.168.4.1';

  Future<http.Response?> sendCommand(
    String endpoint, {
    Map<String, String>? params,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/$endpoint',
      ).replace(queryParameters: params);
      log('Sending command: $uri');
      // Timeout pour éviter une attente infinie si l'ESP32 ne répond pas
      return await http.get(uri).timeout(const Duration(seconds: 3));
    } catch (e) {
      log('Error sending command to $endpoint: $e');
      return null;
    }
  }

  Future<http.Response?> fetchTelemetry() async {
    try {
      final uri = Uri.parse('$_baseUrl/telemetry');
      return await http.get(uri).timeout(const Duration(seconds: 2));
    } catch (e) {
      log('Error fetching telemetry: $e');
      return null;
    }
  }
}
