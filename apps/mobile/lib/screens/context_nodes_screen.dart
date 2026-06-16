import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'components/glass_container.dart';
import '../utils/marker_generator.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ContextNodesScreen extends StatefulWidget {
  const ContextNodesScreen({super.key});

  @override
  State<ContextNodesScreen> createState() => _ContextNodesScreenState();
}

class _ContextNodesScreenState extends State<ContextNodesScreen> {
  GoogleMapController? mapController;
  LatLng _center = const LatLng(37.7749, -122.4194); // Default to SF
  bool _locationPermissionGranted = false;
  Set<Marker> _markers = {};
  StreamSubscription<Position>? _positionStreamSubscription;
  BitmapDescriptor? _customIcon;
  
  List<dynamic> _activeLocations = [];
  Map<String, BitmapDescriptor> _userPinsCache = {};
  IO.Socket? _socket;
  Timer? _locationUpdateTimer;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _initCustomMarker();
    _requestLocationPermission();
    _fetchLocationsAndConnectSocket();
  }

  Future<void> _fetchLocationsAndConnectSocket() async {
    try {
      final locs = await ApiService.getActiveLocations();
      if (!mounted) return;
      setState(() {
        _activeLocations = locs;
      });
      await _cachePinsForLocations();
      _updateAllMarkers();

      // Setup Socket
      _socket = IO.io(ApiService.backendUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build()
      );
      
      _socket!.connect();
      _socket!.onConnect((_) {
        // Join all unique hubs from locations
        final uniqueHubIds = _activeLocations.map((l) => l['hubId'] as String).toSet();
        for (var hId in uniqueHubIds) {
          _socket!.emit('join_hub', hId);
        }
      });

      _socket!.on('location_update', (data) {
        if (!mounted) return;
        final userId = data['userId'];
        final lat = data['latitude'];
        final lng = data['longitude'];
        
        // Find existing location in list
        final index = _activeLocations.indexWhere((l) => l['userId'] == userId);
        if (index != -1) {
          setState(() {
            _activeLocations[index]['latitude'] = lat;
            _activeLocations[index]['longitude'] = lng;
          });
          _updateAllMarkers();
        } else {
          // New person sharing
          _fetchLocationsAndConnectSocket();
        }
      });
    } catch (e) {
      debugPrint('Error fetching locations: $e');
    }
  }

  Future<void> _cachePinsForLocations() async {
    for (var loc in _activeLocations) {
      final userId = loc['userId'];
      final avatarUrl = loc['user']['avatarUrl'];
      if (!_userPinsCache.containsKey(userId)) {
        final username = loc['user']['username'] ?? 'User';
        final icon = await MarkerGenerator.createCustomMarker(
          avatarUrl ?? '',
          username
        );
        _userPinsCache[userId] = icon;
      }
    }
  }

  Future<void> _initCustomMarker() async {
    // We mock the user's profile picture for now using an online placeholder
    final icon = await MarkerGenerator.createCustomMarker('', 'Me');
    if (mounted) {
      setState(() {
        _customIcon = icon;
      });
      if (_locationPermissionGranted) {
        _updateAllMarkers();
      }
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    if (!mounted) return;
    setState(() {
      _locationPermissionGranted = true;
    });

    Position position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _center = LatLng(position.latitude, position.longitude);
      _updateAllMarkers();
    });

    if (mapController != null) {
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(_center, 14.0));
    }

    _positionStreamSubscription = Geolocator.getPositionStream().listen((Position position) {
      if (mounted) {
        setState(() {
          _center = LatLng(position.latitude, position.longitude);
          _updateAllMarkers();
        });
      }
    });
  }

  void _updateAllMarkers() {
    Set<Marker> newMarkers = {};
    
    // My location
    if (_customIcon != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: _center,
          icon: _customIcon!,
          anchor: const Offset(0.5, 1.0),
        )
      );
    }

    // Friends' locations
    for (var loc in _activeLocations) {
      final userId = loc['userId'];
      final icon = _userPinsCache[userId];
      if (icon != null) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('user_$userId'),
            position: LatLng(loc['latitude'].toDouble(), loc['longitude'].toDouble()),
            icon: icon,
            anchor: const Offset(0.5, 1.0),
          )
        );
      }
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _toggleSharing() async {
    if (_isSharing) {
      // Stop sharing
      await ApiService.stopSharingLocationAll();
      _locationUpdateTimer?.cancel();
      setState(() {
        _isSharing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stopped sharing location.')));
    } else {
      // Start sharing
      await ApiService.shareLocationAll(_center.latitude, _center.longitude, durationMinutes: 60);
      setState(() {
        _isSharing = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing location for 1 hour.')));
      
      // Setup live broadcast every 5 seconds
      _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_socket != null && _socket!.connected) {
          // Since we share to all hubs, we iterate unique hub IDs we're part of
          // For MVP, we broadcast to hubs in our _activeLocations list
          final uniqueHubIds = _activeLocations.map((l) => l['hubId'] as String).toSet();
          for (var hId in uniqueHubIds) {
            _socket!.emit('update_location', {
              'hubId': hId,
              'userId': 'me', // backend doesn't check this perfectly on socket yet, it relies on client
              'latitude': _center.latitude,
              'longitude': _center.longitude
            });
          }
        }
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController!.setMapStyle(_mapStyle);
    if (_locationPermissionGranted) {
       mapController!.animateCamera(CameraUpdate.newLatLngZoom(_center, 14.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 14.0,
            ),
            myLocationEnabled: false, // Turned off normal blue dot
            myLocationButtonEnabled: _locationPermissionGranted,
            zoomControlsEnabled: false,
            markers: _markers,
          ),
          
          // Immersive Header Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor,
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                  ]
                )
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Homies Maps', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Share Location Bottom Bar
          Positioned(
            bottom: 120,
            left: 24,
            right: 24,
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              borderRadius: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isSharing ? Colors.red.withOpacity(0.2) : ClosioTheme.primaryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isSharing ? Icons.location_on : Icons.my_location,
                          color: _isSharing ? Colors.red : ClosioTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSharing ? 'Sharing Location' : 'Live Tracking',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                          Text(
                            _isSharing ? 'Visible to all Hubs' : 'Off',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _toggleSharing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSharing ? Colors.red : ClosioTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(_isSharing ? 'Stop' : 'Share', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // Dark Map Style JSON string
  final String _mapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#1d2c4d"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#8ec3b9"
        }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1a3646"
        }
      ]
    },
    {
      "featureType": "administrative.country",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#4b6878"
        }
      ]
    },
    {
      "featureType": "administrative.land_parcel",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#64779e"
        }
      ]
    },
    {
      "featureType": "administrative.province",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#4b6878"
        }
      ]
    },
    {
      "featureType": "landscape.man_made",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#334e87"
        }
      ]
    },
    {
      "featureType": "landscape.natural",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#023e58"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#283d6a"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#6f9ba5"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1d2c4d"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry.fill",
      "stylers": [
        {
          "color": "#023e58"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#3C7680"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#304a7d"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#98a5be"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1d2c4d"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#2c6675"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#255763"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#b0d5ce"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#023e58"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#98a5be"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1d2c4d"
        }
      ]
    },
    {
      "featureType": "transit.line",
      "elementType": "geometry.fill",
      "stylers": [
        {
          "color": "#283d6a"
        }
      ]
    },
    {
      "featureType": "transit.station",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#3a4762"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#0e1626"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#4e6d70"
        }
      ]
    }
  ]
  ''';
}
