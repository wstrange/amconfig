import 'package:logging/logging.dart';
import "../am_connection.dart";
import 'dart:async';
import 'package:http/src/response.dart';

// Represents an OpenAM policy

class Policy {
  String _name;
  List<String> _resources;
  String _applicationName;
  Map _actionValues;
  Map _subject;
  Map _condition;
  String _resourceTypeUuid;
  List<Object> _resourceAttributes;

  Policy.fromJSON(Map json) {
    _name = json['name'];
    _resources = json['resources'];
    _applicationName = json['applicationName'];
    _actionValues = json['actionValues'];
    _subject = json['subject'];
    _condition = json['condition'];
    _resourceTypeUuid = json['resourceTypeUuid'];
    _resourceAttributes = json['resourceAttributes'];
  }

  String toString() =>
      "Policy(name=$_name, resources=$_resources, subject = $_subject rAttrs=$_resourceAttributes)";
}

// Bare bones resource type.
// We will eventually need this to look up resource type uuids for policies
class ResourceType {
  String name;
  String uuid;

  ResourceType.fromJSON(Map json) {
    name = json['name'];
    uuid = json['uuid'];
  }

  String toString() => "ResourceType(name=$name, uuid=$uuid)";
}

// Manage OpenAM policies
// see http://openam.forgerock.org/doc/bootstrap/dev-guide/index.html#rest-api-authz-policies
class PolicyAdmin {
  AMConnection _am;
  final _log = new Logger("Policy");

  PolicyAdmin(this._am);

  Future<List<ResourceType>> listResourceTypes() async {
    var json = await _am.get("/json/resourcetypes", {"_queryFilter": "true"});
    _log.fine("Resource Types = $json");

    var a = new List<ResourceType>();

    json['result'].forEach((r) => a.add(new ResourceType.fromJSON(r)));

    return a;
  }

  Future<List<Policy>> listPolicies() async {
    var json = await _am.get("/json/policies", {"_queryFilter": "true"});
    _log.fine("list policy result = ${json}");

    List result = json['result'];

    var a = new List<Policy>();

    result.forEach((r) => a.add(new Policy.fromJSON(r)));

    return a;
  }

  // For now we just use generic json  - not Policy objects.
  // todo: Look at creating full policy model.
  Future<Response> createPolicy(String policy) async {
    Response r =
        await _am.post("/json/policies", {"_action": "create"}, policy);
    _log.info("create result= ${r.statusCode} ${r.reasonPhrase}");
    return r;
  }
}
