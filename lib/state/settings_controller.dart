import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/doc_store.dart';
import '../data/docs.dart';
import '../data/models.dart';

/// Holds [AppSettings] and persists every change.
class SettingsController extends ValueNotifier<AppSettings> {
  SettingsController(this._store, AppSettings initial) : super(initial);

  final DocStore _store;

  void update(AppSettings Function(AppSettings s) change) {
    final next = change(value);
    value = next;
    unawaited(_store.save(Docs.settings, next));
  }
}
