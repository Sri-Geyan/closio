import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api_service.dart';

class WebRTCService {
  late IO.Socket _socket;
  final String userId;
  final String roomId;
  
  final Map<String, RTCPeerConnection> _peerConnections = {};
  MediaStream? _localStream;
  MediaStream? get localStream => _localStream;
  final Function(String, MediaStream)? onAddRemoteStream;
  final Function(String)? onRemoveRemoteStream;

  WebRTCService({
    required this.userId, 
    required this.roomId,
    this.onAddRemoteStream,
    this.onRemoveRemoteStream,
  }) {
    _initWebRTC();
  }

  Future<void> _initWebRTC() async {
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    _initSocket();
  }

  void _initSocket() {
    _socket = IO.io(ApiService.backendUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build()
    );
    
    _socket.connect();
    
    _socket.onConnect((_) {
      _socket.emit('join_voice_room', [roomId, userId]);
    });

    _socket.on('user_joined_voice', (data) async {
      if (data['userId'] != null && data['userId'] != userId) {
        debugPrint('User joined voice room: ${data['userId']}');
        await _createPeerConnection(data['userId'], isCaller: true);
      }
    });

    _socket.on('user_left_voice', (data) {
      if (data['userId'] != null) {
        debugPrint('User left voice room: ${data['userId']}');
        _peerConnections[data['userId']]?.close();
        _peerConnections.remove(data['userId']);
        if (onRemoveRemoteStream != null) onRemoveRemoteStream!(data['userId']);
      }
    });

    _socket.on('webrtc_offer', (data) async {
      if (data['targetId'] == userId) {
        debugPrint('Received WebRTC offer from ${data['callerId']}');
        final pc = await _createPeerConnection(data['callerId'], isCaller: false);
        await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        _socket.emit('webrtc_answer', {
          'targetId': data['callerId'],
          'answererId': userId,
          'sdp': answer.sdp,
          'type': answer.type,
        });
      }
    });

    _socket.on('webrtc_answer', (data) async {
      if (data['targetId'] == userId) {
        debugPrint('Received WebRTC answer from ${data['answererId']}');
        final pc = _peerConnections[data['answererId']];
        if (pc != null) {
          await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
        }
      }
    });

    _socket.on('webrtc_ice_candidate', (data) async {
      if (data['targetId'] == userId) {
        debugPrint('Received ICE candidate from ${data['senderId']}');
        final pc = _peerConnections[data['senderId']];
        if (pc != null) {
          await pc.addCandidate(RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ));
        }
      }
    });
  }

  Future<RTCPeerConnection> _createPeerConnection(String remoteUserId, {required bool isCaller}) async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    });

    _peerConnections[remoteUserId] = pc;

    pc.onIceCandidate = (candidate) {
      _socket.emit('webrtc_ice_candidate', {
        'targetId': remoteUserId,
        'senderId': userId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onAddStream = (stream) {
      if (onAddRemoteStream != null) {
        onAddRemoteStream!(remoteUserId, stream);
      }
    };

    if (_localStream != null) {
      pc.addStream(_localStream!);
    }

    if (isCaller) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      _socket.emit('webrtc_offer', {
        'targetId': remoteUserId,
        'callerId': userId,
        'sdp': offer.sdp,
        'type': offer.type,
      });
    }

    return pc;
  }

  void leaveRoom() {
    _socket.emit('leave_voice_room', [roomId, userId]);
    _socket.disconnect();
    _socket.dispose();
    
    for (final pc in _peerConnections.values) {
      pc.close();
    }
    _peerConnections.clear();
    
    _localStream?.dispose();
    _localStream = null;
  }
}
