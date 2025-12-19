import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/services/logger_service.dart';
import '../../models/family_member.dart';
import '../../services/location_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'location_settings_screen.dart';

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
    if (!mounted) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        _showErrorDialog('Please sign in to update your location');
      }
      return;
    }

    // Show loading dialog and store its navigator context
    NavigatorState? dialogNavigator;
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          dialogNavigator = Navigator.of(dialogContext);
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );
    }

    try {
      // Check and request location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted && dialogNavigator != null) {
          dialogNavigator!.pop(); // Close loading dialog
          _showErrorDialog(
            'Location services are disabled. Please enable location services in your device settings.',
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted && dialogNavigator != null) {
            dialogNavigator!.pop(); // Close loading dialog
            _showErrorDialog(
              'Location permissions are denied. Please enable location permissions in app settings.',
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted && dialogNavigator != null) {
          dialogNavigator!.pop(); // Close loading dialog
          _showErrorDialog(
            'Location permissions are permanently denied. Please enable them in app settings.',
          );
        }
        return;
      }

      // Get current location with longer timeout and fallback to lower accuracy
      Position position;
      try {
        // Try high accuracy first with 20 second timeout
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 20),
        );
      } catch (e) {
        // If high accuracy times out, try with lower accuracy (faster)
        Logger.warning('High accuracy location failed, trying with lower accuracy', error: e, tag: 'LocationScreen');
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 30),
          );
        } catch (e2) {
          // If medium also fails, try with low accuracy (fastest, uses network)
          Logger.warning('Medium accuracy location failed, trying with low accuracy', error: e2, tag: 'LocationScreen');
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 30),
          );
        }
      }

      // Update location in Firestore
      await _locationService.updateMemberLocation(
        currentUser.uid,
        position.latitude,
        position.longitude,
      );

      // Close loading dialog if still mounted
      if (mounted && dialogNavigator != null) {
        dialogNavigator!.pop();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location updated: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Refresh family members list
      if (mounted) {
        _loadFamilyMembers();
      }
    } catch (e) {
      // Close loading dialog if still mounted
      if (mounted && dialogNavigator != null) {
        dialogNavigator!.pop();
      }
      
      if (!mounted) return;
      
      // Provide more helpful error messages
      String errorMessage;
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Location request timed out. Please ensure:\n'
            '• You are outdoors or near a window\n'
            '• GPS is enabled on your device\n'
            '• Location services are working\n\n'
            'Try again in a moment.';
      } else if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Please check Firestore security rules are deployed.';
      } else {
        errorMessage = 'Failed to update location: ${e.toString()}';
      }
      
      _showErrorDialog(errorMessage);
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestLocation(FamilyMember member) async {
    try {
      await _locationService.requestLocationUpdate(member.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location requested from ${member.name}'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LocationSettingsScreen(),
                ),
              );
            },
            tooltip: 'Location settings',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _updateMyLocation,
            tooltip: 'Update my location',
          ),
        ],
      ),
      body: _familyMembers.isEmpty
          ? EmptyState(
              icon: Icons.location_off,
              title: 'No family members',
              message: 'Family members will appear here when they share their location',
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
                  color: Colors.green[50],
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap the map icon next to a family member to view their location on a map',
                          style: TextStyle(
                            color: Colors.green[900],
                            fontSize: 12,
                          ),
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
    final isCurrentUser = FirebaseAuth.instance.currentUser?.uid == member.id;

    return ModernCard(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
            ] else
              const Text(
                'Location not available',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCurrentUser)
              IconButton(
                icon: const Icon(Icons.share_location),
                onPressed: () => _requestLocation(member),
                tooltip: 'Request location',
              ),
            if (hasLocation)
              IconButton(
                icon: const Icon(Icons.map),
                onPressed: () => _showLocationDetails(member),
                tooltip: 'View on map',
              ),
          ],
        ),
      ),
    );
  }

  void _showLocationDetails(FamilyMember member) {
    if (member.latitude == null || member.longitude == null) {
      return;
    }

    final LatLng location = LatLng(member.latitude!, member.longitude!);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16), // Add padding around dialog
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.95,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${member.name}\'s Location',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Latitude: ${member.latitude!.toStringAsFixed(6)}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              Text(
                'Longitude: ${member.longitude!.toStringAsFixed(6)}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              if (member.lastSeen != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Last updated: ${app_date_utils.AppDateUtils.formatDateTime(member.lastSeen!)}',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: location,
                      zoom: 15.0,
                    ),
                    markers: {
                      Marker(
                        markerId: MarkerId(member.id),
                        position: location,
                        infoWindow: InfoWindow(
                          title: member.name,
                          snippet: member.email ?? 'No email',
                        ),
                      ),
                    },
                    mapType: MapType.normal,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    onMapCreated: (GoogleMapController controller) {
                      // Map created successfully
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
