import "dart:async";

Future<void> main() async {
  print("=== Microtask ordering investigation ===");
  // Simulate what StreamController does internally
  
  // When you add to an async StreamController, delivery is scheduled
  // Let us trace the order
  
  final src = StreamController<int?>();
  var gotNull = false;
  var gotUser = false;
  
  src.stream.listen((v) {
    if (v == null) {
      print("source listener: null - scheduling microtask");
      gotNull = true;
      Future.microtask(() {
        print("flush microtask fires: gotUser=$gotUser");
        if (!gotUser) print("BUG: flush fired before user!");
      });
    } else {
      gotUser = true;
      print("source listener: user ($v)");
    }
  });
  
  print("adding null");
  src.add(null);
  print("adding user");
  src.add(42);
  print("added both");
  await Future<void>.delayed(const Duration(milliseconds: 50));
}
