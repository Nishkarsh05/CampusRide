import 'dart:convert';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

import '../models/campus_bus.dart';

class CampusRideRepository {
  CampusRideRepository._();

  static final CampusRideRepository instance = CampusRideRepository._();

  static const String _databaseUrl =
      'https://campusride-89b00-default-rtdb.firebaseio.com';

  final DatabaseReference _buses = FirebaseDatabase.instance.ref('buses');

  Future<List<CampusBus>> fetchBuses() async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse('$_databaseUrl/buses.json'))
          .timeout(const Duration(seconds: 15));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw Exception('Could not load routes (HTTP ${response.statusCode}).');
      }
      final body = await utf8
          .decodeStream(response)
          .timeout(const Duration(seconds: 15));
      return _parseBuses(jsonDecode(body));
    } finally {
      client.close(force: true);
    }
  }

  List<CampusBus> _parseBuses(dynamic decoded) {
    if (decoded is! Map) return const [];
    final buses =
        decoded.entries
            .map(
              (entry) => CampusBus.fromJson(entry.key.toString(), entry.value),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return buses;
  }

  Stream<DatabaseEvent> watchBusLocation(String busId) =>
      _buses.child(busId).child('location').onValue;

  Future<void> publishLocation({
    required String busId,
    required Position position,
  }) {
    return _buses.child(busId).child('location').set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'updatedAt': ServerValue.timestamp,
      'sharing': true,
    });
  }

  Future<void> stopSharing(String busId) => _buses
      .child(busId)
      .child('location')
      .update({'sharing': false, 'updatedAt': ServerValue.timestamp});
}
