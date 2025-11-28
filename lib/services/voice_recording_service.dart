import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
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
      Logger.warning('Already recording', tag: 'VoiceRecordingService');
      return null;
    }
    
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      Logger.warning('Microphone permission denied', tag: 'VoiceRecordingService');
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
      Logger.info('Started recording at $_currentRecordingPath', tag: 'VoiceRecordingService');
      return _currentRecordingPath;
    } catch (e) {
      Logger.error('Error starting recording', error: e, tag: 'VoiceRecordingService');
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
      Logger.info('Stopped recording, path: $path', tag: 'VoiceRecordingService');
      return path;
    } catch (e) {
      Logger.error('Error stopping recording', error: e, tag: 'VoiceRecordingService');
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
        Logger.warning('Error deleting recording', error: e, tag: 'VoiceRecordingService');
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
        throw AuthException('User not authenticated or not part of a family', code: 'not-authenticated');
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'voice_${userId}_$timestamp.m4a';
      final storagePath = 'families/$familyId/voice_messages/$fileName';
      
      final file = File(localFilePath);
      final ref = _storage.ref().child(storagePath);
      
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      
      Logger.info('Uploaded voice message to $downloadUrl', tag: 'VoiceRecordingService');
      
      // Clean up local file
      try {
        await file.delete();
      } catch (e) {
        Logger.warning('Error deleting local file', error: e, tag: 'VoiceRecordingService');
      }
      
      return downloadUrl;
    } catch (e) {
      Logger.error('Error uploading voice message', error: e, tag: 'VoiceRecordingService');
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

