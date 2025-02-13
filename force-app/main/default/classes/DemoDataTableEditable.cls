public with sharing class DemoDataTableEditable {

    @AuraEnabled(cacheable=false)
    public static DataTableEditable.columnsAndDatas getRecords(Integer limitSize, Integer offset) {
        DataTableEditable.columnsAndDatas datasAndColumns;
        if(Test.isRunningTest()){
            datasAndColumns = DataTableEditable.getResultFromCustomMetadata('ConfigTestClass',limitSize,offset);
    
        }else{
            datasAndColumns = DataTableEditable.getResultFromCustomMetadata('ContactExample',limitSize,offset);
//            datasAndColumns = DataTableEditable.getResultFromCustomMetadata('OpportunityExample',limitSize,offset);
        }
        for(Map<String,Object> mapRecord : datasAndColumns.datas){
            Date valueToTest = (Date) mapRecord.get('Sourcing_Close_Date__c');
            if(valueToTest<Date.today()){
                mapRecord.put('cellColor','cell-Orange');
            }else if(valueToTest<Date.today().addDays(7)){
                mapRecord.put('cellColor','cell-Green');
            }
        }


        return datasAndColumns;
    }





}