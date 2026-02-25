import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Zorg dat deze paden kloppen met jouw mappenstructuur
import '../screens/barcode_scanner_screen.dart';
import '../ShoppingList/shopping_list_page.dart';

class EditProfilePage extends StatefulWidget {
  final int initialIndex;
  const EditProfilePage({super.key, this.initialIndex = 0});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Huidige actieve tab in de instellingen (0 = Profile, 1 = Nutrition, 2 = Other)
  late int _selectedTabIndex;

  // --- NAVBAR LOGICA ---
  int _selectedIndex = 4; // 4 = Profile sectie
  final Color brandGreen = const Color(0xFF00BFA5); // Kleur overgenomen van home_page

  // --- CONTROLLERS PROFILE ---
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _peopleController = TextEditingController();
  String? _selectedGoal;
  String? _selectedActivity;
  String? _selectedGender;

  final List<Map<String, String>> _genderOptions = [
    {'value': 'Man', 'label': 'Male'},
    {'value': 'Vrouw', 'label': 'Female'},
    {'value': 'Other', 'label': 'Other'},
  ];

  final List<Map<String, String>> _goalOptions = [
    {'value': 'lose', 'label': 'Lose Weight'},
    {'value': 'maintain', 'label': 'Maintain Weight'},
    {'value': 'gain', 'label': 'Gain Weight'},
  ];

  final List<Map<String, String>> _activityOptions = [
    {'value': 'low', 'label': 'Low', 'subtitle': 'Almost no activity'},
    {'value': 'slightly_active', 'label': 'Slightly active', 'subtitle': '1-3 times sport a week'},
    {'value': 'medium', 'label': 'Medium', 'subtitle': '3-5 times sport a week'},
    {'value': 'very_active', 'label': 'Very active', 'subtitle': '6-7 times sport a week'},
  ];

  // --- NUTRITION STATE ---
  int _dailyCalories = 2000;
  double _carbPct = 50;
  double _proteinPct = 30;
  double _fatPct = 20;
  double get _totalMacro => _carbPct + _proteinPct + _fatPct;

  final List<String> _selectedRestrictions = [];
  final List<Map<String, dynamic>> _restrictionOptions = [
    {'label': 'Nuts', 'icon': '🥜', 'type': 'allergen'},
    {'label': 'Gluten', 'icon': '🌾', 'type': 'allergen'},
    {'label': 'Lactose', 'icon': '🥛', 'type': 'allergen'},
    {'label': 'Fish', 'icon': '🐟', 'type': 'allergen'},
    {'label': 'Vegetarian', 'icon': '🌱', 'type': 'diet'},
    {'label': 'Vegan', 'icon': '🌿', 'type': 'diet'},
  ];

  // --- VARIABLES OTHER (Notifications) ---
  bool _mealReminders = true;
  bool _weeklyProgress = true;
  bool _shoppingList = false;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialIndex;
    _loadAllData();

    // Listeners om calorieën bij te werken als profieldata verandert
    _ageController.addListener(_calculateDailyCalories);
    _heightController.addListener(_calculateDailyCalories);
    _weightController.addListener(_calculateDailyCalories);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  // --- LOGICA: CALORIE BEREKENING ---
  void _calculateDailyCalories() {
    final double? weight = double.tryParse(_weightController.text);
    final double? height = double.tryParse(_heightController.text);
    final int? age = int.tryParse(_ageController.text);
    if (weight == null || height == null || age == null) return;

    double bmr;
    if (_selectedGender == 'Man') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

    double multiplier = 1.2;
    if (_selectedActivity == 'slightly_active') multiplier = 1.375;
    if (_selectedActivity == 'medium') multiplier = 1.55;
    if (_selectedActivity == 'very_active') multiplier = 1.725;

    double tdee = bmr * multiplier;
    int finalCals = tdee.round();

    if (_selectedGoal == 'lose') finalCals -= 500;
    if (_selectedGoal == 'gain') finalCals += 300;

    setState(() => _dailyCalories = finalCals);
  }

  // --- 1. DATA LADEN (SUPABASE) ---
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Alles in 1 call uit user_settings
      final data = await supabase.from('user_settings').select().eq('user_id', user.id).maybeSingle();

      // Email + naam altijd uit auth (staat niet in user_settings)
      _nameController.text = user.userMetadata?['username'] ??
                             user.userMetadata?['full_name'] ??
                             user.email?.split('@')[0] ??
                             'User';
      _emailController.text = user.email ?? '';

      if (data != null) {
        _ageController.text = data['age']?.toString() ?? '0';
        _peopleController.text = data['persons_count']?.toString() ?? '2';
        _selectedGender = data['gender'];
        _heightController.text = data['height']?.toString() ?? '';
        _weightController.text = data['weight_current']?.toString() ?? '';
        _selectedGoal = data['goal'];
        _selectedActivity = data['activity_level'];

        setState(() {
          _dailyCalories = data['daily_calorie_target'] ?? 2000;
          _carbPct = (data['carb_percentage'] ?? 50).toDouble();
          _proteinPct = (data['protein_percentage'] ?? 30).toDouble();
          _fatPct = (data['fat_percentage'] ?? 20).toDouble();

          _selectedRestrictions.clear();
          if (data['allergens'] != null) {
            _selectedRestrictions.addAll(List<String>.from(data['allergens']));
          }
          if (data['dietary_type'] != null) {
            _selectedRestrictions.add(data['dietary_type']);
          }
        });
      }
      _calculateDailyCalories();
    } catch (e) {
      debugPrint('Fout bij laden: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. DATA OPSLAAN ---
  Future<void> _saveChanges() async {
    if (_selectedTabIndex == 1 && _totalMacro.toInt() != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Macro distribution must total exactly 100%.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // A. Update username in auth metadata
      await supabase.auth.updateUser(
        UserAttributes(data: {'username': _nameController.text.trim()}),
      );

      // B. Update user_settings (profiel + body data)
      final int people = (int.tryParse(_peopleController.text) ?? 2).clamp(1, 30);
      await supabase.from('user_settings').upsert({
        'user_id': user.id,
        'age': int.tryParse(_ageController.text),
        'gender': _selectedGender,
        'height': double.tryParse(_heightController.text),
        'weight_current': double.tryParse(_weightController.text),
        'goal': _selectedGoal,
        'activity_level': _selectedActivity,
        'persons_count': people,
      }, onConflict: 'user_id');

      // C. Update user_settings (Nutrition)
      List<String> allergens = [];
      String? dietaryType;
      for (var item in _selectedRestrictions) {
        final opt = _restrictionOptions.firstWhere((o) => o['label'] == item, orElse: () => {});
        if (opt['type'] == 'allergen') allergens.add(item);
        if (opt['type'] == 'diet') dietaryType = item;
      }

      await supabase.from('user_settings').upsert({
        'user_id': user.id,
        'daily_calorie_target': _dailyCalories,
        'carb_percentage': _carbPct.toInt(),
        'protein_percentage': _proteinPct.toInt(),
        'fat_percentage': _fatPct.toInt(),
        'allergens': allergens,
        'dietary_type': dietaryType,
      }, onConflict: 'user_id');

      if (mounted) _showSuccessDialog("Saved", "All your changes have been successfully saved.");
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // account actions
  Future<void> _changePassword() async {
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "New password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Confirm password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (newPassController.text != confirmPassController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Passwords don't match")),
                );
                return;
              }
              if (newPassController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password must be at least 6 characters")),
                );
                return;
              }
              try {
                await supabase.auth.updateUser(
                  UserAttributes(password: newPassController.text),
                );
                if (mounted) {
                  Navigator.pop(context);
                  _showSuccessDialog("Password Updated", "Your password has been changed successfully.");
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              }
            },
            child: const Text("Save", style: TextStyle(color: Color(0xFF1B8C61), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    newPassController.dispose();
    confirmPassController.dispose();
  }

  Future<void> _logOut() async {
    await supabase.auth.signOut();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _deleteAccount() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text("Are you sure? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;
    try {
      await supabase.rpc('delete_user_account'); 
      await supabase.auth.signOut();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK", style: TextStyle(color: Color(0xFF1B8C61), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- NAVBAR NAVIGATIE ACTIE ---
  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // Doe niets als we al op deze tab zijn

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home');
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListsPage()));
        break;
      case 3:
        print("Navigeer naar Favorites");
        // Navigator.pushNamed(context, '/favorites'); // Voeg toe als je de route hebt
        break;
      case 4:
        // We zijn al op de Profile / Settings pagina
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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
          : Column(
              children: [
                // --- TABS ---
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        _buildTab("Profile", 0),
                        _buildTab("Nutrition", 1),
                        _buildTab("Other", 2),
                      ],
                    ),
                  ),
                ),
                
                // --- CONTENT ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: _buildTabContent(),
                  ),
                ),

                // --- SAVE BUTTON ---
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B8C61),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            
      // --- BOTTOM NAVIGATION BAR (Overgenomen van Home) ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: brandGreen,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt_outlined), label: "Scan"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Lists"),
          BottomNavigationBarItem(icon: Icon(Icons.star_border), label: "Favorites"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0: return _buildProfileTab();
      case 1: return _buildNutritionTab();
      case 2: return _buildOtherTab();
      default: return Container();
    }
  }

  // --- TAB 1: PROFILE ---
  Widget _buildProfileTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF1B8C61), width: 2)),
                child: const Icon(Icons.person, size: 50, color: Color(0xFF1B8C61)),
              ),
              const SizedBox(height: 10),
              Text(_nameController.text.isNotEmpty ? _nameController.text : "User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ),
        const SizedBox(height: 25),
        const Align(alignment: Alignment.centerLeft, child: Text("Basic Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        const SizedBox(height: 15),
        _buildLabel("Name"),
        _buildTextField(_nameController, "Name"),
        _buildLabel("Email"),
        _buildTextField(_emailController, "Email", readOnly: true),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel("Age"), _buildTextField(_ageController, "20", isNumber: true)])),
          const SizedBox(width: 15),
          Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Gender"),
        _buildDropdown(
          value: _selectedGender,
          hint: "Gender",
          items: _genderOptions.map((o) => DropdownMenuItem(
            value: o['value'],
            child: Text(o['label']!),
          )).toList(),
          onChanged: (val) => setState(() {
            _selectedGender = val;
            _calculateDailyCalories();
          }),
        ),
      ],
    ),
  ),
        ]),
        const SizedBox(height: 20),
        const Align(alignment: Alignment.centerLeft, child: Text("Body Measurements", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel("Height (cm)"), _buildTextField(_heightController, "180", isNumber: true)])),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel("Weight (kg)"), _buildTextField(_weightController, "75", isNumber: true)])),
        ]),
        _buildLabel("Goal"),
        _buildDropdown(
          value: _selectedGoal,
          hint: "Select your goal",
          items: _goalOptions.map((o) => DropdownMenuItem(
            value: o['value'],
            child: Text(o['label']!),
          )).toList(),
          onChanged: (val) => setState(() {
            _selectedGoal = val;
            _calculateDailyCalories();
          }),
        ),
        _buildLabel("Activity Level"),
        _buildDropdown(
          value: _selectedActivity,
          hint: "Select activity level",
          items: _activityOptions.map((o) => DropdownMenuItem(
            value: o['value'],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(o['label']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(o['subtitle']!, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          )).toList(),
          onChanged: (val) => setState(() {
            _selectedActivity = val;
            _calculateDailyCalories();
          }),
        ),
        _buildLabel( "People to cook for"),
        _buildTextField(_peopleController, "2", isNumber: true),
      ],
    );
  }

  // --- TAB 2: NUTRITION ---
  Widget _buildNutritionTab() {
    bool isInvalid = _totalMacro.toInt() != 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Dynamic Calorie Goal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Text("Automatically calculated from your profile", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 15),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(15)),
          child: Column(children: [
            Text("$_dailyCalories", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const Text("kcal per day", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 30),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Macro Distribution", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text("${_totalMacro.toInt()}%", style: TextStyle(color: isInvalid ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
        ]),
        _buildMacroSlider("Carbs", Colors.blue, _carbPct, (val) => setState(() => _carbPct = val)),
        _buildMacroSlider("Protein", Colors.orange, _proteinPct, (val) => setState(() => _proteinPct = val)),
        _buildMacroSlider("Fats", Colors.red, _fatPct, (val) => setState(() => _fatPct = val)),
        const SizedBox(height: 30),
        const Text("Dietary Restrictions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 15),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: _restrictionOptions.length,
          itemBuilder: (context, index) {
            final option = _restrictionOptions[index];
            final isSelected = _selectedRestrictions.contains(option['label']);
            return GestureDetector(
              onTap: () => setState(() => isSelected ? _selectedRestrictions.remove(option['label']) : _selectedRestrictions.add(option['label'])),
              child: Container(
                decoration: BoxDecoration(color: isSelected ? const Color(0xFFA5D6A7) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? const Color(0xFF1B8C61) : Colors.grey.shade300, width: isSelected ? 2 : 1)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(option['icon'], style: const TextStyle(fontSize: 18)), const SizedBox(width: 8), Text(option['label'], style: const TextStyle(fontWeight: FontWeight.bold))]),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- TAB 3: OTHER ---
  Widget _buildOtherTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 15),
        _buildSwitchTile("Meal Reminders", "Get notified when it's time to eat", _mealReminders, (val) => setState(() => _mealReminders = val)),
        _buildSwitchTile("Weekly Progress", "Weekly summary of your nutrition", _weeklyProgress, (val) => setState(() => _weeklyProgress = val)),
        _buildSwitchTile("Shopping List", "Reminder to check your shopping list", _shoppingList, (val) => setState(() => _shoppingList = val)),
        const SizedBox(height: 30),
        const Text("Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 15),
        _buildAccountTile(Icons.lock_outline, "Change Password", _changePassword),
        _buildAccountTile(Icons.logout, "Log Out", _logOut, isDestructive: true),
        _buildAccountTile(Icons.delete_outline, "Delete Account", _deleteAccount, isDestructive: true),
      ],
    );
  }

  // --- HELPERS ---
  Widget _buildTab(String title, int index) {
    bool isActive = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: isActive ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]) : null,
          child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF1B8C61) : Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildMacroSlider(String label, Color color, double value, Function(double) onChanged) {
    return Column(children: [
      Row(children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text("${value.toInt()}%", style: TextStyle(color: color, fontWeight: FontWeight.bold))]),
      Slider(value: value, min: 0, max: 100, divisions: 100, activeColor: color, onChanged: onChanged),
    ]);
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
      child: SwitchListTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)), value: value, activeColor: const Color(0xFF1B8C61), onChanged: onChanged),
    );
  }

  Widget _buildAccountTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: ListTile(leading: Icon(icon, color: isDestructive ? Colors.red : Colors.black), title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDestructive ? Colors.red : Colors.black)), trailing: const Icon(Icons.arrow_forward_ios, size: 14), onTap: onTap),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)));
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: Colors.grey[400])),
          isExpanded: true,
          itemHeight: 56,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool readOnly = false, bool isNumber = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(color: readOnly ? Colors.grey[100] : Colors.white, borderRadius: BorderRadius.circular(15), border: readOnly ? Border.all(color: Colors.grey.shade300) : null, boxShadow: readOnly ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), border: InputBorder.none),
      ),
    );
  }
}