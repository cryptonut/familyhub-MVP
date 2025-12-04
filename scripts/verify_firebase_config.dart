/// Verification script to check Firebase configuration
/// Run with: dart scripts/verify_firebase_config.dart

import 'dart:io';
import 'package:path/path.dart' as path;

void main() async {
  print('=== Firebase Configuration Verification ===\n');
  
  // Check google-services.json exists
  final devGoogleServices = File('android/app/src/dev/google-services.json');
  final qaGoogleServices = File('android/app/src/qa/google-services.json');
  final prodGoogleServices = File('android/app/src/prod/google-services.json');
  
  print('1. Checking google-services.json files...');
  if (devGoogleServices.existsSync()) {
    print('   ✓ dev/google-services.json exists');
    await _checkGoogleServices(devGoogleServices, 'dev');
  } else {
    print('   ✗ dev/google-services.json NOT FOUND');
  }
  
  if (qaGoogleServices.existsSync()) {
    print('   ✓ qa/google-services.json exists');
    await _checkGoogleServices(qaGoogleServices, 'qa');
  } else {
    print('   ⚠ qa/google-services.json not found (optional)');
  }
  
  if (prodGoogleServices.existsSync()) {
    print('   ✓ prod/google-services.json exists');
    await _checkGoogleServices(prodGoogleServices, 'prod');
  } else {
    print('   ⚠ prod/google-services.json not found (optional)');
  }
  
  print('\n2. Configuration Checklist:');
  print('   [ ] Cloud Firestore API is enabled in Google Cloud Console');
  print('   [ ] API key has "Cloud Firestore API" in API restrictions');
  print('   [ ] API key application restrictions are set correctly');
  print('   [ ] OAuth client has correct package name and SHA-1');
  print('   [ ] OAuth consent screen is configured');
  
  print('\n3. Required Actions in Google Cloud Console:');
  print('   → Go to: https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0');
  print('   → Enable Cloud Firestore API: https://console.cloud.google.com/apis/library/firestore.googleapis.com');
  print('   → See ROOT_CAUSE_FIX_API_KEY_RESTRICTIONS.md for detailed steps');
  
  print('\n=== Verification Complete ===');
}

Future<void> _checkGoogleServices(File file, String flavor) async {
  try {
    final content = await file.readAsString();
    final json = content;
    
    // Check for OAuth clients
    if (json.contains('oauth_client')) {
      print('   ✓ Contains OAuth client configuration');
    } else {
      print('   ✗ Missing OAuth client configuration');
    }
    
    // Check for API keys
    if (json.contains('api_key')) {
      print('   ✓ Contains API key configuration');
    } else {
      print('   ✗ Missing API key configuration');
    }
    
    // Check for package name
    final packageName = flavor == 'dev' 
        ? 'com.example.familyhub_mvp.dev'
        : flavor == 'qa'
            ? 'com.example.familyhub_mvp.test'
            : 'com.example.familyhub_mvp';
    
    if (json.contains(packageName)) {
      print('   ✓ Contains correct package name: $packageName');
    } else {
      print('   ⚠ Package name $packageName not found (may be in different client entry)');
    }
    
    // Check for SHA-1
    if (json.contains('bb7a6a5f57f1dd0ded142a5c6f2614fd54c3c71c')) {
      print('   ✓ Contains SHA-1 fingerprint');
    } else {
      print('   ⚠ SHA-1 fingerprint not found (may need to be added)');
    }
  } catch (e) {
    print('   ✗ Error reading file: $e');
  }
}
