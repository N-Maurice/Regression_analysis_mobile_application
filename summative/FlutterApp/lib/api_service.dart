import 'dart:convert';
import 'package:http/http.dart' as http;

class PredictionException implements Exception {
  final String message;
  PredictionException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = "https://regression-analysis-mobile-application-om0i.onrender.com";

  static const String predictPath = "/predict";

  static Uri get _predictUri => Uri.parse('$baseUrl$predictPath');

  static Future<double> predictCorruption(Map<String, double> features) async {
    try {
      final response = await http
          .post(
            _predictUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(features),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        final value = data['control_of_corruption'];
        if (value == null) {
          throw PredictionException(
            'The server response did not include a "control_of_corruption" value.',
          );
        }
        return (value as num).toDouble();
      }

      throw PredictionException(
        'Prediction request failed (status ${response.statusCode}). '
        'Please try again later.',
      );
    } on PredictionException {
      rethrow;
    } catch (e) {
      throw PredictionException(
        'Could not reach the prediction service. '
        'Check your connection or try again later.\n($e)',
      );
    }
  }
}
