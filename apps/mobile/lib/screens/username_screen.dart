import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'main_layout.dart';

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final _usernameController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;
  XFile? _imageFile;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  void _submit() async {
    if (_usernameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      String? avatarUrl;
      if (_imageFile != null) {
        final file = File(_imageFile!.path);
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '${DateTime.now().toIso8601String()}_avatar.$fileExt';
        
        await Supabase.instance.client.storage
            .from('images')
            .upload(fileName, file);
            
        avatarUrl = Supabase.instance.client.storage
            .from('images')
            .getPublicUrl(fileName);
      }

      await AuthService.syncUserWithBackend(
        username: _usernameController.text.trim(),
        avatarUrl: avatarUrl,
        upiId: _upiIdController.text.trim().isNotEmpty ? _upiIdController.text.trim() : null,
        bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Set up profile',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: ClosioTheme.surfaceContainer,
                backgroundImage: _imageFile != null ? FileImage(File(_imageFile!.path)) : null,
                child: _imageFile == null 
                    ? const Icon(Icons.add_a_photo, size: 32, color: ClosioTheme.secondaryColor)
                    : null,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                hintText: 'Choose a username',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _upiIdController,
              decoration: const InputDecoration(
                hintText: 'UPI ID (Optional)',
                prefixIcon: Icon(Icons.payment),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(
                hintText: 'Bio (Optional)',
                prefixIcon: Icon(Icons.info_outline),
              ),
              maxLines: 3,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: ClosioTheme.backgroundColor) 
                  : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
