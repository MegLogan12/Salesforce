@IsTest(SeeAllData=true)
private class ODLTasksActivityControllerTest {
    @IsTest
    static void returnsPageData() {
        Test.startTest();
        ODLTasksActivityController.PageData data = ODLTasksActivityController.getPageData();
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assertNotEquals(null, data.taskRows);
        System.assertEquals(7, data.calendarDays.size());
    }
}