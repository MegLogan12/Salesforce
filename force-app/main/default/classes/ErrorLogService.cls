/**
 * ErrorLogService
 * Writes errors to the Error_Log__c custom object for visibility in Salesforce.
 * Used by all service classes to capture non-fatal exceptions without swallowing them.
 */
public with sharing class ErrorLogService {

    public static void log(String className, String methodName, Id recordId, String message) {
        try {
            Error_Log__c err = new Error_Log__c(
                Class_Name__c   = className,
                Method_Name__c  = methodName,
                Record_Id__c    = recordId,
                Message__c      = message.left(32768),
                Logged_At__c    = Datetime.now(),
                User__c         = UserInfo.getUserId()
            );
            insert err;
        } catch (Exception e) {
            // If the error log itself fails, write to debug log
            System.debug('ErrorLogService failed to write: ' + e.getMessage());
            System.debug('Original error: ' + message);
        }
    }
}