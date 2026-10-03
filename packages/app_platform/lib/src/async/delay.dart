/// Waits for a duration. Injected wherever code waits, so tests run on a fake
/// clock instead of sleeping.
typedef Delay = Future<void> Function(Duration duration);
