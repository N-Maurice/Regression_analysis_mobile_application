import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown when the prediction request fails for any reason (network,
/// server error, unexpected response shape, etc.).
class PredictionException implements Exception {
  final String message;
  PredictionException(this.message);

  @override
  String toString() => message;
}

/// Handles communication with the corruption-risk prediction backend.
class ApiService {
  // TODO: Replace with your deployed API's base URL.
  // Example: "https://your-corruption-api.onrender.com"
  static const String baseUrl = "https://regression-analysis-mobile-application-om0i.onrender.com";

  // TODO: Replace with the actual prediction route on your backend.
  // Example: "/api/v1/predict"
  static const String predictPath = "/predict";

  static Uri get _predictUri => Uri.parse('$baseUrl$predictPath');

  /// Sends the 10 WGI governance indicators to the backend and returns the
  /// predicted `cce` (Control of Corruption — Estimate) value.
  ///
  /// Expects the backend to return JSON shaped like:
  /// ```json
  /// { "cce_prediction": 0.732 }
  /// ```
  /// Adjust the response-parsing key below (`cce_prediction`) to match
  /// whatever key your deployed API actually returns.
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

        // Adjust this key to match your API's actual response field.
        final value = data['cce_prediction'];
        if (value == null) {
          throw PredictionException(
            'The server response did not include a "cce_prediction" value.',
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
