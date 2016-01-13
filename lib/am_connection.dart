import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:http/http.dart';

final Logger log = new Logger('AMConnection');

class _AuthenticatedClient extends BaseClient {
  String _tokenId;
  Cookie _ipro;
  final Client _inner;

  _AuthenticatedClient(this._tokenId, this._inner) {
    _ipro = new Cookie("iPlanetDirectoryPro", _tokenId);
    _ipro.httpOnly = false;
  }

  Future<StreamedResponse> send(BaseRequest request) {
    log.info("set cookie ${_ipro.toString()}");
    //request.headers["Set-Cookie"] = _ipro.toString();
    request.headers["Cookie"] = "iPlanetDirectoryPro=${_tokenId}";
    request.headers["Content-Type"] = "application/json";
    log.finest("Headers = ${request.headers}");

    return _inner.send(request);
  }
}

// A connection to an OpenAM server instance
class AMConnection {
  String _user;
  String _password;
  HttpClient _client;
  Uri _baseUri;
  String _tokenId;

  _AuthenticatedClient _http;

  AMConnection(this._user, this._password, this._baseUri) {
    _client = new HttpClient();
  }

  // the underlying Client to make http requests
  Client get httpClient => _http;

  final _authSleepInterval = new Duration(seconds: 10);

  // Authenticate to OpenAM as the configured user.
  // As a side effect the SSO token for the user will be set so
  // that subsequent http requests include the token
  // attempt to authenticate [retry] times. If retry is 0, try forever
  Future authenticate( {int retry:100}) async {
    var u = _uri('/json/authenticate');


    var forever = (retry == 0);
    HttpClientResponse response;

    while( (forever || retry-- > 0))  {
      log.info("Authenticating to ${u}");
      try  {
        var request = await _client.postUrl(u);
        request.headers.contentType = ContentType.JSON;
        request.headers.add('X-OpenAM-Username', _user);
        request.headers.add('X-OpenAM-Password', _password);

        request.write(JSON.encode({}));
        response = await request.close();
        if (response.statusCode == 200)
          break;
      }
      on SocketException catch( ex) {
        log.info("Socket exception = $ex");
      }
      on HttpException catch(e) {
        log.info("HTTP exception caught $e");
      }

      sleep(_authSleepInterval);
    }

    if( response == null )
      throw "No response from server, giving up";

    if( response.statusCode != 200 )
      throw "Could not authenticate. code=${response.statusCode} ${response.reasonPhrase}";

    var s = "";
    await for (var contents in response.transform(UTF8.decoder)) {
      s += contents;
    }

    var json = JSON.decode(s);

    log.info("Decoded json = ${json}");
    _tokenId = json['tokenId'];

    _http = new _AuthenticatedClient(_tokenId, new Client());
  }

  // prefix relative path with base path to form full uri
  Uri _uri(String relative) =>
      _baseUri.replace(path: "${_baseUri.path}$relative");

  // Perform a HTTP get on the connection using the authenticated user
  // return a json map of the results
  Future<Map> get(String uri, Map queryParams) async {
    var u = _uri(uri);

    u = u.replace(queryParameters: queryParams);
    log.info("GET ${u}");
    var resp = await _http.get(u.toString());

    var json = JSON.decode(resp.body);

    log.info("Decoded json = ${json}");
    return json;
  }

  Future<Response> post(String uri, Map queryParams, Object payload) async {
    var u = _uri(uri);
    u = u.replace(queryParameters: queryParams);
    log.fine("POST $u body=$payload");
    Response resp = await _http.post( u.toString(), body: payload);
    log.fine("response = ${resp.body}  ${resp.statusCode} ${resp.statusCode}");
    return resp;
  }
}
