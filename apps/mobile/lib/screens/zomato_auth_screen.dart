import 'package:flutter/material.dart';
import '../services/zomato_service.dart';
import 'zomato_search_screen.dart';

class ZomatoAuthScreen extends StatefulWidget {
  @override
  _ZomatoAuthScreenState createState() => _ZomatoAuthScreenState();
}

class _ZomatoAuthScreenState extends State<ZomatoAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final ZomatoService _zomatoService = ZomatoService();
  
  bool _isLoading = false;
  bool _codeSent = false;
  String? _stateId;

  Future<void> _sendCode() async {
    setState(() => _isLoading = true);
    try {
      final res = await _zomatoService.bindNumber(_phoneController.text);
      if (res['state_id'] != null || res['status'] == 'code_sent') {
        setState(() {
          _codeSent = true;
          _stateId = res['state_id'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Failed to send code.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _verifyCode() async {
    setState(() => _isLoading = true);
    try {
      final res = await _zomatoService.verifyCode(_codeController.text, _stateId ?? '');
      if (res['status'] == 'success') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ZomatoSearchScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Invalid code.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Connect Zomato')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!_codeSent) ...[
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: 'Phone Number (e.g., +91...)'),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendCode,
                child: _isLoading ? CircularProgressIndicator() : Text('Send Code'),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                decoration: InputDecoration(labelText: 'Verification Code'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyCode,
                child: _isLoading ? CircularProgressIndicator() : Text('Verify & Continue'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
