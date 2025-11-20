import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../services/video_call_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class VideoCallScreen extends StatefulWidget {
  final String hubId;
  final String channelName;

  const VideoCallScreen({
    super.key,
    required this.hubId,
    required this.channelName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final VideoCallService _videoCallService = VideoCallService();
  final AuthService _authService = AuthService();

  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isLoading = true;
  List<int> _remoteUids = [];
  int? _localUid;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      await _videoCallService.initialize();
      final engine = _videoCallService.engine;
      if (engine == null) {
        throw Exception('Agora engine not initialized');
      }

      // Set up event handlers
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            setState(() {
              _localUid = connection.localUid;
              _isLoading = false;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            setState(() {
              _remoteUids.add(remoteUid);
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            setState(() {
              _remoteUids.remove(remoteUid);
            });
          },
        ),
      );

      // Join channel
      // Note: In production, generate token server-side
      await engine.joinChannel(
        token: '', // TODO: Generate token via Cloud Function
        channelId: widget.channelName,
        uid: 0, // 0 means Agora assigns a UID
        options: const ChannelMediaOptions(),
      );

      await _videoCallService.joinCall(widget.hubId, widget.channelName);
    } catch (e) {
      debugPrint('Error initializing call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining call: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _toggleMute() async {
    final engine = _videoCallService.engine;
    if (engine != null) {
      await engine.muteLocalAudioStream(!_isMuted);
      setState(() {
        _isMuted = !_isMuted;
      });
    }
  }

  Future<void> _toggleVideo() async {
    final engine = _videoCallService.engine;
    if (engine != null) {
      await engine.muteLocalVideoStream(!_isVideoEnabled);
      setState(() {
        _isVideoEnabled = !_isVideoEnabled;
      });
    }
  }

  Future<void> _endCall() async {
    final engine = _videoCallService.engine;
    if (engine != null) {
      await engine.leaveChannel();
    }
    await _videoCallService.leaveCall(widget.hubId);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _videoCallService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Grid
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              _buildVideoGrid(),

            // Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      onPressed: _toggleMute,
                      color: _isMuted ? Colors.red : Colors.white,
                    ),
                    _buildControlButton(
                      icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                      label: _isVideoEnabled ? 'Video Off' : 'Video On',
                      onPressed: _toggleVideo,
                      color: _isVideoEnabled ? Colors.white : Colors.red,
                    ),
                    _buildControlButton(
                      icon: Icons.call_end,
                      label: 'End',
                      onPressed: _endCall,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoGrid() {
    final totalParticipants = 1 + _remoteUids.length; // Local + remotes

    if (totalParticipants == 1) {
      // Only local user
      return _buildLocalVideo();
    } else if (totalParticipants == 2) {
      // Two participants - side by side
      return Row(
        children: [
          Expanded(child: _buildLocalVideo()),
          Expanded(child: _buildRemoteVideo(_remoteUids[0])),
        ],
      );
    } else {
      // Multiple participants - grid layout
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1,
        ),
        itemCount: totalParticipants,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildLocalVideo();
          } else {
            return _buildRemoteVideo(_remoteUids[index - 1]);
          }
        },
      );
    }
  }

  Widget _buildLocalVideo() {
    final engine = _videoCallService.engine;
    if (engine == null) {
      return const Center(child: Text('Loading...'));
    }

    return FutureBuilder<UserModel?>(
      future: _authService.getCurrentUserModel(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              if (_isVideoEnabled)
                AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        child: Text(
                          user?.displayName[0].toUpperCase() ?? '?',
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.displayName ?? 'You',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              if (_isMuted)
                const Positioned(
                  bottom: 8,
                  left: 8,
                  child: Icon(Icons.mic_off, color: Colors.red),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRemoteVideo(int uid) {
    final engine = _videoCallService.engine;
    if (engine == null) {
      return const Center(child: Text('Loading...'));
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(uid: uid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = Colors.white,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: 28),
            onPressed: onPressed,
            iconSize: 28,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}

