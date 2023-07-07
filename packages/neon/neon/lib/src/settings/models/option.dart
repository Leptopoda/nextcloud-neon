import 'dart:async';

import 'package:meta/meta.dart';
import 'package:neon/src/settings/models/options_category.dart';
import 'package:neon/src/settings/models/storage.dart';
import 'package:neon/src/settings/widgets/label_builder.dart';
import 'package:rxdart/rxdart.dart';

@internal
class OptionDisableException implements Exception {}

@immutable
@internal
abstract class Option<T> {
  Option({
    required this.storage,
    required this.key,
    required this.label,
    required this.defaultValue,
    required this.stream,
    this.category,
    final BehaviorSubject<bool>? enabled,
  }) : enabled = enabled ?? BehaviorSubject<bool>.seeded(true);

  final SettingsStorage storage;
  final String key;
  final LabelBuilder label;
  final T defaultValue;
  final OptionsCategory? category;
  final BehaviorSubject<bool> enabled;
  final BehaviorSubject<T> stream;

  T get value {
    if (hasValue) {
      return stream.value;
    }

    return defaultValue;
  }

  bool get hasValue {
    if (!enabled.value) {
      throw OptionDisableException();
    }

    return stream.hasValue;
  }

  Future reset() async {
    await set(defaultValue);
  }

  void dispose() {
    unawaited(stream.close());
    unawaited(enabled.close());
  }

  Future set(final T value);

  Future<T?> deserialize(final dynamic data);

  dynamic serialize();
}