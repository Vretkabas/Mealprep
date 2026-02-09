// this file will save the data for the quick setup process, 
// such as the selected meals and the number of servings of all 4 pages and send to endpoint

class QuickSetupData {
  int? goal;            // 0=Lose, 1=Maintain, 2=Gain
  int? personsCount;
  int? age;
  int? height;
  double? weightCurrent;
  double? weightTarget;
  String? gender;
  String? activityLevel;
  List<String>? allergies;

  // convert to JSON for sending to backend
  Map<String, dynamic> toJson() {
    return {
      'goal': goal == 0 ? 'lose' : goal == 1 ? 'maintain' : 'gain',
      'personsCount': personsCount,
      'age': age,
      'height': height,
      'weightCurrent': weightCurrent,
      'weightTarget': weightTarget,
      'gender': gender,
      'activityLevel': activityLevel,
      'allergies': allergies,
    };
  }
}