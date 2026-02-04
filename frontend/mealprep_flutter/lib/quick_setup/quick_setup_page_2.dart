import 'package:flutter/material.dart';

class QuickSetupPage2 extends StatefulWidget {
  const QuickSetupPage2({super.key});

  @override
  State<QuickSetupPage2> createState() => _QuickSetupPage2State();
}

class _QuickSetupPage2State extends State<QuickSetupPage2> {
  // Form controllers & waarden
  final _formKey = GlobalKey<FormState>();
  
  // Standaardwaarden (kunnen null zijn als ze nog niet ingevuld zijn)
  int? _age;
  int? _height;
  double? _currentWeight;
  double? _desiredWeight;
  int _personCount = 1; // Default 1 persoon
  String _selectedGender = ''; // 'Man', 'Woman', 'Prefer not to say'
  
  // GDPR Consent State
  bool _gdprConsent = false;
  bool _showGdprError = false;

  // Hulpfunctie om lijsten te genereren voor dropdowns
  List<int> _generateRange(int start, int end) {
    return List<int>.generate(end - start + 1, (i) => start + i);
  }

  void _goToNextPage() {
    setState(() {
      _showGdprError = !_gdprConsent;
    });

    if (_formKey.currentState!.validate() && _selectedGender.isNotEmpty && _gdprConsent) {
      _formKey.currentState!.save();
      
      // Hier zou je de data opslaan in Riverpod/Supabase
      print("Opslaan: Leeftijd: $_age, Lengte: $_height, Personen: $_personCount");
      print("GDPR Consent gegeven: $_gdprConsent");

      // Navigeer naar volgende pagina (bv. Allergieën of Dieetvoorkeur)
      // Navigator.pushNamed(context, '/quick_setup_3'); 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data opgeslagen & naar volgende stap...")),
      );
    } else if (_selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecteer aub je geslacht.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kleuren uit je design
    final Color brandGreen = const Color(0xFF00BFA5); 
    final Color backgroundGrey = const Color(0xFFF5F7F9);
    final Color textDark = const Color(0xFF345069);

    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Progress Bar (Stap 2 van X)
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.5, // We zijn op stap 2 (ongeveer de helft of 1/3)
                    child: Container(
                      decoration: BoxDecoration(
                        color: brandGreen,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                Text(
                  "Personal Info",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 10),
                // Icoon placeholder zoals in screenshot
                Icon(Icons.person, size: 80, color: textDark.withOpacity(0.5)),
                const SizedBox(height: 30),

                // ============================================
                // NIEUW: Voor hoeveel personen koken?
                // ============================================
                _buildLabel("Voor hoeveel personen wil je koken?", textDark),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _personCount,
                      isExpanded: true,
                      items: [1, 2, 3, 4, 5, 6, 7, 8].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text("$value ${value == 1 ? 'persoon' : 'personen'}"),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _personCount = val!),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ============================================
                // Inputs (Age, Height, Weight)
                // ============================================
                // Age
                _buildLabel("Age", textDark),
                const SizedBox(height: 8),
                _buildDropdownField<int>(
                  value: _age,
                  items: _generateRange(16, 99),
                  hint: "Select age",
                  onChanged: (val) => setState(() => _age = val),
                ),

                const SizedBox(height: 16),

                // Height
                _buildLabel("Height (cm)", textDark),
                const SizedBox(height: 8),
                _buildDropdownField<int>(
                  value: _height,
                  items: _generateRange(140, 230),
                  hint: "Select height",
                  onChanged: (val) => setState(() => _height = val),
                ),

                const SizedBox(height: 16),

                // Current Weight (Text Input is vaak fijner voor gewicht dan dropdown)
                _buildLabel("Current weight (kg)", textDark),
                const SizedBox(height: 8),
                _buildNumberInput(
                  hint: "80", 
                  onSaved: (val) => _currentWeight = double.tryParse(val ?? ''),
                ),

                const SizedBox(height: 16),

                // Desired Weight
                _buildLabel("Desired weight (kg)", textDark),
                const SizedBox(height: 8),
                _buildNumberInput(
                  hint: "75", 
                  onSaved: (val) => _desiredWeight = double.tryParse(val ?? ''),
                ),

                const SizedBox(height: 30),

                // ============================================
                // Gender Selection
                // ============================================
                _buildLabel("Gender", textDark),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGenderCard("Man", Icons.face, _selectedGender == "Man"),
                    _buildGenderCard("Woman", Icons.face_3, _selectedGender == "Woman"),
                    _buildGenderCard("Other", Icons.question_mark, _selectedGender == "Prefer not to say"),
                  ],
                ),

                const SizedBox(height: 30),

                // ============================================
                // GDPR / MEDICAL CONSENT (CRUCIAAL)
                // ============================================
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _showGdprError ? Colors.red.withOpacity(0.1) : Colors.white,
                    border: Border.all(
                      color: _showGdprError ? Colors.red : Colors.transparent
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text(
                          "Ik geef toestemming voor het verwerken van mijn gezondheidsgegevens (gewicht, lengte, leeftijd) om een passend voedingsschema te genereren.",
                          style: TextStyle(fontSize: 12),
                        ),
                        subtitle: const Text(
                          "Je gegevens worden veilig opgeslagen en alleen hiervoor gebruikt.",
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        activeColor: brandGreen,
                        value: _gdprConsent,
                        onChanged: (val) {
                          setState(() {
                            _gdprConsent = val ?? false;
                            _showGdprError = false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_showGdprError)
                        const Padding(
                          padding: EdgeInsets.only(left: 10, bottom: 5),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Toestemming is verplicht voor deze app.",
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ============================================
                // Next Button
                // ============================================
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _goToNextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 3,
                    ),
                    child: const Text(
                      "Next",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widgets
  Widget _buildLabel(String text, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildDropdownField<T>({required T? value, required List<T> items, required String hint, required Function(T?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item.toString()))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildNumberInput({required String hint, required Function(String?) onSaved}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: TextFormField(
        keyboardType: TextInputType.number,
        decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: const TextStyle(color: Colors.grey)),
        onSaved: onSaved,
        validator: (val) => (val == null || val.isEmpty) ? 'Verplicht' : null,
      ),
    );
  }

  Widget _buildGenderCard(String label, IconData icon, bool isSelected) {
    final Color brandGreen = const Color(0xFF00BFA5);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = label == "Other" ? "Prefer not to say" : label;
        });
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: isSelected ? brandGreen.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? brandGreen : Colors.transparent, width: 2),
          boxShadow: [
             if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: isSelected ? brandGreen : Colors.grey),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: isSelected ? brandGreen : Colors.grey, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}