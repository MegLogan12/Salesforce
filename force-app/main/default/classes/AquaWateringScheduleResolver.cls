/**
 * AquaWateringScheduleResolver
 *
 * Resolves a textual watering instruction from Aqua_Watering_Schedule__c records
 * tied to a Community__c. Combines BOTH applicable ramp rows (matched by week-since-install)
 * AND the seasonal monthly row for the service month.
 *
 * Designed to be called from Aqua Check Ticket creation (Apex/Flow/LWC) so the
 * resolved schedule is captured as a snapshot on the ticket.
 */
public with sharing class AquaWateringScheduleResolver {

    public static String resolve(Id communityId, Id workOrderId, Date serviceDate) {
        return resolveWithInstallDate(communityId, null, serviceDate);
    }

    public static String resolveWithInstallDate(Id communityId, Date installDate, Date serviceDate) {
        if (communityId == null || serviceDate == null) {
            return '';
        }
        Integer weekNum = (installDate == null)
            ? null
            : Math.max(1, (installDate.daysBetween(serviceDate) / 7) + 1);

        List<Aqua_Watering_Schedule__c> rows = [
            SELECT Schedule_Type__c, Week_Number__c, Run_Frequency__c, Run_Duration_Min__c,
                   Month__c, Run_Time_Pct__c, Notes__c
            FROM Aqua_Watering_Schedule__c
            WHERE Community__c = :communityId
        ];
        if (rows.isEmpty()) {
            return defaultText(installDate);
        }

        DateTime dt = DateTime.newInstance(serviceDate, Time.newInstance(0,0,0,0));
        String monthName = dt.format('MMMM');

        List<String> parts = new List<String>();
        for (Aqua_Watering_Schedule__c r : rows) {
            if (r.Schedule_Type__c == 'New Install Ramp' && weekNum != null && r.Week_Number__c == weekNum) {
                parts.add(formatRamp(r, weekNum));
            } else if (r.Schedule_Type__c == 'Seasonal Monthly' && r.Month__c == monthName) {
                parts.add(formatSeasonal(r, monthName));
            }
        }
        if (parts.isEmpty()) {
            return defaultText(installDate);
        }
        return String.join(parts, '\n');
    }

    private static String formatRamp(Aqua_Watering_Schedule__c r, Integer weekNum) {
        String s = 'Ramp Week ' + weekNum + ': ' + blank(r.Run_Frequency__c);
        if (r.Run_Duration_Min__c != null) s += ', ' + r.Run_Duration_Min__c + ' min';
        if (!String.isBlank(r.Notes__c))   s += ' (' + r.Notes__c + ')';
        return s;
    }

    private static String formatSeasonal(Aqua_Watering_Schedule__c r, String monthName) {
        String s = 'Seasonal ' + monthName + ': ' + blank(r.Run_Frequency__c);
        if (r.Run_Duration_Min__c != null) s += ', ' + r.Run_Duration_Min__c + ' min';
        if (r.Run_Time_Pct__c != null)     s += ' at ' + r.Run_Time_Pct__c + '%';
        if (!String.isBlank(r.Notes__c))   s += ' (' + r.Notes__c + ')';
        return s;
    }

    private static String defaultText(Date installDate) {
        if (installDate == null) {
            return 'No install date on file. Default program: water as needed.';
        }
        Integer days = installDate.daysBetween(Date.today());
        if (days <= 7)  return 'Week 1: 3x/day, 30 minutes each';
        if (days <= 14) return 'Week 2: 3x/week, 20 minutes each';
        if (days <= 21) return 'Week 3: 1x/day, 20 minutes each';
        return 'Week 4+: Per established program';
    }

    private static String blank(String s) {
        return s == null ? '' : s;
    }
}