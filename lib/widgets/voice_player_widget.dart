import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/app_theme.dart';

class VoicePlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isCurrentUser;
  final ThemeData theme;

  const VoicePlayerWidget({
    super.key,
    required this.audioUrl,
    required this.isCurrentUser,
    required this.theme,
  });

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadAudio();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
  }

  Future<void> _loadAudio() async {
    try {
      setState(() {
        _isLoading = true;
      });
      await _audioPlayer.setUrl(widget.audioUrl);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isLoading) return;
    
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSM),
      decoration: BoxDecoration(
        color: widget.isCurrentUser
            ? Colors.white.withOpacity(0.2)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _isLoading ? null : _togglePlayPause,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isCurrentUser ? Colors.white : widget.theme.colorScheme.primary,
                      ),
                    ),
                  )
                : Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: widget.isCurrentUser ? Colors.white : widget.theme.colorScheme.primary,
                  ),
          ),
          const SizedBox(width: AppTheme.spacingSM),
          if (_duration.inSeconds > 0)
            SizedBox(
              width: 100,
              child: LinearProgressIndicator(
                value: _duration.inSeconds > 0
                    ? _position.inSeconds / _duration.inSeconds
                    : 0,
                backgroundColor: widget.isCurrentUser
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.isCurrentUser ? Colors.white : widget.theme.colorScheme.primary,
                ),
              ),
            ),
          const SizedBox(width: AppTheme.spacingSM),
          Text(
            _formatDuration(_position),
            style: widget.theme.textTheme.bodySmall?.copyWith(
              color: widget.isCurrentUser
                  ? Colors.white.withOpacity(0.9)
                  : widget.theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

