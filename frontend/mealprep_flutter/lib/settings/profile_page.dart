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
  
  // Merk kleuren
  final Color brandGreen = const Color(0xFF00BFA5);
  final Color darkBlue = const Color(0xFF2C4A5E);

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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Language",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
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
          color: isSelected ? brandGreen : Colors.black87,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_circle, color: brandGreen) : null,
      onTap: () {
        setState(() {
          _currentLanguage = language;
        });
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Language changed to $language'),
            duration: const Duration(seconds: 1),
            backgroundColor: darkBlue,
          ),
        );
      },
    );
  }

  // --- PROFIELFOTO OPTIES MENU ---
  void _showProfilePictureOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_avatarUrl == null)
                ListTile(
                  leading: Icon(Icons.add_a_photo, color: brandGreen),
                  title: const Text("Add Profile Picture", style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _uploadProfilePicture();
                  },
                ),
              if (_avatarUrl != null)
                ListTile(
                  leading: Icon(Icons.photo_camera, color: brandGreen),
                  title: const Text("Update Profile Picture", style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _uploadProfilePicture();
                  },
                ),
              if (_avatarUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text("Delete Profile Picture", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteProfilePicture();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // --- PROFIELFOTO UPLOADEN ---
  Future<void> _uploadProfilePicture() async {
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
        _avatarUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- PROFIELFOTO VERWIJDEREN ---
  Future<void> _deleteProfilePicture() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final String path = '/${user.id}/profile.jpg';
      await supabase.storage.from('avatars').remove([path]);
      await supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': null}),
      );

      setState(() {
        _avatarUrl = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Profile picture successfully deleted'), backgroundColor: brandGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting profile picture: $e'), backgroundColor: Colors.redAccent),
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
          SnackBar(content: Text('Error signing out: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToProfileSettings() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const EditProfilePage(initialIndex: 0),
    ));
  }

  void _navigateToDietPreferences() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const EditProfilePage(initialIndex: 1),
    ));
  }

  void _navigateToOtherTab() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const EditProfilePage(initialIndex: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Neutrale lichte achtergrond
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading && _email == 'Loading...'
          ? Center(child: CircularProgressIndicator(color: brandGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  // --- PROFILE HEADER ---
                  GestureDetector(
                    onTap: _showProfilePictureOptions,
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: brandGreen.withOpacity(0.3), width: 3),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(color: brandGreen.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: ClipOval(
                            child: _avatarUrl != null
                                ? Image.network(_avatarUrl!, fit: BoxFit.cover, key: ValueKey(_avatarUrl))
                                : Icon(Icons.person, size: 60, color: Colors.grey.shade400),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: brandGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _displayName, 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email, 
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 40),

                  // --- MENU ITEMS ---
                  _buildSectionTitle("Account"),
                  _buildSectionContainer([
                    _buildListTile(Icons.person_outline, "Profile Settings", hasArrow: true, onTap: _navigateToProfileSettings),
                    _buildDivider(),
                    _buildListTile(Icons.lock_outline, "Password", hasArrow: true, onTap: _navigateToOtherTab),
                    _buildDivider(),
                    _buildListTile(Icons.delete_outline, "Delete Account", hasArrow: true, iconColor: Colors.redAccent, textColor: Colors.redAccent, onTap: _navigateToOtherTab),
                  ]),

                  const SizedBox(height: 24),
                  _buildSectionTitle("Preferences"),
                  _buildSectionContainer([
                    _buildListTile(Icons.restaurant_menu, "Diet & Allergens", hasArrow: true, onTap: _navigateToDietPreferences),
                    _buildDivider(),
                    _buildListTile(Icons.favorite_outline, "Health Goals", hasArrow: true, onTap: _navigateToDietPreferences),
                  ]),

                  const SizedBox(height: 24),
                  _buildSectionTitle("App Settings"),
                  _buildSectionContainer([
                    _buildListTile(Icons.notifications_none, "Notifications", hasArrow: true, onTap: _navigateToOtherTab),
                    _buildDivider(),
                    _buildListTile(
                      Icons.language, 
                      "Language", 
                      subtitle: _currentLanguage,
                      hasArrow: true, 
                      onTap: _showLanguagePicker
                    ),
                    _buildDivider(),
                    _buildListTile(Icons.shield_outlined, "Privacy", hasArrow: true),
                  ]),

                  const SizedBox(height: 40),
                  
                  // --- LOGOUT KNOP ---
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _signOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Logout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // Titel voor elke categorie (Account, Settings, etc.)
  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 8),
        child: Text(
          title.toUpperCase(), 
          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.2),
        ),
      ),
    );
  }

  // Witte kaart rondom een groep menu items (iOS stijl)
  Widget _buildSectionContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  // De divider tussen de opties in één blok
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 16),
      child: Divider(height: 1, color: Colors.grey.shade100, thickness: 1),
    );
  }

  // Het individuele lijst item, nu zonder eigen witte achtergrond
  Widget _buildListTile(IconData icon, String title, {String? subtitle, bool hasArrow = false, VoidCallback? onTap, Color? iconColor, Color? textColor}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20), // Voorkomt lelijke klik-hoeken
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? brandGreen).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor ?? brandGreen, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, 
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: textColor ?? Colors.black87),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
              if (hasArrow) 
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}