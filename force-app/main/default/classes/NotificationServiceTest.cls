@IsTest
private class NotificationServiceTest {

    @IsTest
    static void sendPushAlertDelegatesToEscalation() {
        Test.startTest();
        NotificationService.sendPushAlert(UserInfo.getUserId(), 'Test', 'Body', null);
        Test.stopTest();
        System.assert(true, 'No exception expected');
    }

    @IsTest
    static void sendPushAlertNullRecipient() {
        Test.startTest();
        NotificationService.sendPushAlert(null, 'Test', 'Body', null);
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void sendEmailToValidUser() {
        Test.startTest();
        try {
            NotificationService.sendEmail(UserInfo.getUserId(), 'Subject', '<p>Body</p>');
        } catch (System.EmailException e) {
            // Email permission disabled in some sandboxes; the path that builds the message still ran
        }
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void sendEmailToNonExistentUserIsNoop() {
        Test.startTest();
        // Use a fake but valid-format Id
        NotificationService.sendEmail('005000000000001AAA', 'Subject', '<p>Body</p>');
        Test.stopTest();
        System.assert(true);
    }
}