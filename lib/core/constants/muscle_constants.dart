class MuscleConstants {
  static const List<String> generalMuscles = [
    'Piernas',
    'Brazos',
    'Pecho',
    'Espalda',
    'Hombros',
    'Abdomen',
  ];

  static const List<String> specificMuscles = [
    'Gemelos',
    'Cuádriceps',
    'Isquiosurales',
    'Abductores',
    'Aductores',
    'Glúteo',
    'Abdominales',
    'Deltoides anterior',
    'Deltoides lateral',
    'Deltoides posterior',
    'Pectoral',
    'Espalda',
    'Bíceps',
    'Tríceps',
  ];

  static const Map<String, List<String>> musclesByCategory = {
    'Piernas': [
      'Cuádriceps',
      'Isquiosurales',
      'Glúteo',
      'Gemelos',
      'Aductores',
      'Abductores',
    ],
    'Brazos': [
      'Bíceps',
      'Tríceps',
    ],
    'Hombros': [
      'Deltoides anterior',
      'Deltoides lateral',
      'Deltoides posterior',
    ],
    'Pecho': [
      'Pectoral',
    ],
    'Espalda': [
      'Espalda',
    ],
    'Abdomen': [
      'Abdominales',
    ],
  };

  static const Map<String, String> specificToGeneral = {
    'Gemelos': 'Piernas',
    'Cuádriceps': 'Piernas',
    'Isquiosurales': 'Piernas',
    'Abductores': 'Piernas',
    'Aductores': 'Piernas',
    'Glúteo': 'Piernas',
    'Abdominales': 'Abdomen',
    'Deltoides anterior': 'Hombros',
    'Deltoides lateral': 'Hombros',
    'Deltoides posterior': 'Hombros',
    'Pectoral': 'Pecho',
    'Espalda': 'Espalda',
    'Bíceps': 'Brazos',
    'Tríceps': 'Brazos',
  };

  static String? getGeneralForSpecific(String specific) {
    return specificToGeneral[specific];
  }
}
