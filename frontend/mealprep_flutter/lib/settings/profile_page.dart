import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _avatarUrl;
  String _email = 'Loading...';
  String _displayName = 'User';
  
  // Standaard taal instellen
  String _currentLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _getProfile();
  }

Future<void> _getProfile() async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  setState(() {
    _email = user.email ?? 'Geen email';
    _avatarUrl = user.userMetadata?['avatar_url'];
    _displayName = user.userMetadata?['username'] ??
                   user.email?.split('@')[0] ??
                   'User';
    _isLoading = false;
  });
}

  // --- TAAL SELECTIE LOGICA ---
  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Language",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              _buildLanguageOption("English", "🇬🇧"),
              _buildLanguageOption("Nederlands", "🇳🇱"),
              _buildLanguageOption("Français", "🇫🇷"),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String language, String flag) {
    bool isSelected = _currentLanguage == language;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        language,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blueAccent : Colors.black,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
      onTap: () {
        setState(() {
          _currentLanguage = language;
        });
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Taal gewijzigd naar $language'), duration: const Duration(seconds: 1)),
        );
      },
    );
  }

  Future<void> _uploadProfilePicture() async {
    //TODO: profile picture doesnt work
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final imageBytes = await image.readAsBytes();
      final String path = '/${user.id}/profile.jpg';

      await supabase.storage.from('avatars').uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl = supabase.storage.from('avatars').getPublicUrl(path);

      await supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': publicUrl}),
      );

      setState(() {
        _avatarUrl = publicUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload mislukt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij uitloggen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // navigate to profile settings page with initial index 0 (account tab) index is handled in edit_profile_page.dart
  void _navigateToProfileSettings() {
    Navigator.push(context, MaterialPageRoute(
    builder: (_) => const EditProfilePage(initialIndex: 0),
    ));
  }

  // navigate to diet preferences page with initial index 1 (diet & allergens tab) index is handled in edit_profile_page.dart
  void _navigateToDietPreferences() {
    Navigator.push(context, MaterialPageRoute(
    builder: (_) => const EditProfilePage(initialIndex: 1),
    ));
  }

  // same as above but with initial index 2 (other settings like delete, notifications, ..)
  void _navigateToOtherTab() {
    Navigator.push(context, MaterialPageRoute(
    builder: (_) => const EditProfilePage(initialIndex: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading && _email == 'Loading...'
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _uploadProfilePicture,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 3),
                            color: Colors.white,
                          ),
                          child: ClipOval(
                            child: _avatarUrl != null
                                ? Image.network(_avatarUrl!, fit: BoxFit.cover, key: ValueKey(_avatarUrl))
                                : const Icon(Icons.person, size: 80, color: Colors.grey),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(_displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(_email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 30),
                  
                  _buildSectionTitle("Account"),
                  _buildListTile(Icons.account_circle, "Profile Settings", hasArrow: true, onTap: _navigateToProfileSettings),
                  _buildListTile(Icons.lock, "Password", hasArrow: true, onTap: _navigateToOtherTab),
                  _buildListTile(Icons.delete, "Delete Account", hasArrow: true, onTap: _navigateToOtherTab),

                  const SizedBox(height: 20),
                  _buildSectionTitle("Preferences"),
                  _buildListTile(Icons.restaurant, "Diet & Allergens", hasArrow: true, onTap: _navigateToDietPreferences),
                  _buildListTile(Icons.favorite, "Health Goals", hasArrow: true, onTap: _navigateToDietPreferences),

                  const SizedBox(height: 20),
                  _buildSectionTitle("App Settings"),
                  _buildListTile(Icons.notifications, "Notifications", hasArrow: true , onTap: _navigateToOtherTab),
                  
                  // GEWIJZIGD: Language klikbaar gemaakt met subtitel voor huidige taal
                  _buildListTile(
                    Icons.language, 
                    "Language", 
                    subtitle: _currentLanguage, // Toon geselecteerde taal
                    hasArrow: true, 
                    onTap: _showLanguagePicker
                  ),
                  
                  _buildListTile(Icons.privacy_tip, "Privacy", hasArrow: true),
                  
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton(
                      onPressed: _signOut,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        foregroundColor: Colors.red,
                      ),
                      child: const Text("Logout", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 5),
        child: Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, {String? subtitle, bool hasArrow = false, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.blueAccent)) : null,
        trailing: hasArrow ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey) : null,
        onTap: onTap,
      ),
    );
  }
}