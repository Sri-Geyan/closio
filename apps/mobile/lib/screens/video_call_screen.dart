import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../theme.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  
  const VideoCallScreen({super.key, required this.roomId});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  
  IO.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _remoteSocketId;
  final String _userId = Supabase.instance.client.auth.currentUser!.id;

  bool _inCall = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _connectSocket();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _openUserMedia();
  }

  Future<void> _openUserMedia() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'video': true,
      'audio': true,
    });
    _localRenderer.srcObject = stream;
    _localStream = stream;
  }

  void _connectSocket() {
    _socket = IO.io(ApiService.backendUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket?.onConnect((_) {
      _socket?.emit('join_voice_room', [widget.roomId, _userId]);
    });

    _socket?.on('user_joined_voice', (data) async {
      _remoteSocketId = data['socketId'];
      await _createPeerConnection();
      _inCall = true;
      if (mounted) setState(() {});
      await _createOffer();
    });

    _socket?.on('webrtc_offer', (data) async {
      _remoteSocketId = data['socketId'];
      await _createPeerConnection();
      _inCall = true;
      if (mounted) setState(() {});
      
      final offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
      await _peerConnection?.setRemoteDescription(offer);
      
      final answer = await _peerConnection?.createAnswer();
      await _peerConnection?.setLocalDescription(answer!);
      
      _socket?.emit('webrtc_answer', {
        'targetSocketId': _remoteSocketId,
        'answer': answer?.toMap(),
        'answererId': _userId,
      });
    });

    _socket?.on('webrtc_answer', (data) async {
      final answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
      await _peerConnection?.setRemoteDescription(answer);
    });

    _socket?.on('webrtc_ice_candidate', (data) {
      final candidateMap = data['candidate'];
      final candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      _peerConnection?.addCandidate(candidate);
    });

    _socket?.on('user_left_voice', (data) {
      _endCall();
    });
  }

  Future<void> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };
    _peerConnection = await createPeerConnection(configuration);

    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate != null && _remoteSocketId != null) {
        _socket?.emit('webrtc_ice_candidate', {
          'targetSocketId': _remoteSocketId,
          'candidate': candidate.toMap(),
        });
      }
    };

    _peerConnection?.onAddStream = (stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {});
    };

    if (_localStream != null) {
      _peerConnection?.addStream(_localStream!);
    }
  }

  Future<void> _createOffer() async {
    final offer = await _peerConnection?.createOffer();
    await _peerConnection?.setLocalDescription(offer!);
    _socket?.emit('webrtc_offer', {
      'targetSocketId': _remoteSocketId,
      'offer': offer?.toMap(),
      'callerId': _userId,
    });
  }

  void _endCall() {
    _peerConnection?.close();
    _peerConnection = null;
    _remoteRenderer.srcObject = null;
    _remoteSocketId = null;
    _inCall = false;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _socket?.emit('leave_voice_room', [widget.roomId, _userId]);
    _socket?.dispose();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Hub Call'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (_inCall)
            Positioned.fill(
              child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            )
          else
            const Center(child: Text('Waiting for others to join...', style: TextStyle(color: Colors.white, fontSize: 18))),
          Positioned(
            right: 20,
            top: 20,
            width: 100,
            height: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: Colors.grey[900],
                child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
