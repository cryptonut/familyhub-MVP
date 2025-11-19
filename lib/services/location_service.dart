import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/family_member.dart';
import 'auth_service.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  String? get _familyId => _auth.currentUser?.uid;

  String get _collectionPath => 'families/$_familyId/members';

  Future<List<FamilyMember>> getFamilyMembers() async {
    if (_familyId == null) return [];
    
    // Get family members from users collection
    final familyMembers = await _authService.getFamilyMembers();
    
    // Also get location data from members collection
    final snapshot = await _firestore.collection(_collectionPath).get();
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

  Stream<List<FamilyMember>> getFamilyMembersStream() {
    if (_familyId == null) return Stream.value([]);
    
    return _firestore
        .collection(_collectionPath)
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
    if (_familyId == null) throw Exception('User not authenticated');
    
    await _firestore.collection(_collectionPath).doc(memberId).set({
      'latitude': latitude,
      'longitude': longitude,
      'lastSeen': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> addMember(FamilyMember member) async {
    if (_familyId == null) throw Exception('User not authenticated');
    
    await _firestore.collection(_collectionPath).doc(member.id).set({
      'latitude': member.latitude,
      'longitude': member.longitude,
      'lastSeen': member.lastSeen?.toIso8601String(),
    });
  }
}
