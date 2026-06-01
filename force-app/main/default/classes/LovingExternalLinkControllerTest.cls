@isTest
private class LovingExternalLinkControllerTest {

    @isTest
    static void getLinks_returnsCmtRecords() {
        Test.startTest();
        List<LovingExternalLinkController.LinkDto> result = LovingExternalLinkController.getLinks();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result list must not be null');
        for (LovingExternalLinkController.LinkDto d : result) {
            System.assertNotEquals(null, d.key,   'key must be set');
            System.assertNotEquals(null, d.label, 'label must be set');
            System.assertNotEquals(null, d.url,   'url must be set');
        }
    }
}
