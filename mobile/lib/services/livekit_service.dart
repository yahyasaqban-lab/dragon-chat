import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

class LiveKitService extends ChangeNotifier {
  Room? _room;
  LocalParticipant? _localParticipant;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = false;
  bool _isScreenSharing = false;
  String? _error;
  
  Room? get room => _room;
  LocalParticipant? get localParticipant => _localParticipant;
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isScreenSharing => _isScreenSharing;
  String? get error => _error;
  
  List<RemoteParticipant> get remoteParticipants => 
      _room?.remoteParticipants.values.toList() ?? [];
  
  static const String defaultLiveKitUrl = 'wss://livekit.y7xyz.com';
  
  Future<bool> connect({
    required String url,
    required String token,
    bool enableVideo = false,
    bool enableAudio = true,
  }) async {
    try {
      _error = null;
      
      _room = Room();
      
      // Setup listeners
      _room!.addListener(_onRoomEvent);
      
      // Connect
      await _room!.connect(url, token);
      
      _localParticipant = _room!.localParticipant;
      _isConnected = true;
      
      // Enable media
      if (enableAudio) {
        await _localParticipant!.setMicrophoneEnabled(true);
        _isMuted = false;
      }
      
      if (enableVideo) {
        await _localParticipant!.setCameraEnabled(true);
        _isVideoEnabled = true;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  void _onRoomEvent() {
    notifyListeners();
  }
  
  Future<void> toggleMute() async {
    if (_localParticipant == null) return;
    
    _isMuted = !_isMuted;
    await _localParticipant!.setMicrophoneEnabled(!_isMuted);
    notifyListeners();
  }
  
  Future<void> toggleVideo() async {
    if (_localParticipant == null) return;
    
    _isVideoEnabled = !_isVideoEnabled;
    await _localParticipant!.setCameraEnabled(_isVideoEnabled);
    notifyListeners();
  }
  
  Future<void> toggleScreenShare() async {
    if (_localParticipant == null) return;
    
    _isScreenSharing = !_isScreenSharing;
    await _localParticipant!.setScreenShareEnabled(_isScreenSharing);
    notifyListeners();
  }
  
  Future<void> switchCamera() async {
    if (_localParticipant == null) return;
    
    final videoTrack = _localParticipant!.videoTrackPublications.firstOrNull?.track;
    if (videoTrack is LocalVideoTrack) {
      await videoTrack.switchCamera();
    }
  }
  
  Future<void> disconnect() async {
    if (_room != null) {
      await _room!.disconnect();
      _room!.removeListener(_onRoomEvent);
      _room = null;
    }
    
    _localParticipant = null;
    _isConnected = false;
    _isMuted = false;
    _isVideoEnabled = false;
    _isScreenSharing = false;
    
    notifyListeners();
  }
  
  // Get token from server
  Future<String?> getToken({
    required String roomName,
    required String participantName,
    String? serverUrl,
  }) async {
    try {
      // In production, fetch from your server
      // For now, this is a placeholder
      // You need to implement the token endpoint on your server
      
      // Example:
      // final response = await http.post(
      //   Uri.parse('$serverUrl/api/livekit/token'),
      //   body: jsonEncode({
      //     'roomName': roomName,
      //     'participantName': participantName,
      //   }),
      // );
      // return jsonDecode(response.body)['token'];
      
      throw UnimplementedError('Implement token fetching from your server');
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
