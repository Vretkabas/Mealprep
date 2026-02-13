import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Controllers voor de tekstvelden
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(); 
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalController = TextEditingController();
  final _activityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  // 1. Data ophalen uit Supabase
  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        _emailController.text = user.email ?? '';

        // Haal data uit de 'profiles' tabel
        final data = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data != null) {
          _nameController.text = data['full_name'] ?? '';
          _ageController.text = data['age']?.toString() ?? '';
          _genderController.text = data['gender'] ?? '';
          _heightController.text = data['height']?.toString() ?? '';
          _weightController.text = data['weight']?.toString() ?? '';
          _goalController.text = data['goal'] ?? '';
          _activityController.text = data['activity_level'] ?? '';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Fout bij laden: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Data opslaan in Supabase (Inclusief Email Update)
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // --- A. Email Wijzigen in Auth ---
      if (_emailController.text.trim() != user.email) {
        // Update de email in de Supabase Auth tabel
        await supabase.auth.updateUser(
          UserAttributes(email: _emailController.text.trim()),
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bevestig je nieuwe e-mailadres via de link in je inbox!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // --- B. Profielgegevens Wijzigen in Database ---
      final updates = {
        'id': user.id, 
        'full_name': _nameController.text,
        'age': int.tryParse(_ageController.text),
        'gender': _genderController.text,
        'height': double.tryParse(_heightController.text),
        'weight': double.tryParse(_weightController.text),
        'goal': _goalController.text,
        'activity_level': _activityController.text,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert = Update als het bestaat, Insert als het nieuw is
      await supabase.from('profiles').upsert(updates);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Opslaan mislukt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. Popup tonen bij succes
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        title: const Text("Success"),
        content: const Text("Your changes have been saved successfully!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Sluit popup
              Navigator.of(context).pop(); // Ga terug naar Profile Page
            },
            child: const Text("OK", style: TextStyle(color: Color(0xFF1B8C61))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B8C61)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TABS ---
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildTab("Profile", true),
                        _buildTab("Nutrition", false),
                        _buildTab("Other", false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // --- AVATAR ---
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blueAccent, width: 2),
                          ),
                          child: const Icon(Icons.person, size: 50, color: Colors.blueAccent),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _nameController.text.isNotEmpty ? _nameController.text : "User",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // --- FORM FIELDS ---
                  const Text("Basic Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),

                  _buildLabel("Name"),
                  _buildTextField(_nameController, "John"),
                  
                  _buildLabel("Email"),
                  // readOnly staat nu op FALSE zodat je de mail kunt aanpassen
                  _buildTextField(_emailController, "email@example.com", readOnly: false),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Age"),
                            _buildTextField(_ageController, "20", isNumber: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Gender"),
                            _buildTextField(_genderController, "Male"),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text("Body Measurements", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Height (cm)"),
                            _buildTextField(_heightController, "180", isNumber: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Weight (kg)"),
                            _buildTextField(_weightController, "75", isNumber: true),
                          ],
                        ),
                      ),
                    ],
                  ),

                  _buildLabel("Goal"),
                  _buildTextField(_goalController, "Lose Weight"),

                  _buildLabel("Activity Level"),
                  _buildTextField(_activityController, "Moderate Active"),

                  const SizedBox(height: 30),

                  // --- SAVE BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B8C61),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildTab(String title, bool isActive) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: isActive
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
              )
            : null,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF1B8C61) : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool readOnly = false, bool isNumber = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: readOnly ? [] : [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
        ],
        border: readOnly ? Border.all(color: Colors.transparent) : null,
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: InputBorder.none,
        ),
      ),
    );
  }
}