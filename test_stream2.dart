import "dart:async";

Stream<int?> deferLeadingNull_timer(Stream<int?> source) {
  late StreamController<int?> controller;
  StreamSubscription<int?>? sub;
  var sawFirst = false;
  var pendingLeadingNull = false;

  void onData(int? val) {
    if (!sawFirst) {
      sawFirst = true;
      if (val == null) {
        pendingLeadingNull = true;
        Timer.run(() {
          if (pendingLeadingNull && !controller.isClosed) {
            pendingLeadingNull = false;
            print("timer-flush: emitting null");
            controller.add(null);
          } else {
            print("timer-flush: suppressed");
          }
        });
        return;
      }
      controller.add(val);
      return;
    }
    pendingLeadingNull = false;
    controller.add(val);
  }

  controller = StreamController<int?>(
    onListen: () {
      sub = source.listen(onData, onError: controller.addError, onDone: () { controller.close(); });
    },
    onCancel: () async {
      pendingLeadingNull = false;
      await sub?.cancel();
    },
  );
  return controller.stream;
}

Future<void> main() async {
  print("=== Timer.run test ===");
  final src = StreamController<int?>();
  final seen = <int?>[];
  final out = deferLeadingNull_timer(src.stream);
  out.listen((v) { seen.add(v); print("seen: $v"); });

  src.add(null);
  src.add(42);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  print("final seen: $seen");
  print("contains null: ${seen.contains(null)}");
  src.close();
}
