import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:matrix/matrix.dart';
import 'package:livekit_client/livekit_client.dart';
import '../services/livekit_service.dart';
import '../theme/app_theme.dart';

class CallScreen extends StatefulWidget {
  final Room room;
  final bool isVideo;
  
  const CallScreen({
    super.key,
    required this.room,
    this.isVideo = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isConnecting = true;
  bool _isMuted = false;
  bool _isVideoEnabled = false;
  bool _isSpeakerOn = false;
  bool _isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  Future<void> _initCall() async {
    final livekitService = Provider.of<LiveKitService>(context, listen: false);
    
    // Get token from server
    // In production, implement proper token fetching
    final token = await livekitService.getToken(
      roomName: widget.room.id,
      participantName: widget.room.client.userID ?? 'User',
    );
    
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to call'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }
    
    final success = await livekitService.connect(
      url: LiveKitService.defaultLiveKitUrl,
      token: token,
      enableVideo: widget.isVideo,
      enableAudio: true,
    );
    
    if (success && mounted) {
      setState(() {
        _isConnecting = false;
        _isVideoEnabled = widget.isVideo;
      });
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Consumer<LiveKitService>(
          builder: (context, livekitService, child) {
            if (_isConnecting) {
              return _buildConnectingScreen();
            }
            
            return Stack(
              children: [
                // Video grid or avatar
                _buildMainContent(livekitService),
                
                // Top bar
                _buildTopBar(),
                
                // Bottom controls
                _buildControls(livekitService),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildConnectingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🐉', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 24),
          Text(
            'Connecting...',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            widget.room.name ?? 'Call',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(LiveKitService livekitService) {
    if (_isVideoEnabled && livekitService.room != null) {
      return _buildVideoGrid(livekitService);
    }
    
    return _buildVoiceCallUI(livekitService);
  }

  Widget _buildVideoGrid(LiveKitService livekitService) {
    final participants = <Participant>[
      if (livekitService.localParticipant != null)
        livekitService.localParticipant!,
      ...livekitService.remoteParticipants,
    ];
    
    if (participants.isEmpty) {
      return _buildVoiceCallUI(livekitService);
    }
    
    // For 1-2 participants, show full screen
    if (participants.length <= 2) {
      return Stack(
        children: [
          // Remote participant (full screen)
          if (participants.length > 1)
            Positioned.fill(
              child: _buildParticipantVideo(participants[1]),
            ),
          
          // Local participant (small overlay)
          Positioned(
            right: 16,
            top: 100,
            width: 120,
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildParticipantVideo(participants[0]),
            ),
          ),
        ],
      );
    }
    
    // Grid for multiple participants
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length <= 4 ? 2 : 3,
        childAspectRatio: 9 / 16,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildParticipantVideo(participants[index]),
        );
      },
    );
  }

  Widget _buildParticipantVideo(Participant participant) {
    final videoTrack = participant.videoTrackPublications.firstOrNull?.track;
    
    if (videoTrack != null && !videoTrack.muted) {
      return Stack(
        fit: StackFit.expand,
        children: [
          VideoTrackRenderer(videoTrack as VideoTrack),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                participant.identity,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      );
    }
    
    return Container(
      color: AppColors.secondary,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.accent,
              child: Text(
                participant.identity[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              participant.identity,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceCallUI(LiveKitService livekitService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Room avatar
          CircleAvatar(
            radius: 60,
            backgroundColor: AppColors.accent,
            child: Text(
              (widget.room.name ?? 'R')[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 48,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Room name
          Text(
            widget.room.name ?? 'Voice Call',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          
          // Status
          Text(
            '${livekitService.remoteParticipants.length + 1} in call',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Participant avatars
          Wrap(
            spacing: 8,
            children: livekitService.remoteParticipants.map((p) {
              return CircleAvatar(
                backgroundColor: AppColors.tertiary,
                child: Text(
                  p.identity[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.room.name ?? 'Call',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.isVideo ? 'Video Call' : 'Voice Call',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() => _isSpeakerOn = !_isSpeakerOn);
                // Toggle speaker
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(LiveKitService livekitService) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mute
            _buildControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: _isMuted ? 'Unmute' : 'Mute',
              isActive: _isMuted,
              onPressed: () async {
                await livekitService.toggleMute();
                setState(() => _isMuted = !_isMuted);
              },
            ),
            
            // Video
            _buildControlButton(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              label: _isVideoEnabled ? 'Video Off' : 'Video On',
              isActive: !_isVideoEnabled,
              onPressed: () async {
                await livekitService.toggleVideo();
                setState(() => _isVideoEnabled = !_isVideoEnabled);
              },
            ),
            
            // Flip camera
            if (_isVideoEnabled)
              _buildControlButton(
                icon: Icons.flip_camera_ios,
                label: 'Flip',
                onPressed: () async {
                  await livekitService.switchCamera();
                  setState(() => _isFrontCamera = !_isFrontCamera);
                },
              ),
            
            // Screen share
            _buildControlButton(
              icon: Icons.screen_share,
              label: 'Share',
              onPressed: () async {
                await livekitService.toggleScreenShare();
              },
            ),
            
            // End call
            _buildControlButton(
              icon: Icons.call_end,
              label: 'End',
              backgroundColor: AppColors.error,
              onPressed: () async {
                await livekitService.disconnect();
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    Color? backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: backgroundColor ?? 
              (isActive ? AppColors.textSecondary : AppColors.secondary),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
