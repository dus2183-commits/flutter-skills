import 'dart:io';

int getMaxConcurrent() {
  final int cores = Platform.numberOfProcessors;

  ///更激进一点的控制
  int max;
  if (cores <= 2) {
    max = 3;
  } else if (cores <= 4) {
    max = 5;
  }else {
    max = cores+2;
  }
  return max;
}
