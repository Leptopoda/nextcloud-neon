part of '../../dynamite.dart';

class TypeResultBase extends TypeResult {
  TypeResultBase(super.name) : assert(name != 'JsonObject' && name != 'dynamic', 'Use TypeResultObject instead');

  @override
  String serialize(final String object) => object;

  @override
  String encode(
    final String object, {
    final bool onlyChildren = false,
    final String? mimeType,
  }) =>
      name == 'String' ? object : '$object.toString()';

  @override
  String deserialize(final String object, {final bool toBuilder = false}) => '($object as $name)';

  @override
  String decode(final String object) {
    switch (name) {
      case 'String':
        return '($object as String)';
      case 'int':
        return 'int.parse($object as String)';
      default:
        throw Exception('Can not decode "$name" from String');
    }
  }
}
