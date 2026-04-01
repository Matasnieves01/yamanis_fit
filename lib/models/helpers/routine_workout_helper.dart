class RoutineWorkout {
  String workoutId;  String workoutName;
  String reps;
  String sets;
  String weight;

  RoutineWorkout({
    required this.workoutId,
    required this.workoutName,
    this.reps = '',
    this.sets = '',
    this.weight = '',
  });
}