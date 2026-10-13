import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// The server requires v4 attachment ids.
String newId() => _uuid.v4();

String newTimeOrderedId() => _uuid.v7();
