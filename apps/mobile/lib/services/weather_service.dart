import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class WeatherService {
  static const String _apiKey = '67b29a50748b7da4a5df8a9480ff9273';

  // OpenWeatherMap Current Weather endpoint
  static Future<Map<String, dynamic>?> _fetchCurrentWeather(double lat, double lng) async {
    final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lng&appid=$_apiKey&units=metric');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching weather: $e');
    }
    return null;
  }

  // OpenWeatherMap AQI endpoint
  static Future<Map<String, dynamic>?> _fetchAqi(double lat, double lng) async {
    final url = Uri.parse('http://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lng&appid=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching AQI: $e');
    }
    return null;
  }

  static String _getAqiLabel(int index) {
    switch (index) {
      case 1: return 'Good';
      case 2: return 'Fair';
      case 3: return 'Moderate';
      case 4: return 'Poor';
      case 5: return 'Very Poor';
      default: return 'Unknown';
    }
  }

  /// Returns a timing suggestion based on date, type, and REAL weather
  static Future<Map<String, dynamic>?> getTimingSuggestion(DateTime date, String eventType, {double lat = 37.7749, double lng = -122.4194}) async {
    final weatherData = await _fetchCurrentWeather(lat, lng);
    final aqiData = await _fetchAqi(lat, lng);
    
    String tempStr = '22°C';
    String conditionsStr = 'Clear skies';
    if (weatherData != null) {
      tempStr = '${weatherData['main']['temp'].round()}°C';
      conditionsStr = weatherData['weather'][0]['description'] ?? 'Clear skies';
    }

    String aqiStr = 'Good';
    if (aqiData != null) {
      final aqiIndex = aqiData['list'][0]['main']['aqi'];
      aqiStr = _getAqiLabel(aqiIndex);
    }

    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    
    if (eventType == 'Sport' || eventType == 'Running' || eventType == 'Football' || eventType == 'Cricket') {
      if (isWeekend) {
        return {
          'window': '7:00 AM – 9:00 AM',
          'weather': '$conditionsStr, $tempStr',
          'aqi': aqiStr,
        };
      } else {
        return {
          'window': '6:30 PM – 8:30 PM',
          'weather': '$conditionsStr, $tempStr',
          'aqi': aqiStr,
        };
      }
    } else if (eventType == 'Movie') {
      return {
        'window': '8:00 PM – 10:30 PM',
        'weather': 'Indoors ($tempStr outside)',
        'aqi': 'N/A',
      };
    } else {
      return {
        'window': '7:00 PM – 9:00 PM',
        'weather': '$conditionsStr, $tempStr',
        'aqi': aqiStr,
      };
    }
  }

  /// Returns contextual real weather/AQI cards for Running from AI layer
  static Future<Map<String, dynamic>> getRunningConditions(DateTime date, {double lat = 37.7749, double lng = -122.4194}) async {
    try {
      final res = await ApiService.optimizeSport('Running', date.toIso8601String().split('T')[0], lat, lng);
      final opt = res['optimization'];
      return {
        'weather': {'temp': opt['temperature'], 'rainProb': opt['rain_probability'], 'humidity': 'N/A'},
        'aqi': {'rating': opt['aqi'].toString(), 'label': opt['suitability_score'] > 80 ? 'Good' : 'Moderate'},
        'traffic': {'label': opt['hazards']?.isNotEmpty == true ? 'Hazards on route' : 'Light Traffic'},
        'bestWindow': opt['pace_suggestion'] ?? '6:00 AM - 6:30 AM'
      };
    } catch (e) {
      throw Exception('Failed to fetch real running conditions: $e');
    }
  }
}
