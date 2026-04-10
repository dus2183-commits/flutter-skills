import 'dart:js_interop';


@JS('navigator')
external Navigator get _navigator;

@JS()
@staticInterop
class Navigator {}

extension NavigatorExt on Navigator {
  external int? get hardwareConcurrency;
}

int getMaxConcurrent() {
  final int cores = _navigator.hardwareConcurrency ?? 4;
  // return ((cores ~/ 2)+2).clamp(3, 12);
  ///更激进一点的控制
  int max;
  if (cores <= 4) {
    max = 5;
  }else {
    max = cores+2;
  }
  return max;
}
