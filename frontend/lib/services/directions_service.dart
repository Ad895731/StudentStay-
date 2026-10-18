import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class DirectionsService {
  /// Builds the Google Maps directions URL with the specified destination coordinates.
  static String buildDirectionsUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
  }

  /// Opens Google Maps with directions to the destination.
  /// Falls back gracefully to browser or platform default if external app cannot open.
  static Future<bool> launchDirections(double latitude, double longitude) async {
    final urlStr = buildDirectionsUrl(latitude, longitude);
    final uri = Uri.parse(urlStr);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        return await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error launching directions: $e');
      return false;
    }
  }
}
