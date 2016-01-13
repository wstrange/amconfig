// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:amconfig/amconfig.dart';
import 'package:logging/logging.dart';
import 'package:di/di.dart';
import 'package:yaml/yaml.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';

main(List<String> arguments) async {
  Logger.root.level = Level.FINE;
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

  var pw = new File(pw_file).readAsStringSync().trim();

  var am = new AMConnection(openam_user, pw, Uri.parse(openam_url));

  await am.authenticate();

  // DI is a bit overkill here, but this might grow to have more object
  // type;
  ModuleInjector injector = new ModuleInjector(
      [new Module()..bind(AMConnection, toValue: am)..bind(PolicyAdmin)]);

  PolicyAdmin policyAdmin = injector.get(PolicyAdmin);

  var a = await policyAdmin.listPolicies();
  a.forEach((p) => log.fine("got policy $p"));

  var rt = await policyAdmin.listResourceTypes();
  rt.forEach((r) => log.fine("RT = $r"));

  // The policy file is checked out from git
  // We wait a bit here to ensure the git-sync container has time to
  // check out the file before we try to open it

  sleep(new Duration(seconds: 20));

  await createPolicies(policyFile, policyAdmin);
}

Future createPolicies(String policyFile, PolicyAdmin policyAdmin) async {
  var yml = new File(policyFile).readAsStringSync();

  log.info("Loading policies: \n $yml");

  var policyList = loadYaml(yml) as List;
  log.fine("Loaded yml = $policyList");


  await Future.forEach(policyList, (policy) async {
    var j = JSON.encode(policy);
    log.fine("encoded to json = $j");
    var r = await policyAdmin.createPolicy(j);
    log.fine("Policy create result =  ${r.statusCode} ${r.reasonPhrase}");
  });
}
