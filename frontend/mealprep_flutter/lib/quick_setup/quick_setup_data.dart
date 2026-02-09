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
  // keys must match backend Pydantic model (snake_case)
  Map<String, dynamic> toJson() {
    return {
      'goal': goal == 0 ? 'lose' : goal == 1 ? 'maintain' : 'gain',
      'persons_count': personsCount,
      'age': age,
      'height': height,
      'weight_current': weightCurrent,
      'weight_target': weightTarget,
      'gender': gender,
      'activity_level': activityLevel,
      'allergies': allergies,
    };
  }
}
