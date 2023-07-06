import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

/// Listenable Stream
///
/// A class that implements [Listenable] for a stream.
/// Objects need to be manually disposed.
class StreamListenable extends ChangeNotifier {
  /// Listenable Stream
  StreamListenable(final Stream<dynamic> stream) {
    if (stream is! BehaviorSubject) {
      notifyListeners();
    }

    addSubscription(stream);
  }

  /// Listenable for multiple Streams.
  ///
  /// Notifies it's listeners on every event emitted by any of the streams.
  StreamListenable.multiListenable(final Iterable<Stream<dynamic>> streams) {
    streams.forEach(addSubscription);
  }

  void addSubscription(final Stream<dynamic> stream) {
    _subscriptions.add(
      stream.asBroadcastStream().listen((final _) {
        notifyListeners();
      }),
    );
  }

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }

    super.dispose();
  }
}
