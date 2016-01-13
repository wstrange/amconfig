// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:amconfig/amconfig.dart';
import 'package:logging/logging.dart';
import 'package:di/di.dart';
import 'package:yaml/yaml.dart';
import 'dart:io';
import 'dart:convert';

main(List<String> arguments) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  var env = Platform.environment;

  var openam_url = env['OPENAM_URL'];
  var openam_user = env['OPENAM_USER'];
  var pw_file = env['OPENAM_PW_FILE'];

  if (pw_file == null) pw_file = "/secrets/amadmin.pw";

  var policyFile = env['POLICY_FILE'];
  if (policyFile == null) policyFile = "/config/openam/policies.yaml";

  if (openam_url == null || openam_user == null) {
    throw "Environment variables OPENAM_USER, OPENAM_URL must be set";
  }

  var pw = new File(pw_file).readAsStringSync();

  var am = new AMConnection(openam_user, pw, Uri.parse(openam_url));

  await am.authenticate();

  // DI is a bit overkill here, but this might grow to have more object
  // type;
  ModuleInjector injector = new ModuleInjector(
      [new Module()..bind(AMConnection, toValue: am)..bind(PolicyAdmin)]);

  PolicyAdmin policyAdmin = injector.get(PolicyAdmin);

  var a = await policyAdmin.listPolicies();
  a.forEach((p) => log.info("got policy $p"));

  var rt = await policyAdmin.listResourceTypes();
  rt.forEach((r) => log.info("RT = $r"));

  createPolicies(policyFile, policyAdmin);
}

createPolicies(String policyFile, PolicyAdmin policyAdmin) {
  var yml = new File(policyFile).readAsStringSync();

  var p = loadYaml(yml);
  log.info("Loaded yml = $p");

  p.forEach((o) async {
    var j = JSON.encode(o);

    log.info("encoded = $j");
    var r = await policyAdmin.createPolicy(j);
  });
}
