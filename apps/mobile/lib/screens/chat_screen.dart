import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../services/webrtc_service.dart';
import 'hub_settings_screen.dart';
import 'event_detail_screen.dart';
import 'components/voice_room_overlay.dart';
import 'media_viewer_screen.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class ChatScreen extends StatefulWidget {
  final String hubId;
  final String hubName;
  final bool isEmbedded;
  
  const ChatScreen({
    super.key, 
    required this.hubId, 
    required this.hubName,
    this.isEmbedded = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late IO.Socket _socket;
  String? _myUserId;
  bool _isVanishMode = false;
  bool _voiceRoomActive = false;
  WebRTCService? _webRTCService;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _initSocket();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = await ApiService.getUserProfile();
      if (mounted) {
        setState(() {
          _myUserId = user['id'];
        });
        await context.read<AppStateProvider>().fetchMessages(widget.hubId);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat data: $e')),
        );
      }
    }
  }

  void _initSocket() {
    _socket = IO.io(ApiService.backendUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build()
    );
    
    _socket.connect();
    
    _socket.onConnect((_) {
      _socket.emit('join_hub', widget.hubId);
    });

    _socket.on('new_message', (data) {
      if (mounted) {
        context.read<AppStateProvider>().addMessage(widget.hubId, data);
        _scrollToBottom();
      }
    });

    _socket.on('poll_updated', (data) {
      if (mounted) {
        context.read<AppStateProvider>().updateMessage(widget.hubId, data);
      }
    });
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage({String? text, String? mediaUrl, String type = 'TEXT', int? vanishTtl}) {
    if (text == null && mediaUrl == null) return;
    if (_myUserId == null) return;

    final ttl = _isVanishMode ? (vanishTtl ?? 60) : vanishTtl;

    _socket.emit('send_message', {
      'hubId': widget.hubId,
      'senderId': _myUserId,
      'text': text,
      'mediaUrl': mediaUrl,
      'type': type,
      'vanishTtl': ttl,
    });
    _messageController.clear();
  }

  Future<void> _summariseChat(List<dynamic> messages) async {
    final textMsgs = messages
        .where((m) => m['type'] == 'TEXT' && m['vanishTtl'] == null)
        .map((m) => '${m['sender']?['username'] ?? 'User'}: ${m['text']}')
        .join('\n');
        
    if (textMsgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough messages to summarise.'))
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: ClosioTheme.primaryColor),
            SizedBox(width: 8),
            Text('AI Summary'),
          ],
        ),
        content: FutureBuilder(
          future: ApiService.summariseChat(textMsgs),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            } else if (snapshot.hasError) {
              return Text('Failed to generate summary: ${snapshot.error}');
            } else {
              final summary = snapshot.data as Map<String, dynamic>;
              final bullets = summary['summary'] as List<dynamic>;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(b.toString()),
                )).toList(),
              );
            }
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      try {
        final file = File(pickedFile.path);
        final fileExt = pickedFile.path.split('.').last;
        final fileName = '${DateTime.now().toIso8601String()}_${_myUserId}.$fileExt';
        
        await Supabase.instance.client.storage
            .from('images')
            .upload(fileName, file);
            
        final imageUrl = Supabase.instance.client.storage
            .from('images')
            .getPublicUrl(fileName);
            
        _sendMessage(mediaUrl: imageUrl, type: 'IMAGE');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: $e')),
          );
        }
      }
    }
  }

  void _showShareEventDialog() async {
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final events = await ApiService.getHubEvents(widget.hubId);
      if (mounted) Navigator.pop(context); // pop progress indicator

      if (events.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No upcoming events found to share.')),
          );
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Share Event'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return ListTile(
                      title: Text(event['title'] ?? 'Event'),
                      subtitle: Text(event['date'] ?? ''),
                      onTap: () {
                        Navigator.pop(context);
                        final eventJson = jsonEncode({
                          'id': event['id'],
                          'title': event['title'],
                          'date': event['date'],
                          'time': event['time'],
                          'location': event['location']
                        });
                        _sendMessage(text: eventJson, type: 'EVENT');
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load events: $e')),
        );
      }
    }
  }

  void _showShareSplitDialog() async {
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final participations = await ApiService.getUserSplits();
      if (mounted) Navigator.pop(context);

      final hubSplits = participations
          .where((p) => p['split']?['event']?['hubId'] == widget.hubId)
          .map((p) => p['split'])
          .toList();

      if (hubSplits.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No splits found in this Hub to share.')),
          );
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Share Split'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: hubSplits.length,
                  itemBuilder: (context, index) {
                    final split = hubSplits[index];
                    final eventTitle = split?['event']?['title'] ?? 'Split';
                    return ListTile(
                      title: Text(eventTitle),
                      subtitle: Text('\$${split['totalAmount']} • ${split['type']}'),
                      onTap: () {
                        Navigator.pop(context);
                        final splitJson = jsonEncode({
                          'id': split['id'],
                          'totalAmount': split['totalAmount'],
                          'type': split['type'],
                          'eventTitle': eventTitle
                        });
                        _sendMessage(text: splitJson, type: 'SPLIT');
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load splits: $e')),
        );
      }
    }
  }

  void _showCreatePollDialog() {
    final questionController = TextEditingController();
    final opt1Controller = TextEditingController();
    final opt2Controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Poll'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              TextField(
                controller: opt1Controller,
                decoration: const InputDecoration(labelText: 'Option 1'),
              ),
              TextField(
                controller: opt2Controller,
                decoration: const InputDecoration(labelText: 'Option 2'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final q = questionController.text.trim();
                final o1 = opt1Controller.text.trim();
                final o2 = opt2Controller.text.trim();

                if (q.isNotEmpty && o1.isNotEmpty && o2.isNotEmpty) {
                  Navigator.pop(context);
                  final pollJson = jsonEncode({
                    'question': q,
                    'options': [
                      {'text': o1, 'votes': []},
                      {'text': o2, 'votes': []}
                    ]
                  });
                  _sendMessage(text: pollJson, type: 'POLL');
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ClosioTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo,
                  label: 'Photo',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.event,
                  label: 'Share Event',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _showShareEventDialog();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.receipt_long,
                  label: 'Share Split',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    _showShareSplitDialog();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.poll,
                  label: 'Create Poll',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePollDialog();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.location_on,
                  label: 'Meet Here',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _sendMessage(text: 'Meet here! 📍 Downtown Central', type: 'LOCATION');
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.mic,
                  label: 'Voice Room',
                  color: Colors.purple.shade300,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _voiceRoomActive = true;
                      _webRTCService = WebRTCService(
                        userId: _myUserId ?? '',
                        roomId: widget.hubId,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 28,
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(dynamic msg) {
    final type = msg['type'] ?? 'TEXT';
    final text = msg['text'] ?? '';

    switch (type) {
      case 'IMAGE':
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaViewerScreen(
                  imageUrl: msg['mediaUrl'],
                  hubId: widget.hubId,
                  hubName: widget.hubName,
                ),
              ),
            );
          },
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: msg['mediaUrl'],
                fit: BoxFit.cover,
                placeholder: (context, url) => const SizedBox(
                  width: 200, height: 200, 
                  child: Center(child: CircularProgressIndicator(color: ClosioTheme.primaryColor)),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image),
              ),
            ),
          ),
        );
      case 'EVENT':
        try {
          final eventData = jsonDecode(text);
          return Card(
            color: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'EVENT INVITATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    eventData['title'] ?? 'Event',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${eventData['date']} • ${eventData['time'] ?? 'All Day'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (eventData['location'] != null && eventData['location'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '📍 ${eventData['location']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventDetailScreen(event: eventData),
                          ),
                        );
                      },
                      child: const Text('View details & RSVP', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        } catch (_) {
          return const Text('[Invalid Event Card]');
        }
      case 'SPLIT':
        try {
          final splitData = jsonDecode(text);
          return Card(
            color: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.green.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'SPLIT BILL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    splitData['eventTitle'] ?? 'Split bill',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total: \$${splitData['totalAmount']}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () {
                        // For splits, they can go to the splits tab in HubHomeScreen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Swipe to Splits tab to view details.')),
                        );
                      },
                      child: const Text('View Split Details', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        } catch (_) {
          return const Text('[Invalid Split Card]');
        }
      case 'POLL':
        try {
          final pollData = jsonDecode(text);
          final question = pollData['question'] ?? 'Poll';
          final List<dynamic> options = pollData['options'] ?? [];
          
          int totalVotes = 0;
          for (var opt in options) {
            final votesList = opt['votes'] as List<dynamic>? ?? [];
            totalVotes += votesList.length;
          }

          return Card(
            color: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orange.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.poll, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'HUB POLL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(options.length, (optIdx) {
                    final opt = options[optIdx];
                    final optText = opt['text'] ?? '';
                    final List<dynamic> votes = opt['votes'] as List<dynamic>? ?? [];
                    final isMyVote = votes.contains(_myUserId);
                    
                    final double pct = totalVotes == 0 ? 0.0 : votes.length / totalVotes;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () {
                          if (_myUserId != null) {
                            _socket.emit('vote_poll', {
                              'messageId': msg['id'],
                              'optionIndex': optIdx,
                              'userId': _myUserId,
                            });
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  optText,
                                  style: TextStyle(
                                    fontWeight: isMyVote ? FontWeight.bold : FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${votes.length} votes',
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                color: isMyVote ? Colors.orange : Colors.orange.shade200,
                                backgroundColor: Colors.grey.shade100,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        } catch (_) {
          return const Text('[Invalid Poll Card]');
        }
      case 'SPORT_EVENT':
        try {
          final sportData = jsonDecode(text);
          return Card(
            color: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.indigo.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sports, color: Colors.indigo.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '${sportData['sportType']?.toUpperCase() ?? 'SPORT'} EVENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sportData['title'] ?? 'Match',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${sportData['date']} • 📍 ${sportData['location'] ?? 'Venue TBA'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (sportData['sportDetails'] != null && sportData['sportDetails']['weather'] != null) ...[
                     const SizedBox(height: 4),
                     Text('☁️ ${sportData['sportDetails']['weather']['temp']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                  const SizedBox(height: 8),

                ],
              ),
            ),
          );
        } catch (_) {
          return const Text('[Invalid Sport Event Card]');
        }
      case 'LOCATION':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_pin, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
            ],
          ),
        );
      default:
        return Text(
          text,
          style: TextStyle(
            color: msg['senderId'] == _myUserId ? ClosioTheme.onPrimaryColor : Colors.black87,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final messages = appState.getMessages(widget.hubId);
    final isLoadingMessages = appState.isLoadingMessages(widget.hubId);

    return Scaffold(
      backgroundColor: _isVanishMode ? Colors.grey.shade900 : ClosioTheme.backgroundColor,
      appBar: widget.isEmbedded ? null : AppBar(
        backgroundColor: _isVanishMode ? Colors.grey.shade900 : ClosioTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _isVanishMode ? Colors.white : Colors.white),
        title: Text(widget.hubName, style: TextStyle(fontWeight: FontWeight.bold, color: _isVanishMode ? Colors.white : Colors.white)),
        actions: [
          Row(
            children: [
              Text('Vanish', style: TextStyle(fontSize: 12, color: _isVanishMode ? Colors.white : Colors.white70)),
              Switch(
                value: _isVanishMode,
                onChanged: (val) {
                  setState(() => _isVanishMode = val);
                },
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.auto_awesome, color: _isVanishMode ? Colors.white : Colors.amber),
            onPressed: () => _summariseChat(messages),
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: _isVanishMode ? Colors.white : Colors.white), 
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HubSettingsScreen(
                    hubId: widget.hubId,
                    hubName: widget.hubName,
                  ),
                ),
              ).then((leftHub) {
                if (leftHub == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              });
            },
          ),
        ],
      ),
      body: isLoadingMessages
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_voiceRoomActive && _webRTCService != null)
                  VoiceRoomOverlay(
                    webrtcService: _webRTCService!,
                    onLeave: () {
                      _webRTCService?.leaveRoom();
                      setState(() {
                        _voiceRoomActive = false;
                        _webRTCService = null;
                      });
                    },
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMine = msg['senderId'] == _myUserId;
                      final sender = msg['sender'];
                      final senderUsername = sender?['username'] ?? 'User';

                      // Handle vanish mode TTL locally for MVP
                      if (msg['vanishTtl'] != null) {
                        final created = DateTime.parse(msg['createdAt']);
                        final diff = DateTime.now().difference(created).inSeconds;
                        if (diff > msg['vanishTtl']) return const SizedBox.shrink();
                      }

                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Column(
                            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMine && senderUsername.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                                  child: Text(
                                    senderUsername,
                                    style: const TextStyle(fontSize: 11, color: ClosioTheme.secondaryColor, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isMine 
                                      ? ClosioTheme.primaryColor 
                                      : ClosioTheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
                                    bottomRight: isMine ? Radius.zero : const Radius.circular(16),
                                  ),
                                ),
                                child: _buildMessageContent(msg),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${DateTime.parse(msg['createdAt']).toLocal().hour}:${DateTime.parse(msg['createdAt']).toLocal().minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                                    ),
                                    if (isMine) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.done_all, size: 12, color: Colors.blue.shade300),
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: ClosioTheme.surfaceContainer)),
                    color: ClosioTheme.backgroundColor,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, color: ClosioTheme.secondaryColor),
                        onPressed: _showAttachmentMenu,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(color: _isVanishMode ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Message',
                            hintStyle: TextStyle(color: _isVanishMode ? Colors.grey : Colors.black54),
                            filled: true,
                            fillColor: _isVanishMode ? Colors.grey.shade800 : ClosioTheme.surfaceContainerLow,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onLongPress: () {
                          // Vanish Mode Quick Send
                          final txt = _messageController.text.trim();
                          if (txt.isNotEmpty) {
                            _sendMessage(text: txt, type: 'TEXT', vanishTtl: 60);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent as vanishing message (60s)')));
                          }
                        },
                        child: CircleAvatar(
                          backgroundColor: ClosioTheme.primaryColor,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: ClosioTheme.onPrimaryColor, size: 20),
                            onPressed: () {
                              final txt = _messageController.text.trim();
                              if (txt.isNotEmpty) {
                                _sendMessage(text: txt, type: 'TEXT');
                              }
                            },
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
}
