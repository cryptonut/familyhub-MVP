import 'package:flutter/material.dart';
import '../../models/lesson_plan.dart' show LessonPlan, LessonStatus;
import '../../services/homeschooling_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'create_edit_lesson_plan_screen.dart';

/// Screen for managing lesson plans in a homeschooling hub
class LessonPlanningScreen extends StatefulWidget {
  final String hubId;

  const LessonPlanningScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<LessonPlanningScreen> createState() => _LessonPlanningScreenState();
}

class _LessonPlanningScreenState extends State<LessonPlanningScreen> {
  final HomeschoolingService _service = HomeschoolingService();
  List<LessonPlan> _lessonPlans = [];
  String? _selectedSubject;
  bool _isLoading = true;

  final List<String> _availableSubjects = [
    'Math',
    'Science',
    'English',
    'History',
    'Geography',
    'Art',
    'Music',
    'Physical Education',
    'Foreign Language',
    'Computer Science',
  ];

  @override
  void initState() {
    super.initState();
    _loadLessonPlans();
  }

  Future<void> _loadLessonPlans() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final plans = await _service.getLessonPlans(
        hubId: widget.hubId,
        subject: _selectedSubject,
      );

      if (mounted) {
        setState(() {
          _lessonPlans = List<LessonPlan>.from(plans);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lesson plans: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not scheduled';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Plans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateEditLessonPlanScreen(
                    hubId: widget.hubId,
                    availableSubjects: _availableSubjects,
                  ),
                ),
              );
              if (result == true) {
                _loadLessonPlans();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Subject filter
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            color: Theme.of(context).cardColor,
            child: DropdownButtonFormField<String?>(
              value: _selectedSubject,
              decoration: const InputDecoration(
                labelText: 'Filter by Subject',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Subjects'),
                ),
                ..._availableSubjects.map((subject) => DropdownMenuItem<String?>(
                      value: subject,
                      child: Text(subject),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedSubject = value;
                });
                _loadLessonPlans();
              },
            ),
          ),

          // Lesson plans list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _lessonPlans.isEmpty
                    ? EmptyState(
                        icon: Icons.book_outlined,
                        title: 'No Lesson Plans',
                        message: 'Create your first lesson plan',
                        action: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateEditLessonPlanScreen(
                                  hubId: widget.hubId,
                                  availableSubjects: _availableSubjects,
                                ),
                              ),
                            );
                            if (result == true) {
                              _loadLessonPlans();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Lesson Plan'),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLessonPlans,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.spacingMD),
                          itemCount: _lessonPlans.length,
                          itemBuilder: (context, index) {
                            final plan = _lessonPlans[index];
                            return ModernCard(
                              padding: const EdgeInsets.all(AppTheme.spacingMD),
                              margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              plan.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              plan.subject,
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          plan.status.name.toUpperCase(),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (plan.description != null) ...[
                                    const SizedBox(height: AppTheme.spacingMD),
                                    Text(
                                      plan.description!,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                  const SizedBox(height: AppTheme.spacingMD),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDate(plan.scheduledDate),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      const SizedBox(width: AppTheme.spacingMD),
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${plan.estimatedDurationMinutes} min',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  if (plan.learningObjectives.isNotEmpty) ...[
                                    const SizedBox(height: AppTheme.spacingMD),
                                    Text(
                                      'Objectives:',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    ...plan.learningObjectives.map((objective) => Padding(
                                          padding: const EdgeInsets.only(left: 16, bottom: 4),
                                          child: Text(
                                            '• $objective',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        )),
                                  ],
                                  const SizedBox(height: AppTheme.spacingMD),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  CreateEditLessonPlanScreen(
                                                hubId: widget.hubId,
                                                availableSubjects: _availableSubjects,
                                                lessonPlan: plan,
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            _loadLessonPlans();
                                          }
                                        },
                                        child: const Text('Edit'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

