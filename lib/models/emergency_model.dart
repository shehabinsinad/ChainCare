class EmergencyModel {
  final String name;
  final String bloodGroup;
  final String allergies;
  final String chronicConditions;
  final String contactName;  // Changed from single string
  final String contactPhone; // Added phone
  final String notes;

  EmergencyModel({
    required this.name,
    required this.bloodGroup,
    required this.allergies,
    required this.chronicConditions,
    required this.contactName,
    required this.contactPhone,
    required this.notes,
  });

  factory EmergencyModel.fromMap(Map<String, dynamic> data) {
    return EmergencyModel(
      name: data['name'] ?? 'Unknown',
      bloodGroup: data['bloodGroup'] ?? 'Unknown',
      allergies: data['allergies'] ?? 'None',
      chronicConditions: data['conditions'] ?? 'None',
      // FIX: Map to the exact Firestore keys used in Profile Screen
      contactName: data['emergencyContactName'] ?? 'Not Listed',
      contactPhone: data['emergencyContactPhone'] ?? 'N/A',
      notes: data['notes'] ?? '',
    );
  }
}