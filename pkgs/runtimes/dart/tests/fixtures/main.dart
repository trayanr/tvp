import 'dart:convert';
import 'dart:isolate';
Future<void> main() async {
  final values = jsonDecode('[6,7]') as List<dynamic>;
  final answer = await Isolate.run(() => (values[0] as int) * (values[1] as int));
  if (answer != 42) throw StateError('isolate/json');
  print(answer);
}
