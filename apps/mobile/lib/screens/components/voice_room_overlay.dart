import 'package:flutter/material.dart';
import '../../services/webrtc_service.dart';
import '../../theme.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VoiceRoomOverlay extends StatefulWidget {
  final WebRTCService webrtcService;
  final VoidCallback onLeave;

  const VoiceRoomOverlay({
    super.key,
    required this.webrtcService,
    required this.onLeave,
  });

  @override
  State<VoiceRoomOverlay> createState() => _VoiceRoomOverlayState();
}

class _VoiceRoomOverlayState extends State<VoiceRoomOverlay> {
  bool _isMuted = false;
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  @override
  void initState() {
    super.initState();
    // Since we handle audio, flutter_webrtc automatically plays the audio tracks attached to the stream.
    // Video renderers are technically optional for audio-only, but we can use them to display audio visualization or just track who is streaming.
    
    // Listen for new streams from the service
    /* 
    widget.webrtcService.onAddRemoteStream = (userId, stream) {
       // Optional: setup renderer if video was supported
       setState(() {});
    };
    */
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    if (widget.webrtcService.localStream != null) {
      widget.webrtcService.localStream!.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade900,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volume_up, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Voice Room Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tap to manage participants',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isMuted ? Icons.mic_off : Icons.mic,
              color: _isMuted ? Colors.red.shade300 : Colors.white,
            ),
            onPressed: _toggleMute,
          ),
          TextButton(
            onPressed: widget.onLeave,
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

FontWeight eitherBoldOrNot(FontWeight fw) {
  return fw;
}
