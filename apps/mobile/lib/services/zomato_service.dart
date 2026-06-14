import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

class ZomatoService {
  String get baseUrl => ApiService.backendUrl;

  Future<Map<String, String>> _getHeaders() async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> bindNumber(String phoneNumber) async {
    final response = await http.post(
      Uri.parse('$baseUrl/zomato/bind'),
      headers: await _getHeaders(),
      body: jsonEncode({'phoneNumber': phoneNumber}),
    );
    return jsonDecode(response.body);
  }

  Future<dynamic> verifyCode(String code, String stateId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/zomato/verify'),
      headers: await _getHeaders(),
      body: jsonEncode({'code': code, 'stateId': stateId}),
    );
    return jsonDecode(response.body);
  }

  Future<dynamic> searchRestaurants(String keyword, double lat, double lng) async {
    final response = await http.get(
      Uri.parse('$baseUrl/zomato/restaurants?keyword=$keyword&lat=$lat&lng=$lng'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  Future<dynamic> getMenu(int resId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/zomato/restaurants/$resId/menu'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  Future<dynamic> createCart(int resId, List<dynamic> items, String addressId, String paymentType) async {
    final response = await http.post(
      Uri.parse('$baseUrl/zomato/cart'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'resId': resId,
        'items': items,
        'addressId': addressId,
        'paymentType': paymentType,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<dynamic> checkout(String cartId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/zomato/checkout'),
      headers: await _getHeaders(),
      body: jsonEncode({'cartId': cartId}),
    );
    return jsonDecode(response.body);
  }
}
