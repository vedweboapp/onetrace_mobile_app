import 'package:flutter_test/flutter_test.dart';
import 'package:red5/core/places/place_address.dart';

void main() {
  group('parsePlaceAddressComponents', () {
    test('maps Google address components to form fields', () {
      final place = parsePlaceAddressComponents([
        {
          'long_name': '221B',
          'short_name': '221B',
          'types': ['street_number'],
        },
        {
          'long_name': 'Baker Street',
          'short_name': 'Baker St',
          'types': ['route'],
        },
        {
          'long_name': 'Flat 2',
          'short_name': 'Flat 2',
          'types': ['subpremise'],
        },
        {
          'long_name': 'London',
          'short_name': 'London',
          'types': ['postal_town'],
        },
        {
          'long_name': 'England',
          'short_name': 'England',
          'types': ['administrative_area_level_1'],
        },
        {
          'long_name': 'United Kingdom',
          'short_name': 'GB',
          'types': ['country'],
        },
        {
          'long_name': 'NW1 6XE',
          'short_name': 'NW1 6XE',
          'types': ['postal_code'],
        },
      ]);

      expect(place.addressLine1, '221B Baker Street');
      expect(place.addressLine2, 'Flat 2');
      expect(place.city, 'London');
      expect(place.state, 'England');
      expect(place.country, 'United Kingdom');
      expect(place.postalCode, 'NW1 6XE');
    });
  });

  group('matchCountryOption', () {
    test('matches aliases for United Kingdom', () {
      const options = ['India', 'United Kingdom', 'United States'];
      expect(matchCountryOption('uk', options), 'United Kingdom');
    });
  });
}
