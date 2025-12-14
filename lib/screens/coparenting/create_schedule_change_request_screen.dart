import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/coparenting_service.dart';
import '../../services/auth_service.dart';
import '../../services/hub_service.dart';
import '../../utils/app_theme.dart';

/// Screen for creating a schedule change request
class CreateScheduleChangeRequestScreen extends StatefulWidget {
  final String hubId;
  final String? childId;

  const CreateScheduleChangeRequestScreen({
    super.key,
    required this.hubId,
    this.childId,
  });

  @override
  State<CreateScheduleChangeRequestScreen> createState() => _CreateScheduleChangeRequestScreenState();
}

class _CreateScheduleChangeRequestScreenState extends State<CreateScheduleChangeRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final CoparentingService _service = CoparentingService();
  final HubService _hubService = HubService();
  final AuthService _authService = AuthService();
  final _reasonController = TextEditingController();
  
  List<UserModel> _members = [];
  String? _selectedChildId;
  DateTime? _requestedDate;
  DateTime? _swapWithDate;
  bool _isSwap = false;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.childId;
    _loadData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hub = await _hubService.getHub(widget.hubId);
      final members = <UserModel>[];
      if (hub != null) {
        for (final memberId in hub.memberIds) {
          final user = await _authService.getUserModel(memberId);
          if (user != null) {
            members.add(user);
          }
        }
      }

      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _selectRequestedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requestedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _requestedDate = picked;
      });
    }
  }

  Future<void> _selectSwapWithDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _swapWithDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _swapWithDate = picked;
      });
    }
  }

  Future<void> _saveRequest() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a child'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_requestedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a requested date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isSwap && _swapWithDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a swap date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _service.requestScheduleChange(
        hubId: widget.hubId,
        childId: _selectedChildId!,
        requestedDate: _requestedDate!,
        swapWithDate: _isSwap && _swapWithDate != null
            ? _swapWithDate!.toIso8601String()
            : null,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule change request created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Schedule Change'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Child selection
                    DropdownButtonFormField<String>(
                      value: _selectedChildId,
                      decoration: const InputDecoration(
                        labelText: 'Child *',
                        border: OutlineInputBorder(),
                        helperText: 'Select the child for this request',
                      ),
                      items: _members.map((member) {
                        return DropdownMenuItem(
                          value: member.uid,
                          child: Text(member.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedChildId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a child';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Requested date
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Requested Date *',
                        border: OutlineInputBorder(),
                        helperText: 'The date you want to change',
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _requestedDate != null
                                  ? DateFormat('MMM d, y').format(_requestedDate!)
                                  : 'Select date',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _selectRequestedDate,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Swap toggle
                    CheckboxListTile(
                      title: const Text('Swap with another date'),
                      subtitle: const Text('Exchange this date with another date'),
                      value: _isSwap,
                      onChanged: (value) {
                        setState(() {
                          _isSwap = value ?? false;
                          if (!_isSwap) {
                            _swapWithDate = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Swap with date (conditional)
                    if (_isSwap) ...[
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Swap With Date *',
                          border: OutlineInputBorder(),
                          helperText: 'The date to swap with',
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _swapWithDate != null
                                    ? DateFormat('MMM d, y').format(_swapWithDate!)
                                    : 'Select date',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: _selectSwapWithDate,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                    ],

                    // Reason
                    TextFormField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason (optional)',
                        border: OutlineInputBorder(),
                        helperText: 'Explain why you need this change',
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveRequest,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Submit Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }
}

