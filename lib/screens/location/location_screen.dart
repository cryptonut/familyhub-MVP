import 'package:flutter/material.dart';
import '../../models/family_member.dart';
import '../../services/location_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final LocationService _locationService = LocationService();
  List<FamilyMember> _familyMembers = [];

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  Future<void> _loadFamilyMembers() async {
    final members = await _locationService.getFamilyMembers();
    setState(() {
      _familyMembers = members;
    });
  }

  Future<void> _updateMyLocation() async {
    // In a real app, you would use geolocator to get current location
    // For now, we'll show a dialog explaining this
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Location'),
        content: const Text(
          'To enable location sharing, you need to:\n\n'
          '1. Add location permissions to your app\n'
          '2. Use geolocator package to get current location\n'
          '3. Call _locationService.updateMemberLocation()\n\n'
          'For now, this is a demo with sample locations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _updateMyLocation,
            tooltip: 'Update my location',
          ),
        ],
      ),
      body: _familyMembers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No family members',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _familyMembers.length,
                    itemBuilder: (context, index) {
                      final member = _familyMembers[index];
                      return _buildMemberCard(member);
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Map integration requires Google Maps API key',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'To enable map view, add your Google Maps API key in '
                        'android/app/src/main/AndroidManifest.xml and configure '
                        'google_maps_flutter package.',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMemberCard(FamilyMember member) {
    final hasLocation = member.latitude != null && member.longitude != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            member.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          member.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.email != null) Text('📧 ${member.email}'),
            if (hasLocation) ...[
              const SizedBox(height: 4),
              Text(
                '📍 ${member.latitude!.toStringAsFixed(4)}, '
                '${member.longitude!.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (member.lastSeen != null)
                Text(
                  'Last seen: ${app_date_utils.AppDateUtils.getRelativeTime(member.lastSeen!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
            ] else
              const Text(
                'Location not available',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: hasLocation
            ? IconButton(
                icon: const Icon(Icons.map),
                onPressed: () {
                  _showLocationDetails(member);
                },
                tooltip: 'View on map',
              )
            : null,
      ),
    );
  }

  void _showLocationDetails(FamilyMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${member.name}\'s Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latitude: ${member.latitude!.toStringAsFixed(6)}'),
            Text('Longitude: ${member.longitude!.toStringAsFixed(6)}'),
            if (member.lastSeen != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last updated: ${app_date_utils.AppDateUtils.formatDateTime(member.lastSeen!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Map view requires\nGoogle Maps API key',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
