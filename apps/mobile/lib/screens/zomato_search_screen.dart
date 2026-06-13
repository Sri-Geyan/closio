import 'package:flutter/material.dart';
import '../services/zomato_service.dart';
import 'zomato_menu_screen.dart';

class ZomatoSearchScreen extends StatefulWidget {
  @override
  _ZomatoSearchScreenState createState() => _ZomatoSearchScreenState();
}

class _ZomatoSearchScreenState extends State<ZomatoSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ZomatoService _zomatoService = ZomatoService();
  
  bool _isLoading = false;
  List<dynamic> _restaurants = [];

  Future<void> _search() async {
    if (_searchController.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _restaurants = [];
    });
    
    try {
      // Hardcoded coordinates for MVP (could be fetched from device)
      final res = await _zomatoService.searchRestaurants(_searchController.text, 28.6139, 77.2090);
      setState(() {
        _restaurants = res['restaurants'] ?? [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search Restaurants')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for pizza, burger, etc.',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _search,
                )
              ],
            ),
          ),
          if (_isLoading) CircularProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _restaurants.length,
              itemBuilder: (context, index) {
                final r = _restaurants[index];
                return ListTile(
                  title: Text(r['name'] ?? 'Unknown'),
                  subtitle: Text(r['cuisines'] ?? ''),
                  trailing: Text(r['rating']?.toString() ?? ''),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ZomatoMenuScreen(
                          restaurantId: r['id'],
                          restaurantName: r['name'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
