import 'package:flutter_riverpod/flutter_riverpod.dart';

const discoverBranchIndex = 0;
const exploreBranchIndex = 1;
const libraryBranchIndex = 2;
// Branch identities stay stable even when Explore is hidden or reordered.
const catalogBranchIndex = 3;

final currentVisibleBranchIndexProvider = StateProvider<int>(
  (ref) => discoverBranchIndex,
);
