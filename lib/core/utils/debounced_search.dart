import 'dart:async';

/// Debounces search input before triggering a reload (default 350 ms).
class DebouncedSearch {
  DebouncedSearch({this.delay = const Duration(milliseconds: 350)});

  final Duration delay;
  Timer? _timer;

  void schedule(void Function() onSearch) {
    _timer?.cancel();
    _timer = Timer(delay, onSearch);
  }

  void cancel() => _timer?.cancel();

  void dispose() => _timer?.cancel();
}
