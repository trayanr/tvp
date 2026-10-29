import 'dart:convert';
Future<void> main() async {
  final values = jsonDecode('[6,7]') as List<dynamic>;
  final answer = await Future<int>(() => (values[0] as int) * (values[1] as int));
  if (answer != 42) throw StateError('async/json');
  print(answer);
}
