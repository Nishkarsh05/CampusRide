import 'package:firebase_database/firebase_database.dart';

class BusStop {
  const BusStop({required this.number, required this.name, required this.time});

  final String number;
  final String name;
  final String time;

  factory BusStop.fromJson(String number, dynamic value) {
    final data = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    return BusStop(
      number: number,
      name: data['name']?.toString() ?? 'Unnamed stop',
      time: data['time']?.toString() ?? 'Time unavailable',
    );
  }

  factory BusStop.fromSnapshot(DataSnapshot snapshot) => BusStop(
    number: snapshot.key ?? '',
    name: snapshot.child('name').value?.toString() ?? 'Unnamed stop',
    time: snapshot.child('time').value?.toString() ?? 'Time unavailable',
  );
}

class CampusBus {
  const CampusBus({
    required this.id,
    required this.busNumber,
    required this.stops,
  });

  final String id;
  final String busNumber;
  final List<BusStop> stops;

  factory CampusBus.fromJson(String id, dynamic value) {
    final data = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    final rawStops = data['stops'];
    final stops = <BusStop>[];
    if (rawStops is List) {
      for (var index = 0; index < rawStops.length; index++) {
        final rawStop = rawStops[index];
        if (rawStop != null) stops.add(BusStop.fromJson('$index', rawStop));
      }
    } else if (rawStops is Map) {
      for (final entry in rawStops.entries) {
        stops.add(BusStop.fromJson(entry.key.toString(), entry.value));
      }
    }
    stops.sort((a, b) {
      final aNumber = int.tryParse(a.number) ?? 0;
      final bNumber = int.tryParse(b.number) ?? 0;
      return aNumber.compareTo(bNumber);
    });
    return CampusBus(
      id: id,
      busNumber: data['busNumber']?.toString() ?? 'Unknown bus',
      stops: stops,
    );
  }

  factory CampusBus.fromSnapshot(DataSnapshot snapshot) {
    final stops =
        snapshot.child('stops').children.map(BusStop.fromSnapshot).toList()
          ..sort((a, b) {
            final aNumber = int.tryParse(a.number) ?? 0;
            final bNumber = int.tryParse(b.number) ?? 0;
            return aNumber.compareTo(bNumber);
          });

    return CampusBus(
      id: snapshot.key ?? '',
      busNumber: snapshot.child('busNumber').value?.toString() ?? 'Unknown bus',
      stops: stops,
    );
  }
}
