import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';

/// Service for end-to-end encryption of messages
/// Uses X25519 for key exchange and AES-256-GCM for encryption
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final Map<String, SimpleKeyPair> _keyPairs = {}; // userId -> keyPair
  final Map<String, SimplePublicKey> _publicKeys = {}; // userId -> publicKey
  final AesGcm _cipher = AesGcm.with256bits();

  /// Generate or retrieve key pair for current user
  Future<SimpleKeyPair> getOrCreateKeyPair(String userId) async {
    if (_keyPairs.containsKey(userId)) {
      return _keyPairs[userId]!;
    }

    try {
      final keyPair = await _cipher.newKeyPair();
      _keyPairs[userId] = keyPair;
      
      // Extract and store public key
      final publicKey = await keyPair.extractPublicKey();
      _publicKeys[userId] = publicKey;
      
      Logger.info('Key pair generated for user: $userId', tag: 'EncryptionService');
      return keyPair;
    } catch (e) {
      Logger.error('Error generating key pair', error: e, tag: 'EncryptionService');
      throw EncryptionException('Failed to generate encryption keys', code: 'key-generation-failed', originalError: e);
    }
  }

  /// Get public key for a user
  Future<SimplePublicKey?> getPublicKey(String userId) async {
    if (_publicKeys.containsKey(userId)) {
      return _publicKeys[userId];
    }

    // TODO: Fetch from Firestore or key exchange
    // For now, return null (key exchange not implemented)
    return null;
  }

  /// Encrypt a message
  Future<EncryptedMessage> encryptMessage({
    required String plaintext,
    required String senderId,
    required String recipientId,
  }) async {
    try {
      // Get or create sender's key pair
      final senderKeyPair = await getOrCreateKeyPair(senderId);
      
      // Get recipient's public key
      final recipientPublicKey = await getPublicKey(recipientId);
      if (recipientPublicKey == null) {
        throw EncryptionException(
          'Recipient public key not found. Key exchange required.',
          code: 'public-key-not-found',
        );
      }

      // Perform key agreement (ECDH)
      final sharedSecret = await senderKeyPair.sharedSecretKey(
        remotePublicKey: recipientPublicKey,
      );

      // Encrypt message
      final secretBox = await _cipher.encrypt(
        plaintext.codeUnits,
        secretKey: sharedSecret,
      );

      return EncryptedMessage(
        ciphertext: base64Encode(secretBox.cipherText),
        nonce: base64Encode(secretBox.nonce),
        mac: base64Encode(secretBox.mac.bytes),
        senderPublicKey: base64Encode((await senderKeyPair.extractPublicKey()).bytes),
      );
    } catch (e) {
      Logger.error('Error encrypting message', error: e, tag: 'EncryptionService');
      if (e is EncryptionException) rethrow;
      throw EncryptionException('Failed to encrypt message', code: 'encryption-failed', originalError: e);
    }
  }

  /// Decrypt a message
  Future<String> decryptMessage({
    required EncryptedMessage encryptedMessage,
    required String recipientId,
    required String senderId,
  }) async {
    try {
      // Get recipient's key pair
      final recipientKeyPair = await getOrCreateKeyPair(recipientId);
      
      // Get sender's public key from message
      final senderPublicKeyBytes = base64Decode(encryptedMessage.senderPublicKey);
      final senderPublicKey = SimplePublicKey(senderPublicKeyBytes, type: KeyPairType.x25519);

      // Perform key agreement
      final sharedSecret = await recipientKeyPair.sharedSecretKey(
        remotePublicKey: senderPublicKey,
      );

      // Decrypt message
      final secretBox = SecretBox(
        base64Decode(encryptedMessage.ciphertext),
        nonce: base64Decode(encryptedMessage.nonce),
        mac: Mac(base64Decode(encryptedMessage.mac)),
      );

      final plaintext = await _cipher.decrypt(
        secretBox,
        secretKey: sharedSecret,
      );

      return String.fromCharCodes(plaintext);
    } catch (e) {
      Logger.error('Error decrypting message', error: e, tag: 'EncryptionService');
      if (e is EncryptionException) rethrow;
      throw EncryptionException('Failed to decrypt message', code: 'decryption-failed', originalError: e);
    }
  }

  /// Store public key (for key exchange)
  Future<void> storePublicKey(String userId, SimplePublicKey publicKey) async {
    _publicKeys[userId] = publicKey;
    // TODO: Store in Firestore for key exchange
    Logger.info('Public key stored for user: $userId', tag: 'EncryptionService');
  }

  /// Clear keys (for logout)
  void clearKeys() {
    _keyPairs.clear();
    _publicKeys.clear();
    Logger.info('Encryption keys cleared', tag: 'EncryptionService');
  }
}

/// Encrypted message data structure
class EncryptedMessage {
  final String ciphertext; // Base64 encoded
  final String nonce; // Base64 encoded
  final String mac; // Base64 encoded
  final String senderPublicKey; // Base64 encoded

  EncryptedMessage({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    required this.senderPublicKey,
  });

  Map<String, dynamic> toJson() => {
        'ciphertext': ciphertext,
        'nonce': nonce,
        'mac': mac,
        'senderPublicKey': senderPublicKey,
      };

  factory EncryptedMessage.fromJson(Map<String, dynamic> json) => EncryptedMessage(
        ciphertext: json['ciphertext'] as String,
        nonce: json['nonce'] as String,
        mac: json['mac'] as String,
        senderPublicKey: json['senderPublicKey'] as String,
      );
}

/// Exception for encryption-related errors
class EncryptionException extends AppException {
  const EncryptionException(super.message, {super.code, super.originalError});
}


