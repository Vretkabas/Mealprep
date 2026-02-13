import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'edit_profile_page.dart'; // Zorg dat dit bestand bestaat

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

  @override
  void initState() {
    super.initState();
    _getProfile();
  }

  // 1. Data ophalen van de huidige ingelogde user
  Future<void> _getProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Haal extra profielgegevens op (zoals naam) uit de 'profiles' tabel
        final profileData = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
            
        setState(() {
          _email = user.email ?? 'Geen email';
          // Eerst metadata checken, dan profile table, dan fallback op email
          _avatarUrl = user.userMetadata?['avatar_url'];
          _displayName = profileData?['full_name'] ?? 
                         user.userMetadata?['full_name'] ?? 
                         user.email?.split('@')[0] ?? 
                         'User';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij laden profiel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Foto uploaden naar Supabase Storage
  Future<void> _uploadProfilePicture() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return; // Gebruiker heeft geannuleerd

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final imageBytes = await image.readAsBytes();
      final String path = '/${user.id}/profile.jpg'; // Uniek pad per user

      // Upload naar de 'avatars' bucket
      await supabase.storage.from('avatars').uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(upsert: true), // Overschrijf oude foto
          );

      // Haal de publieke URL op
      final String publicUrl =
          supabase.storage.from('avatars').getPublicUrl(path);

      // Update de user metadata met de nieuwe URL
      await supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': publicUrl}),
      );

      setState(() {
        _avatarUrl = publicUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profielfoto bijgewerkt!')),
        );
      }
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

  // 3. Uitloggen en terug naar Login scherm
  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signOut();
      
      if (mounted) {
        // Navigeer terug naar login en verwijder alle eerdere routes
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Lichte achtergrond
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading && _email == 'Loading...'
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // --- AVATAR SECTIE ---
                  GestureDetector(
                    onTap: _uploadProfilePicture, // Klikken = uploaden
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
                                ? Image.network(
                                    _avatarUrl!,
                                    fit: BoxFit.cover,
                                    // Hack om te zorgen dat afbeelding ververst
                                    key: ValueKey(_avatarUrl), 
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.person, size: 60, color: Colors.grey),
                                  )
                                : const Icon(Icons.person, size: 80, color: Colors.grey),
                          ),
                        ),
                        // Edit icoontje
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // --- NAAM / EMAIL ---
                  Text(
                    _displayName, 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _email,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),

                  const SizedBox(height: 30),

                  // --- MENU ITEMS ---
                  // Account
                  _buildSectionTitle("Account"),
                  
                  // Aangepaste Email Navigatie
                  _buildListTile(
                    Icons.email, 
                    "Email", 
                    hasArrow: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditProfilePage()),
                      ).then((_) {
                        // Ververs data als we terugkomen
                        _getProfile(); 
                      });
                    },
                  ),
                  
                  _buildListTile(Icons.lock, "Password", hasArrow: true),
                  _buildListTile(Icons.delete, "Delete Account", hasArrow: true),

                  const SizedBox(height: 20),

                  // Preferences
                  _buildSectionTitle("Preferences"),
                  _buildListTile(Icons.restaurant, "Diet & Allergens", hasArrow: true),
                  _buildListTile(Icons.favorite, "Health Goals", hasArrow: true),
                  _buildListTile(Icons.attach_money, "Budget", hasArrow: true),

                  const SizedBox(height: 20),

                  // App Settings
                  _buildSectionTitle("App Settings"),
                  _buildListTile(Icons.notifications, "Notifications", hasArrow: true),
                  _buildListTile(Icons.language, "Language", hasArrow: true),
                  _buildListTile(Icons.privacy_tip, "Privacy", hasArrow: true),
                  
                  const SizedBox(height: 20),

                  // Analytics
                  _buildSectionTitle("Analytics"),
                  _buildListTile(Icons.bar_chart, "View Stats", hasArrow: true),

                  const SizedBox(height: 40),

                  // --- LOGOUT KNOP ---
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
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.red) 
                        : const Text("Logout", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // Helper Widget voor sectie titels
  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 5),
        child: Text(
          title,
          style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  // Helper Widget voor de lijst items
  Widget _buildListTile(IconData icon, String title, {bool hasArrow = false, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: hasArrow ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey) : null,
        onTap: onTap, // Hier wordt de actie uitgevoerd
      ),
    );
  }
}