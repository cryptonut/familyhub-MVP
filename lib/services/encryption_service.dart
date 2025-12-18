import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/logger_service.dart';

/// Service for managing encryption keys and encrypting/decrypting messages
/// Implements end-to-end encryption for premium chat features
class EncryptionService {
  static const String _prefsKeyPrefix = 'encryption_keys_';
  static const String _deviceKeyKey = 'device_encryption_key';
  
  SecretKey? _deviceKey;
  
  /// Initialize encryption service and generate/load device key
  Future<void> initialize() async {
    try {
      await _loadOrGenerateDeviceKey();
      Logger.info('EncryptionService initialized', tag: 'EncryptionService');
    } catch (e) {
      Logger.error('Error initializing EncryptionService', error: e, tag: 'EncryptionService');
      rethrow;
    }
  }
  
  /// Load or generate device encryption key
  Future<void> _loadOrGenerateDeviceKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyData = prefs.getString(_deviceKeyKey);
      
      if (keyData != null) {
        // Load existing key
        final keyBytes = base64Decode(keyData);
        _deviceKey = SecretKey(Uint8List.fromList(keyBytes));
      } else {
        // Generate new key (256 bits = 32 bytes)
        final algorithm = AesGcm.with256bits();
        _deviceKey = await algorithm.newSecretKey();
        
        // Save key
        final keyBytes = await _deviceKey!.extractBytes();
        await prefs.setString(_deviceKeyKey, base64Encode(keyBytes));
      }
    } catch (e) {
      Logger.error('Error loading/generating device key', error: e, tag: 'EncryptionService');
      rethrow;
    }
  }
  
  /// Generate a shared secret key for a chat conversation
  /// This key is shared between all participants in the conversation
  Future<SecretKey> generateSharedKey(String conversationId) async {
    try {
      final algorithm = AesGcm.with256bits();
      final key = await algorithm.newSecretKey();
      
      // Store the key (encrypted with device key)
      await _storeSharedKey(conversationId, key);
      
      return key;
    } catch (e) {
      Logger.error('Error generating shared key', error: e, tag: 'EncryptionService');
      rethrow;
    }
  }
  
  /// Get shared key for a conversation (loads from storage)
  Future<SecretKey?> getSharedKey(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyData = prefs.getString('$_prefsKeyPrefix$conversationId');
      
      if (keyData == null) return null;
      
      // Decrypt the stored key using device key
      final encryptedKeyBytes = Uint8List.fromList(base64Decode(keyData));
      final decryptedKeyBytes = await _decryptWithDeviceKey(encryptedKeyBytes);
      
      return SecretKey(decryptedKeyBytes);
    } catch (e) {
      Logger.error('Error getting shared key', error: e, tag: 'EncryptionService');
      return null;
    }
  }
  
  /// Store shared key (encrypted with device key)
  Future<void> _storeSharedKey(String conversationId, SecretKey key) async {
    try {
      final keyBytes = await key.extractBytes();
      final encryptedKeyBytes = await _encryptWithDeviceKey(Uint8List.fromList(keyBytes));
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefsKeyPrefix$conversationId',
        base64Encode(encryptedKeyBytes),
      );
    } catch (e) {
      Logger.error('Error storing shared key', error: e, tag: 'EncryptionService');
      rethrow;
    }
  }
  
  /// Encrypt data with device key
  Future<Uint8List> _encryptWithDeviceKey(Uint8List data) async {
    if (_deviceKey == null) {
      await _loadOrGenerateDeviceKey();
    }
    
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      data,
      secretKey: _deviceKey!,
      nonce: nonce,
    );
    
    // Combine nonce, ciphertext, and MAC
    final nonceLen = nonce.length;
    final cipherLen = secretBox.cipherText.length;
    final macLen = secretBox.mac.bytes.length;
    final result = Uint8List(nonceLen + cipherLen + macLen);
    var offset = 0;
    result.setRange(offset, offset + nonceLen, nonce);
    offset += nonceLen;
    result.setRange(offset, offset + cipherLen, secretBox.cipherText);
    offset += cipherLen;
    result.setRange(offset, offset + macLen, secretBox.mac.bytes);
    
    return result;
  }
  
  /// Decrypt data with device key
  Future<Uint8List> _decryptWithDeviceKey(Uint8List encryptedData) async {
    if (_deviceKey == null) {
      await _loadOrGenerateDeviceKey();
    }
    
    final algorithm = AesGcm.with256bits();
    
    // Extract nonce, ciphertext, and MAC
    final nonceLength = algorithm.nonceLength;
    final macLength = 16; // GCM MAC is 16 bytes
    
    final nonce = encryptedData.sublist(0, nonceLength);
    final cipherText = encryptedData.sublist(
      nonceLength,
      encryptedData.length - macLength,
    );
    final macBytes = encryptedData.sublist(encryptedData.length - macLength);
    
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    
    final decrypted = await algorithm.decrypt(
      secretBox,
      secretKey: _deviceKey!,
    );
    return Uint8List.fromList(decrypted);
  }
  
  /// Encrypt a message for a conversation
  Future<String> encryptMessage(String message, String conversationId) async {
    try {
      // Get or generate shared key for this conversation
      var sharedKey = await getSharedKey(conversationId);
      if (sharedKey == null) {
        sharedKey = await generateSharedKey(conversationId);
      }
      
      // Encrypt the message
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final algorithm = AesGcm.with256bits();
      final nonce = algorithm.newNonce();
      final secretBox = await algorithm.encrypt(
        messageBytes,
        secretKey: sharedKey,
        nonce: nonce,
      );
      
      // Encode as base64 for storage in Firestore
      final encryptedData = {
        'nonce': base64Encode(nonce),
        'ciphertext': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      };
      
      return jsonEncode(encryptedData);
    } catch (e) {
      Logger.error('Error encrypting message', error: e, tag: 'EncryptionService');
      rethrow;
    }
  }
  
  /// Decrypt a message from a conversation
  Future<String> decryptMessage(String encryptedMessageJson, String conversationId) async {
    try {
      // Get shared key for this conversation
      final sharedKey = await getSharedKey(conversationId);
      if (sharedKey == null) {
        throw Exception('Shared key not found for conversation: $conversationId');
      }
      
      // Decode the encrypted message
      final encryptedData = jsonDecode(encryptedMessageJson) as Map<String, dynamic>;
      final nonce = base64Decode(encryptedData['nonce'] as String);
      final cipherText = base64Decode(encryptedData['ciphertext'] as String);
      final macBytes = base64Decode(encryptedData['mac'] as String);
      
      // Decrypt
      final algorithm = AesGcm.with256bits();
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );
      
      final decryptedBytes = await algorithm.decrypt(
        secretBox,
        secretKey: sharedKey,
      );
      
      return utf8.decode(Uint8List.fromList(decryptedBytes));
    } catch (e) {
      Logger.error('Error decrypting message', error: e, tag: 'EncryptionService');
      rethrow;
    }
  }
  
  /// Share encryption key with another user
  /// In a real implementation, this would use a key exchange protocol
  /// For now, we'll store the key in Firestore encrypted with the recipient's public key
  /// (This is a simplified version - full E2EE would use Signal Protocol)
  Future<void> shareKeyWithUser(String conversationId, String recipientUserId) async {
    try {
      final sharedKey = await getSharedKey(conversationId);
      if (sharedKey == null) {
        throw Exception('Shared key not found for conversation: $conversationId');
      }
      
      // TODO: Implement proper key exchange using recipient's public key
      // For now, this is a placeholder
      Logger.info(
        'Key sharing requested for conversation $conversationId with user $recipientUserId',
        tag: 'EncryptionService',
      );
    } catch (e) {
      Logger.error('Error sharing key', error: e, tag: 'EncryptionService');
      rethrow;
    }
  }
  
  /// Check if encryption is enabled for a conversation
  Future<bool> isEncryptionEnabled(String conversationId) async {
    final sharedKey = await getSharedKey(conversationId);
    return sharedKey != null;
  }
  
  /// Delete encryption keys for a conversation (when leaving or deleting)
  Future<void> deleteConversationKeys(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefsKeyPrefix$conversationId');
      Logger.info('Deleted encryption keys for conversation: $conversationId', tag: 'EncryptionService');
    } catch (e) {
      Logger.error('Error deleting conversation keys', error: e, tag: 'EncryptionService');
    }
  }
}
