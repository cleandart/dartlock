// Copyright (c) 2014, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library lock;

import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;

get _baseDir => p.dirname(Platform.script.toFilePath());

_lockPath(path) {
  if (p.isAbsolute(path)) return path;
  else return p.join(_baseDir, path);
}

bool tryLock(path) {
  if (new File(_lockPath(path)).existsSync()) {
    return false;
  } else {
    new File(_lockPath(path)).createSync();
    return true;
  }
}

void freeLock(path) {
 new File(_lockPath(path)).deleteSync();
}

Future obtainLock(path, {Duration tryInterval: const Duration(seconds: 1)}) {
  var completer = new Completer();

  tryCallback(Timer timer) {
    if (tryLock(path)) {
      timer.cancel();
      completer.complete();
    }
  }
  var timer = new Timer.periodic(tryInterval, tryCallback);

  // Make first run immediately.
  tryCallback(timer);
  return completer.future;
}

Future runWithLock(path, Future callback(), {Duration tryInterval: const Duration(seconds: 1)}) {
  var value;
  return obtainLock(path, tryInterval: tryInterval).then((_) {
    var listeners = [];
    var signals = [
                   // BUG in Dart -- can not listen to all three signals
                   // together.
                    //ProcessSignal.SIGHUP,
                    ProcessSignal.SIGINT,
                    ProcessSignal.SIGTERM,
                  ];
    for (var s in signals) {
      listeners.add(s.watch().listen((_) {
        freeLock(path);
        exit(1);
      }));
    }

    return callback().then((value) {
      for (var l in listeners) l.cancel();
      freeLock(path);
      return value;
    });
  });
}