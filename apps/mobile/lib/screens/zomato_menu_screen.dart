import 'package:flutter/material.dart';
import '../services/zomato_service.dart';
import 'cart_screen.dart';

class ZomatoMenuScreen extends StatefulWidget {
  final int restaurantId;
  final String restaurantName;

  ZomatoMenuScreen({required this.restaurantId, required this.restaurantName});

  @override
  _ZomatoMenuScreenState createState() => _ZomatoMenuScreenState();
}

class _ZomatoMenuScreenState extends State<ZomatoMenuScreen> {
  final ZomatoService _zomatoService = ZomatoService();
  bool _isLoading = true;
  List<dynamic> _menuCategories = [];
  List<dynamic> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _fetchMenu();
  }

  Future<void> _fetchMenu() async {
    try {
      final res = await _zomatoService.getMenu(widget.restaurantId);
      setState(() {
        _menuCategories = res['categories'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load menu: $e')));
    }
  }

  void _addToCart(dynamic item) {
    setState(() {
      _cartItems.add({
        'variant_id': item['variants'][0]['id'], // Assume first variant
        'quantity': 1,
        'name': item['name'],
        'price': item['variants'][0]['price']
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item['name']} added to cart')));
  }

  void _goToCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          restaurantId: widget.restaurantId,
          cartItems: _cartItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurantName),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: _cartItems.isNotEmpty ? _goToCart : null,
          )
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _menuCategories.length,
            itemBuilder: (context, index) {
              final category = _menuCategories[index];
              final items = category['items'] as List<dynamic>? ?? [];
              
              return ExpansionTile(
                title: Text(category['name'] ?? 'Category'),
                children: items.map((item) {
                  return ListTile(
                    title: Text(item['name'] ?? ''),
                    subtitle: Text('₹${item['variants']?[0]?['price'] ?? 0}'),
                    trailing: IconButton(
                      icon: Icon(Icons.add_circle_outline),
                      onPressed: () => _addToCart(item),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      floatingActionButton: _cartItems.isNotEmpty ? FloatingActionButton.extended(
        onPressed: _goToCart,
        label: Text('View Cart (${_cartItems.length})'),
        icon: Icon(Icons.shopping_cart),
      ) : null,
    );
  }
}
