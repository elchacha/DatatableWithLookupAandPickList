@isTest
private with sharing class DemoDataTableEditableTest {

    @isTest(seeAllData=true)
    private static void DemoDataTableEditableTest() {
        DemoDataTableEditable.getRecords(20,20);
    }
}