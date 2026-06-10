/**
 * Wraps Microsoft Graph API calls using the Microsoft_Graph Named Credential.
 *
 * Auth model: OAuth 2.0 Client Credentials flow via External Credential
 *   "Microsoft_Graph". Salesforce mints an application token scoped to
 *   Mail.Send, Calendars.ReadWrite, User.Read.All.
 *
 * Setup prerequisites (done in Azure AD + Salesforce Setup, not code):
 *   1. Register an Azure AD application (single-tenant).
 *   2. Grant APPLICATION permissions (admin consent):
 *        - Mail.Send
 *        - Calendars.ReadWrite
 *        - User.Read.All
 *   3. Create a client secret. Record ClientId, TenantId, ClientSecret.
 *   4. In SF Setup > Named Credentials > External Credentials >
 *        Microsoft_Graph, edit the Principal named "Default" and paste
 *        ClientId + ClientSecret + TenantId into Authentication Parameters.
 *   5. Assign External Credential Principal Access to users or permsets
 *        that need to invoke callouts (or to the running user for system
 *        automation).
 *
 * Never commit ClientSecret to source.
 */
public with sharing class MicrosoftGraphService {

    private static final String NC = 'callout:Microsoft_Graph';
    private static final String BETA = '/beta';
    private static final String V1 = '/v1.0';

    // ---------- public API: send email ----------

    /**
     * Send an email as a specific mailbox user (UPN or userId).
     * Uses POST /users/{id|upn}/sendMail.
     *
     * @param fromUpn  mailbox to send from, e.g. 'megan.logan@thelovingcompanies.com'
     * @param toEmails list of recipient email addresses
     * @param subject  subject line
     * @param htmlBody HTML body
     * @return         the HTTP status code (202 on success)
     */
    public static Integer sendMail(
        String fromUpn,
        List<String> toEmails,
        String subject,
        String htmlBody
    ) {
        if (String.isBlank(fromUpn)) {
            throw new MicrosoftGraphException('fromUpn is required');
        }
        if (toEmails == null || toEmails.isEmpty()) {
            throw new MicrosoftGraphException('toEmails is required');
        }

        List<Map<String, Object>> toList = new List<Map<String, Object>>();
        for (String addr : toEmails) {
            if (String.isBlank(addr)) continue;
            toList.add(new Map<String, Object>{
                'emailAddress' => new Map<String, Object>{ 'address' => addr }
            });
        }

        Map<String, Object> payload = new Map<String, Object>{
            'message' => new Map<String, Object>{
                'subject'       => subject,
                'body'          => new Map<String, Object>{
                    'contentType' => 'HTML',
                    'content'     => htmlBody
                },
                'toRecipients'  => toList
            },
            'saveToSentItems' => true
        };

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(NC + V1 + '/users/' + EncodingUtil.urlEncode(fromUpn, 'UTF-8') + '/sendMail');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() >= 400) {
            throw new MicrosoftGraphException(
                'Graph sendMail failed: ' + res.getStatusCode() + ' ' + res.getStatus() + ' ' + res.getBody()
            );
        }
        return res.getStatusCode();
    }

    // ---------- public API: create calendar event ----------

    /**
     * Create a calendar event on a user's primary calendar.
     * Uses POST /users/{id|upn}/calendar/events.
     *
     * @param ownerUpn     mailbox owner (UPN)
     * @param subject      event subject
     * @param bodyHtml     event body (HTML)
     * @param startUtc     event start in UTC
     * @param endUtc       event end in UTC
     * @param attendees    list of attendee email addresses (optional)
     * @param location     free-text location (optional)
     * @return             the created event's id
     */
    public static String createEvent(
        String ownerUpn,
        String subject,
        String bodyHtml,
        Datetime startUtc,
        Datetime endUtc,
        List<String> attendees,
        String location
    ) {
        if (String.isBlank(ownerUpn)) throw new MicrosoftGraphException('ownerUpn is required');
        if (startUtc == null || endUtc == null) throw new MicrosoftGraphException('start/end required');

        List<Map<String, Object>> attList = new List<Map<String, Object>>();
        if (attendees != null) {
            for (String a : attendees) {
                if (String.isBlank(a)) continue;
                attList.add(new Map<String, Object>{
                    'type' => 'required',
                    'emailAddress' => new Map<String, Object>{ 'address' => a }
                });
            }
        }

        Map<String, Object> payload = new Map<String, Object>{
            'subject' => subject,
            'body'    => new Map<String, Object>{
                'contentType' => 'HTML',
                'content'     => String.isBlank(bodyHtml) ? '' : bodyHtml
            },
            'start'   => new Map<String, Object>{
                'dateTime' => startUtc.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss'),
                'timeZone' => 'UTC'
            },
            'end'     => new Map<String, Object>{
                'dateTime' => endUtc.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss'),
                'timeZone' => 'UTC'
            },
            'attendees' => attList
        };
        if (String.isNotBlank(location)) {
            payload.put('location', new Map<String, Object>{ 'displayName' => location });
        }

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(NC + V1 + '/users/' + EncodingUtil.urlEncode(ownerUpn, 'UTF-8') + '/calendar/events');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() >= 400) {
            throw new MicrosoftGraphException(
                'Graph createEvent failed: ' + res.getStatusCode() + ' ' + res.getStatus() + ' ' + res.getBody()
            );
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) body.get('id');
    }

    // ---------- public API: ping / health check ----------

    /**
     * Verify the Named Credential auth path works by fetching the app's
     * own user list (first page). Returns true on 200.
     */
    public static Boolean ping() {
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(NC + V1 + '/users?$top=1');
        req.setTimeout(15000);
        HttpResponse res = new Http().send(req);
        return res.getStatusCode() == 200;
    }

    public class MicrosoftGraphException extends Exception {}
}