@isTest
public with sharing class DataTableEditableTest {

    @isTest(seeAllData=true)
    private static void getColumnsAndDatasTest(){

        List<SObject> sobjects =[SELECT Id, Name, AccountId, Account.Name, Chances_to_win__c, CloseDate FROM Opportunity ORDER BY CreatedDate DESC LIMIT 2];
        DataTableEditable.convert(sobjects,'SELECT Id, Name, AccountId, Account.Name, Chances_to_win__c, CloseDate FROM Opportunity');

        DataTableEditable.updateRecords(sobjects);
    }

}