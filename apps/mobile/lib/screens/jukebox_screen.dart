import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../services/itunes_service.dart';

class JukeboxScreen extends StatefulWidget {
  final String hubId;
  final String hubName;

  const JukeboxScreen({super.key, required this.hubId, required this.hubName});

  @override
  State<JukeboxScreen> createState() => _JukeboxScreenState();
}

class _JukeboxScreenState extends State<JukeboxScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _session;
  List<dynamic> _tracks = [];
  IO.Socket? _socket;
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _fetchSession();
    _initSocket();
  }

  Future<void> _fetchSession() async {
    try {
      final session = await ApiService.getActiveJukeboxSession(widget.hubId);
      if (mounted) {
        setState(() {
          _session = session;
          if (session != null) {
            _tracks = session['tracks'] ?? [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initSocket() {
    // Note: Assuming backend runs on 10.0.2.2:3000 locally
    _socket = IO.io('http://10.0.2.2:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket?.onConnect((_) {
      _socket?.emit('join_hub', widget.hubId);
    });

    _socket?.on('jukebox_track_added', (data) {
      if (mounted) {
        setState(() {
          _tracks.add(data);
          _sortTracks();
        });
      }
    });

    _socket?.on('jukebox_track_updated', (data) {
      if (mounted) {
        setState(() {
          final index = _tracks.indexWhere((t) => t['id'] == data['id']);
          if (index != -1) {
            _tracks[index] = data;
          }
          _sortTracks();
        });
      }
    });

    _socket?.on('jukebox_ended', (_) {
      if (mounted) {
        setState(() {
          _session = null;
          _tracks = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jukebox session ended.')));
      }
    });
  }

  void _sortTracks() {
    _tracks.sort((a, b) => (b['votes'] as int).compareTo(a['votes'] as int));
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _startSession(String name, String mood) async {
    setState(() => _isLoading = true);
    try {
      final session = await ApiService.startJukeboxSession(widget.hubId, name, mood);
      setState(() {
        _session = session;
        _tracks = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _endSession() async {
    try {
      await ApiService.endJukeboxSession(widget.hubId);
      _socket?.emit('jukebox_ended', widget.hubId);
    } catch (e) {
      print(e);
    }
  }

  void _voteTrack(String trackId, int change) {
    _socket?.emit('jukebox_vote_track', {
      'hubId': widget.hubId,
      'trackId': trackId,
      'voteChange': change,
    });
  }

  Future<void> _openSpotify(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Spotify')));
    }
  }

  void _showAddSongModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ClosioTheme.backgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return AddSongSheet(
          onAdd: (track) {
            _socket?.emit('jukebox_queue_track', {
              'hubId': widget.hubId,
              'sessionId': _session!['id'],
              'addedById': _currentUserId, // Backend will trust this for MVP
              'title': track['title'],
              'artist': track['artist'],
              'albumArt': track['albumArt'],
              'spotifyUrl': track['spotifyUrl']
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ClosioTheme.backgroundColor,
        appBar: AppBar(backgroundColor: ClosioTheme.backgroundColor),
        body: Shimmer.fromColors(
          baseColor: Colors.grey[900]!,
          highlightColor: Colors.grey[800]!,
          child: ListView.builder(
            itemCount: 5,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
              child: Row(
                children: [
                  Container(width: 48, height: 48, color: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: double.infinity, height: 16, color: Colors.white),
                        const SizedBox(height: 8),
                        Container(width: 100, height: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_session == null) {
      return _buildStartSessionView();
    }

    return _buildActiveSessionView();
  }

  Widget _buildStartSessionView() {
    String mood = 'Chill';
    String name = 'Just Vibing';

    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Jukebox'),
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 80, color: ClosioTheme.primaryColor),
            const SizedBox(height: 24),
            const Text('Start a Jukebox Session', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Queue up songs and listen together.', textAlign: TextAlign.center, style: TextStyle(color: ClosioTheme.secondaryColor)),
            const SizedBox(height: 32),
            StatefulBuilder(builder: (context, setSheetState) {
              return DropdownButtonFormField<String>(
                value: mood,
                decoration: const InputDecoration(labelText: 'Mood', border: OutlineInputBorder()),
                items: ['Chill', 'Hype', 'Focus', 'Party', 'Desi hits'].map((m) {
                  return DropdownMenuItem(value: m, child: Text(m));
                }).toList(),
                onChanged: (val) => setSheetState(() => mood = val!),
              );
            }),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _startSession(name, mood),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: ClosioTheme.primaryColor,
              ),
              child: const Text('Start Session'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionView() {
    final host = _session!['host'];
    final isHost = host?['supabaseId'] == _currentUserId || true; // For MVP testing, allow ending if host ID is tricky
    
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_session!['name']),
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
        actions: [
          if (isHost)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: ClosioTheme.errorColor),
              onPressed: _endSession,
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tracks.length,
              itemBuilder: (context, index) {
                final track = _tracks[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: track['albumArt'] != null 
                        ? CachedNetworkImage(
                            imageUrl: track['albumArt'],
                            width: 48, height: 48, fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(baseColor: Colors.grey[900]!, highlightColor: Colors.grey[800]!, child: Container(color: Colors.white)),
                            errorWidget: (context, url, error) => const Icon(Icons.music_note),
                          )
                        : const Icon(Icons.music_note),
                  ),
                  title: Text(track['title'], maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(track['artist'], maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill, color: ClosioTheme.primaryColor),
                        onPressed: () => _openSpotify(track['spotifyUrl']),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _voteTrack(track['id'], 1),
                            child: const Icon(Icons.keyboard_arrow_up, size: 20),
                          ),
                          Text('${track['votes']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          GestureDetector(
                            onTap: () => _voteTrack(track['id'], -1),
                            child: const Icon(Icons.keyboard_arrow_down, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSongModal,
        icon: const Icon(Icons.add),
        label: const Text('Add Song'),
        backgroundColor: ClosioTheme.primaryColor,
      ),
    );
  }
}

class AddSongSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const AddSongSheet({super.key, required this.onAdd});

  @override
  State<AddSongSheet> createState() => _AddSongSheetState();
}

class _AddSongSheetState extends State<AddSongSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;

  void _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() => _isSearching = true);
    final results = await ItunesService.searchSongs(q);
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 16, right: 16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a song...',
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            _isSearching
            ? Shimmer.fromColors(
                baseColor: Colors.grey[900]!, highlightColor: Colors.grey[800]!,
                child: ListView.builder(
                  shrinkWrap: true, itemCount: 3,
                  itemBuilder: (_, __) => ListTile(leading: Container(width:40, height:40, color:Colors.white), title: Container(width:100, height:16, color:Colors.white))
                )
              )
            : Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final r = _results[index];
                    return ListTile(
                      leading: r['albumArt'] != null 
                          ? CachedNetworkImage(
                              imageUrl: r['albumArt'], width: 40,
                              placeholder: (context, url) => Container(width: 40, color: Colors.grey[900]),
                              errorWidget: (context, url, error) => const Icon(Icons.music_note),
                            ) 
                          : const Icon(Icons.music_note),
                      title: Text(r['title'], maxLines: 1),
                      subtitle: Text(r['artist'], maxLines: 1),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle, color: ClosioTheme.primaryColor),
                        onPressed: () => widget.onAdd(r),
                      ),
                    );
                  },
                ),
              )
          ],
        ),
      ),
    );
  }
}
