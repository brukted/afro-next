import 'package:uuid/uuid.dart';

class IdFactory {
  IdFactory() : _uuid = const Uuid();

  final Uuid _uuid;

  String next() => _uuid.v4();
}
