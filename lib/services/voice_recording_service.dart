import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'auth_service.dart';

class VoiceRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  
  bool _isRecording = false;
  String? _currentRecordingPath;
  Duration _recordingDuration = Duration.zero;
  
  bool get isRecording => _isRecording;
  Duration get recordingDuration => _recordingDuration;
  
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.microphone.request();
      return status.isGranted;
    }
    return true;
  }
  
  Future<String?> startRecording() async {
    if (_isRecording) {
      debugPrint('VoiceRecordingService: Already recording');
      return null;
    }
    
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('VoiceRecordingService: Microphone permission denied');
      return null;
    }
    
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/voice_$timestamp.m4a';
      
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );
      
      _isRecording = true;
      _recordingDuration = Duration.zero;
      debugPrint('VoiceRecordingService: Started recording at $_currentRecordingPath');
      return _currentRecordingPath;
    } catch (e) {
      debugPrint('VoiceRecordingService: Error starting recording: $e');
      return null;
    }
  }
  
  Future<String?> stopRecording() async {
    if (!_isRecording || _currentRecordingPath == null) {
      return null;
    }
    
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      debugPrint('VoiceRecordingService: Stopped recording, path: $path');
      return path;
    } catch (e) {
      debugPrint('VoiceRecordingService: Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }
  
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }
    
    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('VoiceRecordingService: Error deleting recording: $e');
      }
      _currentRecordingPath = null;
    }
    _recordingDuration = Duration.zero;
  }
  
  Future<String?> uploadVoiceMessage(String localFilePath) async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      final userId = _auth.currentUser?.uid;
      
      if (familyId == null || userId == null) {
        throw Exception('User not authenticated or not part of a family');
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'voice_${userId}_$timestamp.m4a';
      final storagePath = 'families/$familyId/voice_messages/$fileName';
      
      final file = File(localFilePath);
      final ref = _storage.ref().child(storagePath);
      
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      
      debugPrint('VoiceRecordingService: Uploaded voice message to $downloadUrl');
      
      // Clean up local file
      try {
        await file.delete();
      } catch (e) {
        debugPrint('VoiceRecordingService: Error deleting local file: $e');
      }
      
      return downloadUrl;
    } catch (e) {
      debugPrint('VoiceRecordingService: Error uploading voice message: $e');
      rethrow;
    }
  }
  
  void updateRecordingDuration(Duration duration) {
    _recordingDuration = duration;
  }
  
  void dispose() {
    if (_isRecording) {
      _recorder.stop();
    }
    _recorder.dispose();
  }
}

