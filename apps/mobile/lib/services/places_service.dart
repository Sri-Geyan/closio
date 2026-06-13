import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class PlacesService {
  static const String _apiKey = 'AIzaSyDrFSd3XPFYL3gq6oq8jlCfz5Pud63j-FQ';

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 + 
            c(lat1 * p) * c(lat2 * p) * 
            (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Real Google Places API query
  static Future<List<Map<String, dynamic>>> searchVenues(String query, double lat, double lng) async {
    final url = Uri.parse('https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(query)}&location=$lat,$lng&radius=5000&key=$_apiKey');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        
        return results.map((place) {
          final loc = place['geometry']['location'];
          final placeLat = loc['lat'];
          final placeLng = loc['lng'];
          final distance = _calculateDistance(lat, lng, placeLat, placeLng);
          
          return {
            'name': place['name'],
            'distance': '${distance.toStringAsFixed(1)} km',
            'rating': place['rating']?.toDouble() ?? 0.0,
            'openNow': place['opening_hours']?['open_now'] ?? false,
            'lat': placeLat,
            'lng': placeLng,
          };
        }).toList();
      }
    } catch (e) {
      print('Error fetching places: $e');
    }
    return [];
  }
  static Future<Map<String, dynamic>?> getCoordinates(String address) async {
    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if ((data['results'] as List).isNotEmpty) {
           final loc = data['results'][0]['geometry']['location'];
           return {'lat': loc['lat'], 'lng': loc['lng']};
        }
      }
    } catch (e) {
      print('Error geocoding: $e');
    }
    return null;
  }
}
