import 'location_data.dart';

class LocationsResponse {
  final bool success;
  final List<LocationData> locations;

  LocationsResponse({required this.success, required this.locations});

  factory LocationsResponse.fromJson(dynamic json) {
    // Handle both array response and object response
    if (json is List) {
      // Direct array from PHP endpoint
      return LocationsResponse(
        success: true,
        locations: json
            .map((item) => LocationData.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    } else if (json is Map<String, dynamic>) {
      // Wrapped response
      return LocationsResponse(
        success: true,
        locations: (json['locations'] as List)
            .map((item) => LocationData.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    } else {
      throw Exception('Invalid response format');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'locations': locations.map((location) => location.toJson()).toList(),
    };
  }
}
