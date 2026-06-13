import 'dart:convert';
import 'package:http/http.dart' as http;

class ItunesService {
  static const String baseUrl = 'https://itunes.apple.com/search';

  static Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await http.get(Uri.parse('$baseUrl?term=$query&entity=song&limit=20'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>;
        
        return results.map((track) {
          // Construct a Spotify deep link from the title/artist (heuristic since iTunes doesn't have Spotify IDs)
          // The best we can do is create a search query deep link
          final searchStr = Uri.encodeComponent('${track['trackName']} ${track['artistName']}');
          
          return {
            'title': track['trackName'],
            'artist': track['artistName'],
            'albumArt': track['artworkUrl100']?.replaceAll('100x100bb', '300x300bb'), // get larger image
            'spotifyUrl': 'spotify:search:$searchStr',
          };
        }).toList();
      }
    } catch (e) {
      print('Error searching iTunes: $e');
    }
    return [];
  }
}
