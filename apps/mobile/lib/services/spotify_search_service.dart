import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class SpotifySearchService {
  static Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('${ApiService.backendUrl}/jukebox/spotify/search?q=$query'),
        headers: await ApiService.getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['tracks']['items'] as List<dynamic>;
        
        return items.map((track) {
          String? albumArt;
          if (track['album']['images'] != null && track['album']['images'].isNotEmpty) {
            albumArt = track['album']['images'][0]['url'];
          }
          
          return {
            'title': track['name'],
            'artist': track['artists'][0]['name'],
            'albumArt': albumArt,
            'spotifyUrl': track['uri'], // This is the spotify:track:... URI
          };
        }).toList();
      }
    } catch (e) {
      print('Error searching Spotify: $e');
    }
    return [];
  }
}
