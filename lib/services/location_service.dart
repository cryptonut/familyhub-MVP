import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/family_member.dart';
import 'auth_service.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  Future<String?> get _familyId async {
    final userModel = await _authService.getCurrentUserModel();
    return userModel?.familyId;
  }

  Future<String> get _collectionPath async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    return 'families/$familyId/members';
  }

  Future<List<FamilyMember>> getFamilyMembers() async {
    final familyId = await _familyId;
    if (familyId == null) return [];
    
    // Get family members from users collection
    final familyMembers = await _authService.getFamilyMembers();
    
    // Also get location data from members collection
    final collectionPath = await _collectionPath;
    final snapshot = await _firestore.collection(collectionPath).get();
    final locationMap = <String, Map<String, dynamic>>{};
    
    for (var doc in snapshot.docs) {
      locationMap[doc.id] = doc.data();
    }
    
    return familyMembers.map((user) {
      final locationData = locationMap[user.uid];
      return FamilyMember(
        id: user.uid,
        name: user.displayName,
        email: user.email,
        latitude: locationData?['latitude'] as double?,
        longitude: locationData?['longitude'] as double?,
        lastSeen: locationData?['lastSeen'] != null
            ? DateTime.parse(locationData!['lastSeen'] as String)
            : null,
      );
    }).toList();
  }

  Stream<List<FamilyMember>> getFamilyMembersStream() async* {
    final familyId = await _familyId;
    if (familyId == null) {
      yield [];
      return;
    }
    
    final collectionPath = await _collectionPath;
    yield* _firestore
        .collection(collectionPath)
        .snapshots()
        .asyncMap((snapshot) async {
      final familyMembers = await _authService.getFamilyMembers();
      final locationMap = <String, Map<String, dynamic>>{};
      
      for (var doc in snapshot.docs) {
        locationMap[doc.id] = doc.data();
      }
      
      return familyMembers.map((user) {
        final locationData = locationMap[user.uid];
        return FamilyMember(
          id: user.uid,
          name: user.displayName,
          email: user.email,
          latitude: locationData?['latitude'] as double?,
          longitude: locationData?['longitude'] as double?,
          lastSeen: locationData?['lastSeen'] != null
              ? DateTime.parse(locationData!['lastSeen'] as String)
              : null,
        );
      }).toList();
    });
  }

  Future<void> updateMemberLocation(
    String memberId,
    double latitude,
    double longitude,
  ) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    final collectionPath = await _collectionPath;
    await _firestore.collection(collectionPath).doc(memberId).set({
      'latitude': latitude,
      'longitude': longitude,
      'lastSeen': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> addMember(FamilyMember member) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    final collectionPath = await _collectionPath;
    await _firestore.collection(collectionPath).doc(member.id).set({
      'latitude': member.latitude,
      'longitude': member.longitude,
      'lastSeen': member.lastSeen?.toIso8601String(),
    });
  }
}
