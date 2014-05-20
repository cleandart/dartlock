// Copyright (c) 2014, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library lock;

import 'dart:io';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

Logger logger = new Logger('dartlock');

class LockException implements Exception {

    /** The max count that was exceeded. */
    final num count;
    /** Path of lock. */
    final String path;

    LockException(this.count, this.path);

    String toString() =>
        "LockException: could not obtain lock at path $path after "
        "$count trials.";
}


Set _locks = new Set();

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
    _locks.add(path);
    return true;
  }
}

void freeLock(path) {
  if (_locks.contains(path)) {
    new File(_lockPath(path)).deleteSync();
  }
}

Future obtainLock(path, {Duration tryInterval: const Duration(seconds: 1),
                         num maxTrials: -1}) {
  logger.info('Trying to obtain lock at path $path.');
  var completer = new Completer();

  var trials = 0;
  tryCallback(Timer timer) {
    if (tryLock(path)) {
      timer.cancel();
      logger.info('Lock was successfully obtained.');
      completer.complete();
    } else {
      trials++;
      if (trials == maxTrials) {
        timer.cancel();
        completer.completeError(
            new LockException(trials, path));
      }
    }
  }
  var timer = new Timer.periodic(tryInterval, tryCallback);

  // Make first run immediately.
  tryCallback(timer);
  return completer.future;
}

Future _runWithLock(path, Future callback(), tryInterval, maxTrials) {
  var value;
  return obtainLock(path, tryInterval: tryInterval, maxTrials: maxTrials).then((_) {
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

Future runWithLock(path, Future callback(),
                   {Duration tryInterval: const Duration(seconds: 1),
                    num maxTrials: -1}) {
  return runZoned(() => _runWithLock(path, callback, tryInterval, maxTrials),
                                     onError: (e, s) {
    freeLock(path);
    if (e is LockException) {
      logger.warning(e.toString());
    } else {
      logger.shout('Error executing callback.', e, s);
    }
    exit(1);
  });
}
