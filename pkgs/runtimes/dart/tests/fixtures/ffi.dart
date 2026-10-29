import 'dart:ffi';
typedef NativeAnswer = Int32 Function(Int32, Int32);
typedef DartAnswer = int Function(int, int);
void main(List<String> args) {
  final library = DynamicLibrary.open(args.single);
  final answer = library.lookupFunction<NativeAnswer, DartAnswer>('answer');
  if (answer(6, 7) != 42) throw StateError('FFI');
  print(answer(6, 7));
}
