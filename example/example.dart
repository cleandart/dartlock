// Copyright (c) 2014, the Clean project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:lock/lock.dart';

import 'dart:async';

void main() {
  runWithLock("example.lock", () {
    return new Future.delayed(new Duration(seconds: 10), () => print("Done"));
  }).then((_) => print("Exiting"));

}