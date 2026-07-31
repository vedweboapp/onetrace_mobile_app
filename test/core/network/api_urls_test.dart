import 'package:flutter_test/flutter_test.dart';
import 'package:red5/core/network/api_urls.dart';

void main() {
  test('job timer endpoints use the expected job routes', () {
    expect(AppApiUrls.jobTimer(15), '/api/v1/jobs/15/timer/');
    expect(AppApiUrls.jobTimers(15), '/api/v1/jobs/15/timers/');
  });
}
