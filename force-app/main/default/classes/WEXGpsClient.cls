/**
* WEXGpsClient — foundation HTTP client for the GPS Insight (WEX Fleet Intelligence) API v2.
*
* Responsibilities:
*   • Resolves and caches the GPS Insight session token via GPS_Insight_Config__c
*   • Injects session_token into every outbound request automatically
*   • Returns a typed ApiResponse with a convenience rows() method
*   • Logs all non-2xx responses and exceptions to Error_Log__c
*
* Never reference this class's auth logic directly — always call get() / post().
* Auth credentials live exclusively in GPS_Insight_Config__c (Custom Setting).
*
* Named Credential: WEX_GPS_API → https://api.gpsinsight.com
* Callout pattern:  callout:WEX_GPS_API/v2/vehicle/location
*/
public with sharing class WEXGpsClient {

@TestVisible static final String CRED = 'callout:WEX_GPS_API';
@TestVisible static final String AUTH_BASE = 'https://api.gpsinsight.com/v2';


public class ApiResponse {
public final Integer statusCode;
public final String  rawBody;
public final Boolean ok;

@TestVisible
ApiResponse(Integer code, String body) {
this.statusCode = code;
this.rawBody    = body;
this.ok         = (code >= 200 && code < 300);
}

/**
* Returns all records from the API response 'data' (or 'results', 'vehicles', etc.)
* envelope.  Never returns null — returns an empty list on any error.
*/
public List<Map<String, Object>> rows() {
if (!ok || String.isBlank(rawBody)) return new List<Map<String, Object>>();
try {
Object parsed = JSON.deserializeUntyped(rawBody);
List<Object> items = extractItems(parsed);
List<Map<String, Object>> out = new List<Map<String, Object>>();
if (items != null) {
for (Object o : items) {
if (o instanceof Map<String, Object>) out.add((Map<String, Object>) o);
}
}
return out;
} catch (Exception e) {
return new List<Map<String, Object>>();
}
}

private List<Object> extractItems(Object parsed) {
if (parsed instanceof List<Object>) return (List<Object>) parsed;
if (!(parsed instanceof Map<String, Object>)) return null;
Map<String, Object> root = (Map<String, Object>) parsed;
for (String key : new List<String>{'data', 'vehicles', 'results', 'drivers', 'landmarks', 'alerts'}) {
Object val = root.get(key);
if (val instanceof List<Object>) return (List<Object>) val;
if (val instanceof Map<String, Object>) return new List<Object>{ val };
}
return null;
}
}


public static ApiResponse get(String path) {
return doGet(path, new Map<String, String>());
}

public static ApiResponse get(String path, Map<String, String> params) {
return doGet(path, params == null ? new Map<String, String>() : params);
}


@TestVisible
static ApiResponse doGet(String path, Map<String, String> params) {
String token = resolveToken();
if (String.isBlank(token)) {
logError('doGet', 401, 'No session token — check GPS_Insight_Config__c credentials. Path: ' + path);
return errResponse(401, 'No session token');
}

try {
String cachedToken = getCachedToken();
HttpResponse res = sendGet(path, params, token);
ApiResponse out = new ApiResponse(res.getStatusCode(), res.getBody());
if (!out.ok && shouldRetryInvalidToken(res)) {
String refreshedToken = forceRefreshToken();
if (!String.isBlank(refreshedToken) && refreshedToken != token) {
res = sendGet(path, params, refreshedToken);
out = new ApiResponse(res.getStatusCode(), res.getBody());
if (out.ok) {
persistSessionToken(refreshedToken);
}
}
} else if (out.ok && token != cachedToken) {
persistSessionToken(token);
}
if (!out.ok) {
logError('doGet', out.statusCode, path + ' → ' + trunc(out.rawBody, 500));
}
return out;
} catch (Exception e) {
// Do not call logError() (DML) if the exception itself is a callout restriction.
// Attempting DML after 'uncommitted work pending' can cascade into a second failure.
String msg = path + ': ' + e.getMessage();
if (!e.getMessage().containsIgnoreCase('uncommitted work')) {
    logError('doGet', 0, msg);
} else {
    System.debug(LoggingLevel.WARN, 'WEXGpsClient.doGet skipped DML log (callout restriction): ' + msg);
}
return errResponse(0, e.getMessage());
}
}

@TestVisible
static HttpResponse sendGet(String path, Map<String, String> params, String token) {
String url = CRED + '/' + path.removeStart('/');
url += '?session_token=' + EncodingUtil.urlEncode(token, 'UTF-8');
for (String k : params.keySet()) {
String v = params.get(k);
if (!String.isBlank(v)) {
url += '&' + EncodingUtil.urlEncode(k, 'UTF-8')
+ '=' + EncodingUtil.urlEncode(v, 'UTF-8');
}
}

HttpRequest req = new HttpRequest();
req.setEndpoint(url);
req.setMethod('GET');
req.setHeader('Accept', 'application/json');
req.setTimeout(30000);
return new Http().send(req);
}

@TestVisible
static Boolean shouldRetryInvalidToken(HttpResponse res) {
if (res == null || res.getStatusCode() != 401) return false;
String body = res.getBody();
return !String.isBlank(body) && body.toLowerCase().contains('invalid session_token');
}

@TestVisible
static String forceRefreshToken() {
GPS_Insight_Config__c cfg = GPS_Insight_Config__c.getOrgDefaults();
if (String.isBlank(cfg.Username__c) || String.isBlank(cfg.App_Token__c)) {
return null;
}
return login(cfg.Username__c, cfg.App_Token__c);
}

@TestVisible
static void persistSessionToken(String token) {
if (String.isBlank(token)) return;
GPS_Insight_Config__c cfg = GPS_Insight_Config__c.getOrgDefaults();
cfg.Session_Token__c = token;
cfg.Token_Expiry__c = DateTime.now().addDays(6);
upsert cfg;
}


@TestVisible
static String resolveToken() {
GPS_Insight_Config__c cfg = GPS_Insight_Config__c.getOrgDefaults();
if (!String.isBlank(cfg.Session_Token__c)
&& cfg.Token_Expiry__c != null
&& cfg.Token_Expiry__c > DateTime.now().addHours(1)) {
return cfg.Session_Token__c;
}
if (String.isBlank(cfg.Username__c) || String.isBlank(cfg.App_Token__c)) {
return null;
}
return login(cfg.Username__c, cfg.App_Token__c);
}

@TestVisible
static String getCachedToken() {
return GPS_Insight_Config__c.getOrgDefaults().Session_Token__c;
}

@TestVisible
static String login(String username, String appToken) {
HttpRequest req = new HttpRequest();
req.setEndpoint(AUTH_BASE + '/userauth/login'
+ '?username='   + EncodingUtil.urlEncode(username, 'UTF-8')
+ '&app_token='  + EncodingUtil.urlEncode(appToken, 'UTF-8'));
req.setMethod('GET');
req.setHeader('Accept', 'application/json');
req.setTimeout(15000);

try {
HttpResponse res = new Http().send(req);
if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
logError('login', res.getStatusCode(), trunc(res.getBody(), 300));
return null;
}
Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
Object data = body.get('data');
if (data instanceof Map<String, Object>) {
return toStr(((Map<String, Object>) data).get('token'));
}
if (data instanceof List<Object>) {
List<Object> dl = (List<Object>) data;
if (!dl.isEmpty() && dl[0] instanceof Map<String, Object>) {
return toStr(((Map<String, Object>) dl[0]).get('token'));
}
}
} catch (Exception e) {
if (!e.getMessage().containsIgnoreCase('uncommitted work')) {
    logError('login', 0, e.getMessage());
} else {
    System.debug(LoggingLevel.WARN, 'WEXGpsClient.login skipped DML log (callout restriction): ' + e.getMessage());
}
}
return null;
}


public static void logError(String method, Integer code, String message) {
System.debug(LoggingLevel.ERROR, 'WEXGpsClient.' + method + '[' + code + ']: ' + message);
try {
insert new Error_Log__c(
Class_Name__c  = 'WEXGpsClient',
Method_Name__c = method,
Message__c     = trunc(message + ' (HTTP ' + code + ')', 32768),
Logged_At__c   = DateTime.now()
);
} catch (Exception ignored) {}
}


public static String   toStr(Object o)    { return o == null ? null : String.valueOf(o); }
public static Decimal  toDecimal(Object o) {
if (o == null) return null;
try { return Decimal.valueOf(String.valueOf(o)); } catch (Exception e) { return null; }
}
public static DateTime toDateTime(String s) {
if (String.isBlank(s)) return null;
try {
if (s.endsWith('Z')) s = s.replace('Z', '+0000');
return (DateTime) JSON.deserialize('"' + s + '"', DateTime.class);
} catch (Exception e) { return null; }
}

private static ApiResponse errResponse(Integer code, String msg) {
return new ApiResponse(code, '{"error":"' + msg.replace('"', '\\"') + '"}');
}
private static String trunc(String s, Integer max) {
return s == null ? '' : (s.length() <= max ? s : s.left(max));
}
}