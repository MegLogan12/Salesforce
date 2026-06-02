@IsTest(SeeAllData=true)
private class ODLSAConsoleControllerTest {
    @IsTest
    static void returnsListAndDetailData() {
        ODLServiceAppointmentConsoleController.ListPageData listData = ODLServiceAppointmentConsoleController.getListData();
        System.assertNotEquals(null, listData);
        System.assertNotEquals(null, listData.rows);

        if (!listData.rows.isEmpty()) {
            ODLServiceAppointmentConsoleController.DetailPageData detailData =
                ODLServiceAppointmentConsoleController.getRecordData(listData.rows[0].id);
            System.assertNotEquals(null, detailData);
            System.assertNotEquals(null, detailData.appointmentNumber);
        }
    }
}