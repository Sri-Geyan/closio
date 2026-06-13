import 'package:flutter/material.dart';
import '../services/zomato_service.dart';

class CartScreen extends StatefulWidget {
  final int restaurantId;
  final List<dynamic> cartItems;

  CartScreen({required this.restaurantId, required this.cartItems});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ZomatoService _zomatoService = ZomatoService();
  bool _isLoading = false;
  String? _cartId;
  Map<String, dynamic>? _cartDetails;

  @override
  void initState() {
    super.initState();
    _createCart();
  }

  Future<void> _createCart() async {
    setState(() => _isLoading = true);
    try {
      // Create cart using Zomato API
      // We pass a hardcoded addressId and paymentType for MVP.
      final res = await _zomatoService.createCart(
        widget.restaurantId, 
        widget.cartItems.map((item) => {
          'variant_id': item['variant_id'],
          'quantity': item['quantity']
        }).toList(),
        'addr_12345', 
        'upi'
      );
      
      setState(() {
        _cartId = res['cart_id'];
        _cartDetails = res;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create cart: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _checkout() async {
    if (_cartId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final res = await _zomatoService.checkout(_cartId!);
      // Checkout successful!
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order placed successfully!')));
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Your Cart')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = widget.cartItems[index];
                      return ListTile(
                        title: Text(item['name']),
                        subtitle: Text('Qty: ${item['quantity']}'),
                        trailing: Text('₹${item['price'] * item['quantity']}'),
                      );
                    },
                  ),
                ),
                if (_cartDetails != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('Total Amount: ₹${_cartDetails!['total_amount']}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _checkout,
                            child: Text('Checkout via UPI'),
                            style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                          ),
                        )
                      ],
                    ),
                  )
              ],
            ),
    );
  }
}
