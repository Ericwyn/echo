import 'dart:async';

import 'package:flutter/material.dart';

/// A presenter-independent song action supplied by a host surface.
///
/// [id] is stable across presenters so desktop menus and mobile sheets can
/// describe the same operation without owning its business behavior.
@immutable
class SongAction {
  const SongAction({
    required this.id,
    required this.icon,
    required this.title,
    required this.onPressed,
    this.isAvailable = true,
    this.isDestructive = false,
  }) : assert(id != '');

  final String id;
  final IconData icon;
  final String title;
  final bool isAvailable;
  final bool isDestructive;
  final FutureOr<void> Function() onPressed;
}
