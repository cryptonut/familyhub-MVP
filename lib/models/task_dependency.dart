class TaskDependency {
  final String id;
  final String taskId;
  final String dependsOnTaskId;
  final DependencyType type;

  TaskDependency({
    required this.id,
    required this.taskId,
    required this.dependsOnTaskId,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskId': taskId,
        'dependsOnTaskId': dependsOnTaskId,
        'type': type.name,
      };

  factory TaskDependency.fromJson(Map<String, dynamic> json) {
    return TaskDependency(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      dependsOnTaskId: json['dependsOnTaskId'] as String,
      type: DependencyType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DependencyType.hard,
      ),
    );
  }
}

enum DependencyType {
  hard, // Task cannot start until dependency complete
  soft, // Task can start but dependency recommended
}

enum TaskStatus {
  pending,
  blocked,
  inProgress,
  completed,
}

