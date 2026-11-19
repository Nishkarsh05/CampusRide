import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:geolocator/geolocator.dart';

import '../models/campus_bus.dart';
import '../services/campusride_repository.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({super.key});

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  late Future<List<CampusBus>> _busesFuture = CampusRideRepository.instance
      .fetchBuses();
  final _searchController = TextEditingController();
  String _query = '';

  void _retry() => setState(() {
    _busesFuture = CampusRideRepository.instance.fetchBuses();
  });

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CampusBus>>(
      future: _busesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadError(
            message: 'Could not load bus routes.',
            onRetry: _retry,
          );
        }
        final allBuses = snapshot.data ?? [];
        final query = _query.trim().toLowerCase();
        final buses = allBuses.where((bus) {
          return bus.id.toLowerCase().contains(query) ||
              bus.busNumber.toLowerCase().contains(query) ||
              bus.driver.toLowerCase().contains(query);
        }).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search by route, bus, or driver',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Expanded(
              child: buses.isEmpty
                  ? const _EmptyState(
                      icon: Icons.alt_route_rounded,
                      title: 'No matching routes',
                      message: 'Try another route ID, bus number, or driver.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                      itemCount: buses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _BusCard(
                        bus: buses[index],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BusDetailsPage(bus: buses[index]),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class TimingsPage extends StatefulWidget {
  const TimingsPage({super.key});

  @override
  State<TimingsPage> createState() => _TimingsPageState();
}

class _TimingsPageState extends State<TimingsPage> {
  late Future<List<CampusBus>> _busesFuture = CampusRideRepository.instance
      .fetchBuses();

  void _retry() => setState(() {
    _busesFuture = CampusRideRepository.instance.fetchBuses();
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CampusBus>>(
      future: _busesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadError(
            message: 'Could not load the bus timings.',
            onRetry: _retry,
          );
        }
        final buses = snapshot.data ?? [];
        if (buses.isEmpty) {
          return const _EmptyState(
            icon: Icons.schedule_rounded,
            title: 'No timings available',
            message: 'Bus stop schedules will appear here when added.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          itemCount: buses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final bus = buses[index];
            return Card(
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: const Icon(Icons.directions_bus_rounded),
                ),
                title: Text(
                  '${bus.id} · ${bus.busNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${bus.stops.length} scheduled stops'),
                children: [
                  if (bus.stops.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No stops are listed for this bus.'),
                    )
                  else
                    ...bus.stops.map((stop) => _StopRow(stop: stop)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class BusDetailsPage extends StatelessWidget {
  const BusDetailsPage({super.key, required this.bus});

  final CampusBus bus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Route ${bus.id}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bus.busNumber,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  _InfoLine(
                    icon: Icons.person_outline_rounded,
                    label: 'Driver',
                    value: bus.driver,
                  ),
                  const SizedBox(height: 10),
                  _InfoLine(
                    icon: Icons.call_outlined,
                    label: 'Contact',
                    value: bus.mobile.isEmpty ? 'Not listed' : bus.mobile,
                  ),
                  const SizedBox(height: 10),
                  _InfoLine(
                    icon: Icons.alt_route_rounded,
                    label: 'Stops',
                    value: '${bus.stops.length} on this route',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Route stops',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (bus.stops.isEmpty)
            const _EmptyState(
              icon: Icons.signpost_outlined,
              title: 'No stops listed',
              message: 'This bus does not have stop data yet.',
            )
          else
            ...bus.stops.asMap().entries.map(
              (entry) => _TimelineStop(
                stop: entry.value,
                isLast: entry.key == bus.stops.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  late Future<List<CampusBus>> _busesFuture = CampusRideRepository.instance
      .fetchBuses();
  StreamSubscription<Position>? _positionSubscription;
  String? _selectedBusId;
  bool _sharingFromThisPhone = false;
  bool _startingShare = false;
  Timer? _scheduleClock;

  @override
  void initState() {
    super.initState();
    _scheduleClock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _retry() => setState(() {
    _busesFuture = CampusRideRepository.instance.fetchBuses();
  });

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _scheduleClock?.cancel();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _message('Turn on Location Services to share the bus position.');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _message('Allow location access for CampusRide in phone settings.');
      return false;
    }
    if (permission == LocationPermission.denied) {
      _message('Location permission was not granted.');
      return false;
    }
    return true;
  }

  Future<void> _startSharing() async {
    final busId = _selectedBusId;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (busId == null || userId == null) return;
    setState(() => _startingShare = true);
    try {
      if (!await _ensureLocationPermission()) return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await CampusRideRepository.instance.publishLocation(
        busId: busId,
        userId: userId,
        position: position,
      );
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 20,
            ),
          ).listen(
            (nextPosition) =>
                unawaited(_publishPosition(busId, userId, nextPosition)),
            onError: (_) {
              if (mounted) {
                _message('Location updates stopped. Check location access.');
              }
            },
          );
      if (mounted) setState(() => _sharingFromThisPhone = true);
    } on FirebaseException catch (error) {
      if (mounted) {
        _message(
          error.code == 'permission-denied'
              ? 'Firebase rules do not allow this account to share bus location.'
              : 'Could not send location to Firebase.',
        );
      }
    } catch (_) {
      if (mounted) _message('Could not start location sharing. Try again.');
    } finally {
      if (mounted) setState(() => _startingShare = false);
    }
  }

  Future<void> _publishPosition(
    String busId,
    String userId,
    Position position,
  ) async {
    try {
      await CampusRideRepository.instance.publishLocation(
        busId: busId,
        userId: userId,
        position: position,
      );
    } on FirebaseException catch (error) {
      if (mounted) {
        _message(
          error.code == 'permission-denied'
              ? 'Firebase rules blocked a location update.'
              : 'A bus location update failed.',
        );
      }
      await _positionSubscription?.cancel();
      if (mounted) setState(() => _sharingFromThisPhone = false);
    }
  }

  Future<void> _stopSharing() async {
    final busId = _selectedBusId;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (mounted) setState(() => _sharingFromThisPhone = false);
    if (busId == null) return;
    try {
      await CampusRideRepository.instance.stopSharing(busId);
    } on FirebaseException catch (error) {
      if (mounted && error.code == 'permission-denied') {
        _message(
          'Sharing stopped on this phone, but Firebase did not accept the status update.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CampusBus>>(
      future: _busesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadError(
            message: 'Could not load buses for tracking.',
            onRetry: _retry,
          );
        }
        final buses = snapshot.data ?? [];
        if (buses.isEmpty) {
          return const _EmptyState(
            icon: Icons.location_searching_rounded,
            title: 'No buses available',
            message: 'Add bus routes before using tracking.',
          );
        }
        final selectedId = _selectedBusId ?? buses.first.id;
        final selectedBus = buses.firstWhere(
          (bus) => bus.id == selectedId,
          orElse: () => buses.first,
        );
        if (_selectedBusId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedBusId == null) {
              setState(() => _selectedBusId = selectedBus.id);
            }
          });
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          children: [
            Text(
              'Choose a bus',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedBus.id,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.directions_bus_rounded),
              ),
              items: buses
                  .map(
                    (bus) => DropdownMenuItem(
                      value: bus.id,
                      child: Text('${bus.id} · ${bus.busNumber}'),
                    ),
                  )
                  .toList(),
              onChanged: _sharingFromThisPhone
                  ? null
                  : (value) => setState(() => _selectedBusId = value),
            ),
            const SizedBox(height: 16),
            _ScheduleEstimateCard(bus: selectedBus, now: DateTime.now()),
            const SizedBox(height: 16),
            StreamBuilder<DatabaseEvent>(
              stream: CampusRideRepository.instance.watchBusLocation(
                selectedBus.id,
              ),
              builder: (context, locationSnapshot) {
                if (locationSnapshot.hasError) {
                  return const _LocationCard(
                    title: 'Location unavailable',
                    message: 'Could not read this bus location from Firebase.',
                    live: false,
                  );
                }
                if (locationSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                return _buildLocationCard(
                  locationSnapshot.data?.snapshot.value,
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver location sharing',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _startingShare
                          ? null
                          : _sharingFromThisPhone
                          ? _stopSharing
                          : _startSharing,
                      icon: _startingShare
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _sharingFromThisPhone
                                  ? Icons.stop_circle_outlined
                                  : Icons.my_location_rounded,
                            ),
                      label: Text(
                        _startingShare
                            ? 'Starting…'
                            : _sharingFromThisPhone
                            ? 'Stop sharing from this phone'
                            : 'Share this phone’s location',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLocationCard(Object? rawValue) {
    if (rawValue is! Map) {
      return const _LocationCard(
        title: 'No live location yet',
        message: 'A driver can start sharing from the driver phone below.',
        live: false,
      );
    }
    final location = Map<String, dynamic>.from(rawValue);
    final latitude = (location['latitude'] as num?)?.toDouble();
    final longitude = (location['longitude'] as num?)?.toDouble();
    final updatedAt = (location['updatedAt'] as num?)?.toInt();
    final timestamp = updatedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(updatedAt);
    final isRecent =
        timestamp != null &&
        DateTime.now().difference(timestamp) < const Duration(seconds: 45) &&
        location['sharing'] == true;
    if (latitude == null || longitude == null) {
      return const _LocationCard(
        title: 'Location data is incomplete',
        message: 'The saved bus location does not contain coordinates.',
        live: false,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRecent
                      ? Icons.gps_fixed_rounded
                      : Icons.location_searching_rounded,
                  color: isRecent ? Colors.green.shade700 : Colors.blueGrey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isRecent
                        ? 'Bus is sharing live location'
                        : 'Last known location',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (isRecent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _LiveBusMap(latitude: latitude, longitude: longitude),
            const SizedBox(height: 14),
            Text('Latitude  ${latitude.toStringAsFixed(5)}'),
            const SizedBox(height: 5),
            Text('Longitude  ${longitude.toStringAsFixed(5)}'),
            if (timestamp != null) ...[
              const SizedBox(height: 8),
              Text(
                'Updated ${_relativeTime(timestamp)}',
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Map tiles need an internet connection. The marker updates when the driver phone shares a new GPS position.',
              style: TextStyle(
                color: Colors.blueGrey.shade600,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final seconds = DateTime.now().difference(time).inSeconds;
    if (seconds < 10) return 'just now';
    if (seconds < 60) return '$seconds seconds ago';
    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _BusCard extends StatelessWidget {
  const _BusCard({required this.bus, required this.onTap});

  final CampusBus bus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.directions_bus_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${bus.id} · ${bus.busNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bus.driver,
                      style: TextStyle(color: Colors.blueGrey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${bus.stops.length} stops',
                      style: TextStyle(
                        color: Colors.blueGrey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop});

  final BusStop stop;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 7, 20, 7),
    child: Row(
      children: [
        const Icon(Icons.circle, size: 9, color: Color(0xFF6746B8)),
        const SizedBox(width: 12),
        Expanded(child: Text(stop.name)),
        Text(stop.time, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _TimelineStop extends StatelessWidget {
  const _TimelineStop({required this.stop, required this.isLast});

  final BusStop stop;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          stop.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        stop.time,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
      Expanded(child: Text(value)),
    ],
  );
}

class _ScheduleEstimateCard extends StatelessWidget {
  const _ScheduleEstimateCard({required this.bus, required this.now});

  final CampusBus bus;
  final DateTime now;

  DateTime? _stopTime(String value) {
    final normalized = value.trim().toUpperCase().replaceAll('.', '');
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$')
        .firstMatch(normalized);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3);
    if (minute > 59) return null;
    if (meridiem != null) {
      if (hour < 1 || hour > 12) return null;
      hour = hour % 12 + (meridiem == 'PM' ? 12 : 0);
    } else if (hour > 23) {
      return null;
    }
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final schedule = bus.stops
        .map((stop) => (stop: stop, time: _stopTime(stop.time)))
        .where((entry) => entry.time != null)
        .toList();
    final color = Theme.of(context).colorScheme.primary;

    String title;
    String message;
    if (schedule.isEmpty) {
      title = 'Schedule estimate unavailable';
      message = 'This route has no readable stop times. Check the Timings tab.';
    } else if (now.isBefore(schedule.first.time!)) {
      title = 'Trip has not started yet';
      message =
          'First listed stop: ${schedule.first.stop.name} at ${_formatTime(schedule.first.time!)}.';
    } else {
      var lastReached = -1;
      for (var index = 0; index < schedule.length; index++) {
        if (!now.isBefore(schedule[index].time!)) lastReached = index;
      }
      if (lastReached >= schedule.length - 1) {
        title = 'Scheduled trip may be complete';
        message =
            'The last listed stop is ${schedule.last.stop.name} at ${_formatTime(schedule.last.time!)}.';
      } else if (lastReached < 0) {
        title = 'Trip has not started yet';
        message =
            'First listed stop: ${schedule.first.stop.name} at ${_formatTime(schedule.first.time!)}.';
      } else {
        final from = schedule[lastReached];
        final to = schedule[lastReached + 1];
        title = 'Estimated between stops';
        message =
            '${from.stop.name} (${_formatTime(from.time!)}) → ${to.stop.name} (${_formatTime(to.time!)}).';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule_rounded, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(message, style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.title,
    required this.message,
    required this.live,
  });

  final String title;
  final String message;
  final bool live;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            live ? Icons.gps_fixed_rounded : Icons.location_off_outlined,
            color: live ? Colors.green : Colors.blueGrey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _LiveBusMap extends StatefulWidget {
  const _LiveBusMap({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  State<_LiveBusMap> createState() => _LiveBusMapState();
}

class _LiveBusMapState extends State<_LiveBusMap> {
  final MapController _controller = MapController();
  bool _mapIsReady = false;

  @override
  void didUpdateWidget(covariant _LiveBusMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapIsReady &&
        (oldWidget.latitude != widget.latitude ||
            oldWidget.longitude != widget.longitude)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.move(
            LatLng(widget.latitude, widget.longitude),
            _controller.camera.zoom,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.latitude, widget.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 230,
        child: FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
            onMapReady: () => _mapIsReady = true,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bixly.campusride',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 54,
                  height: 54,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                color: Colors.white.withValues(alpha: .9),
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 46),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey.shade600),
          ),
        ],
      ),
    ),
  );
}
