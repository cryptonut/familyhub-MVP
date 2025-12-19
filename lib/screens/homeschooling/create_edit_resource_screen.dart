import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/educational_resource.dart';
import '../../services/homeschooling_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../core/services/logger_service.dart';

class CreateEditResourceScreen extends StatefulWidget {
  final String hubId;
  final EducationalResource? resource;

  const CreateEditResourceScreen({
    super.key,
    required this.hubId,
    this.resource,
  });

  @override
  State<CreateEditResourceScreen> createState() =>
      _CreateEditResourceScreenState();
}

class _CreateEditResourceScreenState extends State<CreateEditResourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final HomeschoolingService _service = HomeschoolingService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  ResourceType _selectedType = ResourceType.link;
  String? _selectedGradeLevel;
  final List<String> _selectedSubjects = [];
  final List<String> _tags = [];
  
  String? _fileUrl; // For uploaded files
  String? _selectedFileName;
  File? _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.resource != null) {
      _titleController.text = widget.resource!.title;
      _descriptionController.text = widget.resource!.description ?? '';
      _urlController.text = widget.resource!.url ?? '';
      _fileUrl = widget.resource!.fileUrl;
      _selectedType = widget.resource!.type;
      _selectedGradeLevel = widget.resource!.gradeLevel;
      _selectedSubjects.addAll(widget.resource!.subjects);
      _tags.addAll(widget.resource!.tags);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      if (_selectedType == ResourceType.image) {
        // Use image picker for images
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          setState(() {
            _selectedFile = File(image.path);
            _selectedFileName = image.name;
            _fileUrl = null; // Clear previous URL
          });
        }
      } else {
        // Use file picker for documents and videos
        List<String>? allowedExtensions;
        if (_selectedType == ResourceType.document) {
          allowedExtensions = ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'];
        } else if (_selectedType == ResourceType.video) {
          allowedExtensions = ['mp4', 'mov', 'avi', 'mkv'];
        }
        
        final result = await FilePicker.platform.pickFiles(
          type: allowedExtensions != null ? FileType.custom : FileType.any,
          allowedExtensions: allowedExtensions,
          allowMultiple: false,
        );

        if (result != null && result.files.single.path != null) {
          setState(() {
            _selectedFile = File(result.files.single.path!);
            _selectedFileName = result.files.single.name;
            _fileUrl = null; // Clear previous URL
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<String?> _uploadFile() async {
    if (_selectedFile == null) return null;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final fileExtension = _selectedFileName!.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Determine content type
      String? contentType;
      if (_selectedType == ResourceType.image) {
        contentType = 'image/$fileExtension';
      } else if (_selectedType == ResourceType.video) {
        contentType = 'video/$fileExtension';
      } else if (_selectedType == ResourceType.document) {
        switch (fileExtension) {
          case 'pdf':
            contentType = 'application/pdf';
            break;
          case 'doc':
          case 'docx':
            contentType = 'application/msword';
            break;
          case 'txt':
            contentType = 'text/plain';
            break;
          default:
            contentType = 'application/octet-stream';
        }
      }

      // Upload to Firebase Storage
      final storagePath = 'hubs/${widget.hubId}/resources/$timestamp.$fileExtension';
      final storageRef = _storage.ref(storagePath);
      
      final uploadTask = storageRef.putFile(
        _selectedFile!,
        SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'uploadedBy': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
            'resourceTitle': _titleController.text.trim(),
          },
        ),
      );

      // Track upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        if (mounted) {
          setState(() {
            _uploadProgress = progress;
          });
        }
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }

      return downloadUrl;
    } catch (e, st) {
      Logger.error('Error uploading resource file', error: e, stackTrace: st, tag: 'CreateEditResourceScreen');
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: ${e.toString()}')),
        );
      }
      return null;
    }
  }

  Future<void> _saveResource() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that link type has URL, and file types have file
    if (_selectedType == ResourceType.link && _urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL is required for links')),
      );
      return;
    }

    if (_selectedType != ResourceType.link && _selectedFile == null && _fileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please ${_selectedType == ResourceType.image ? 'select an image' : 'upload a file'}')),
      );
      return;
    }

    try {
      // Upload file if one is selected
      String? finalFileUrl = _fileUrl;
      if (_selectedFile != null) {
        finalFileUrl = await _uploadFile();
        if (finalFileUrl == null) {
          return; // Upload failed, error already shown
        }
      }

      if (widget.resource == null) {
        await _service.createEducationalResource(
          hubId: widget.hubId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          type: _selectedType,
          url: _selectedType == ResourceType.link && _urlController.text.trim().isNotEmpty
              ? _urlController.text.trim()
              : null,
          fileUrl: finalFileUrl,
          subjects: _selectedSubjects,
          gradeLevel: _selectedGradeLevel,
          tags: _tags,
        );
      } else {
        // Note: Resource editing/updating not yet implemented in service layer
        // For now, show a message that editing is not supported
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resource editing is not yet supported. Please delete and recreate.'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resource == null ? 'Add Resource' : 'Edit Resource'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              DropdownButtonFormField<ResourceType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Resource Type *',
                  border: OutlineInputBorder(),
                ),
                items: ResourceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              if (_selectedType == ResourceType.link) ...[
                const SizedBox(height: AppTheme.spacingMD),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL *',
                    border: OutlineInputBorder(),
                    hintText: 'https://example.com',
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (_selectedType == ResourceType.link &&
                        (value == null || value.trim().isEmpty)) {
                      return 'URL is required for links';
                    }
                    return null;
                  },
                ),
              ] else ...[
                // File upload for document, video, image types
                const SizedBox(height: AppTheme.spacingMD),
                if (_fileUrl != null && _selectedFile == null) ...[
                  // Show existing file
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text('File already uploaded')),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                ],
                if (_selectedFile != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedType == ResourceType.image
                              ? Icons.image
                              : _selectedType == ResourceType.video
                                  ? Icons.video_library
                                  : Icons.description,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFileName!,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (_isUploading)
                                Text(
                                  'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                        if (!_isUploading)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedFile = null;
                                _selectedFileName = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  if (_isUploading) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _uploadProgress),
                  ],
                  const SizedBox(height: AppTheme.spacingMD),
                ] else if (!_isUploading) ...[
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: Icon(_selectedType == ResourceType.image
                        ? Icons.image
                        : _selectedType == ResourceType.video
                            ? Icons.video_library
                            : Icons.upload_file),
                    label: Text(_selectedType == ResourceType.image
                        ? 'Select Image'
                        : _selectedType == ResourceType.video
                            ? 'Select Video'
                            : 'Select Document'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                ],
              ],
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Grade Level (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Grade 5',
                ),
                onChanged: (value) => _selectedGradeLevel =
                    value.trim().isEmpty ? null : value.trim(),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              const Text(
                'Subjects (tap to add)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Wrap(
                spacing: AppTheme.spacingXS,
                children: ['Math', 'Science', 'English', 'History', 'Art']
                    .map((subject) => FilterChip(
                          label: Text(subject),
                          selected: _selectedSubjects.contains(subject),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSubjects.add(subject);
                              } else {
                                _selectedSubjects.remove(subject);
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: ElevatedButton.icon(
            onPressed: _saveResource,
            icon: const Icon(Icons.check),
            label: Text(widget.resource == null ? 'Create Resource' : 'Save Changes'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

