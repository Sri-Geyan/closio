import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final _usernameController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _bioController = TextEditingController();
  String _email = '';
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  XFile? _newImageFile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = await ApiService.getUserProfile();
      final supabaseUser = AuthService.supabase.auth.currentUser;
      
      setState(() {
        _usernameController.text = user['username'] ?? '';
        _upiIdController.text = user['upiId'] ?? '';
        _bioController.text = user['bio'] ?? '';
        _avatarUrl = user['avatarUrl'];
        _email = supabaseUser?.email ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newImageFile = pickedFile;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_usernameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    
    try {
      String? updatedAvatarUrl = _avatarUrl;
      
      if (_newImageFile != null) {
        final file = File(_newImageFile!.path);
        final fileExt = _newImageFile!.path.split('.').last;
        final fileName = '${DateTime.now().toIso8601String()}_avatar.$fileExt';
        
        await Supabase.instance.client.storage
            .from('images')
            .upload(fileName, file);
            
        updatedAvatarUrl = Supabase.instance.client.storage
            .from('images')
            .getPublicUrl(fileName);
      }

      await ApiService.syncUser(
        _usernameController.text.trim(),
        avatarUrl: updatedAvatarUrl,
        upiId: _upiIdController.text.trim().isNotEmpty ? _upiIdController.text.trim() : null,
        bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
        Navigator.pop(context, true); // Return true to signal refresh needed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Account Details'),
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: ClosioTheme.surfaceContainer,
                      backgroundImage: _newImageFile != null 
                          ? FileImage(File(_newImageFile!.path)) 
                          : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null) as ImageProvider?,
                      child: _newImageFile == null && _avatarUrl == null
                          ? const Icon(Icons.add_a_photo, size: 32, color: ClosioTheme.secondaryColor)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _pickImage,
                    child: const Text('Change Photo'),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _upiIdController,
                    decoration: const InputDecoration(
                      labelText: 'UPI ID',
                      prefixIcon: Icon(Icons.payment),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bioController,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(text: _email),
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      child: _isSaving 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
