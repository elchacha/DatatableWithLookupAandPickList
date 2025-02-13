public with sharing class DataTableEditable {


    static Map<String,String> manageFields= new Map<String,String>();
    static Set<String> referenceFieldEditable= new Set<String>();
    static String parentSobjectType;

    public static columnsAndDatas getResultFromCustomMetadataWithRecordId(String metadatame,String recordId,Integer limitSize, Integer offset){
        manageFields = new Map<String,String>();
        DataTableEditable__mdt config =[SELECT Query__c,columnLabels__c,columnReferences__c FROM DataTableEditable__mdt WHERE DeveloperName=:metadatame];
        String query  = config.Query__c;
        if(limitSize!=null) {
            query+=' LIMIT '+limitSize;
            if(offset!=null)query+=' OFFSET '+offset;
        }
        List<SObject> sobjects = Database.query(query);
        

        try {
            for(String fieldToProcess : config.columnLabels__c.split('\\n')){
                List<String> fieldInfo = fieldToProcess.split(':');
                manageFields.put(fieldInfo[0].trim(), fieldInfo[1].trim());
            }
        } catch (Exception e) {
            
        }

        try {
            referenceFieldEditable = new Set<String>();
            for(String fieldToProcess : config.columnReferences__c.split('\\r\\n')){
                referenceFieldEditable.add(fieldToProcess.trim().toLowerCase());
            }
        } catch (Exception e) {
        }

        return convert(sobjects,config.Query__c);
    }

 public static columnsAndDatas getResultFromCustomMetadata(String metadatame,Integer limitSize, Integer offset){
        return getResultFromCustomMetadataWithRecordId(metadatame,null,limitSize,offset);
    }


    public static columnsAndDatas convert(List<SObject> sobjects,String query){

        String fields = query.substring(7,query.toLowerCase().indexOf('from'));

        List<Map<String,Object>>  objects = new List<Map<String,Object>> ();
        List<String> lFields = fields.split(',');

        boolean firstRecord=true;

        List<Column> columns = new List<Column>();

        parentSobjectType = String.valueOf(sobjects[0].getSObjectType());

        for(SObject aSObject : sobjects){
            Map<String,Object> aMap = new Map<String,Object>();
            for(String fieldName : lFields){
                if(fieldName!=null){
                    fieldName=fieldName.trim();
                }
                if(firstRecord){
                    if(manageFields.containsKey(fieldName)){
                        if(!manageFields.get(fieldName).equals('hidden')){
                            columns.add(new Column(getFieldInfo(aSObject,fieldName),fieldName,manageFields.get(fieldName)));
                        }
                    } else{
                        columns.add(new Column(getFieldInfo(aSObject,fieldName),fieldName,null));
                    }
                }
                aMap.put(fieldName.trim().replaceAll('\\.', ''),getFieldValue(aSObject,fieldName));
                if(fieldName.toLowerCase().trim().endsWith('.name')){
                    aMap.put('Link'+fieldName.trim().replaceAll('\\.', ''),'/'+getLinkId(aSObject,fieldName));
                }

            }
            objects.add(aMap);
            firstRecord=false;
        }
        return new columnsAndDatas(columns,objects);
    }


    private static Object getFieldValue(Sobject record,String fieldName){
        fieldName=fieldName.trim();
        if(fieldName.contains('.')){
            String parent =fieldName.split('\\.')[0].trim();
            String child =fieldName.substring(fieldName.indexOf('.')+1);
            return getFieldValue(record.getSObject(parent),child);
        }else{
            // null if no parent record
            if(record==null) return '';
            return record.get(fieldName);
        }
    }

    public static Object getLinkId(Sobject record,String fieldName){
        fieldName=fieldName.trim();
        if(fieldName.contains('.')){
            String parent =fieldName.split('\\.')[0].trim();
            String child =fieldName.substring(fieldName.indexOf('.')+1);
            return getLinkId(record.getSObject(parent),child);
        }else{
            if(record==null) return '';
            return record.Id;
        }
    }


    static Map<SObjectType,Map<String, Schema.SObjectField>> fieldMaps = new Map<SObjectType,Map<String, Schema.SObjectField>>();
    private static DescribeFieldResult getFieldInfo(Sobject record,String fieldName){
        fieldName=fieldName.trim();
        if(fieldName.contains('.')){
            String parent =fieldName.split('\\.')[0].trim();
            String child =fieldName.substring(fieldName.indexOf('.')+1);
            return getFieldInfo(record.getSObject(parent),child);
        }else{
            if(!fieldMaps.containsKey(record.getSObjectType())){
                fieldMaps.put(record.getSObjectType(),Schema.describeSObjects(new String[]{String.valueOf(record.getSObjectType())})[0].fields.getMap());
            }
    
            return fieldMaps.get(record.getSObjectType()).get(fieldName).getDescribe();
        }
    }



    public class Column{
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String fieldName;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public boolean editable =false;
        @AuraEnabled
        public Object typeAttributes;
        @AuraEnabled
        public Object cellAttributes;
    
        
        public Column(DescribeFieldResult fieldDesc,String fieldFullName,String fieldLabel){

            this.fieldName = fieldFullName.trim().replaceAll('\\.', '');
            boolean isChild=fieldFullName.contains('.');


            label=fieldDesc.getLabel();

            if(fieldLabel!=null){
                label=fieldLabel;
            }
            type=String.valueOf(fieldDesc.getType()).tolowerCase();
            if(!isChild){
                editable=fieldDesc.isUpdateable();
            }

            cellAttributes=new Map<String, Object>{'class' => new Map<String, String>{'fieldName' => 'cellColor'}};

            if(type=='reference'){
                type='text';
                editable=false;
            }

            if(type=='picklist'){
                if(isChild){
                    type='text';
                }else{
                    ((Map<String, Object>)cellAttributes).put('fieldName' , 'fieldClass');
                    typeAttributes=getPickListTypeAttribute(fieldName,label,'fieldClass',fieldDesc);
                }
                editable=false;
            }
            if(referenceFieldEditable.contains(fieldFullName.trim().toLowerCase())){
                type='lookup';
                if(fieldName.contains('__r')){
                    this.fieldName= fieldFullName.split('__r')[0]+'__c';
                }else{
                    this.fieldName= fieldFullName.split('\\.')[0]+'Id';
                }
    
                typeAttributes=getReferenceTypeAttribute(fieldFullName,label,this.fieldName+'Class',fieldDesc);
            }
        }
        private Object getReferenceTypeAttribute(String fieldName,String label,String className,DescribeFieldResult fieldDesc){
            String fieldParentId;
            String childObjectLabel;
            if(fieldName.contains('__r')){
                fieldParentId=fieldName.split('__r')[0]+'__c';
                childObjectLabel=fieldName.split('__r')[0];
            }else{
                fieldParentId=fieldName.split('\\.')[0]+'Id';
                childObjectLabel=fieldName.split('\\.')[0];
            }

            Map<String,Object> attr = new Map<String,Object>();
            attr.put('placeholder','Choose '+label);
            attr.put('object',parentSobjectType);
            attr.put('fieldName',fieldParentId);
            attr.put('label',childObjectLabel);
            attr.put('value',new Map<String, Object>{'fieldName' => fieldParentId});
            attr.put('context',new Map<String, Object>{'fieldName' => 'Id'});
            attr.put('variant','label-hidden');
            attr.put('name',fieldParentId);
            attr.put('fields',new List<String>{fieldDesc.getSObjectType()+'.'+fieldDesc.getName()});
            attr.put('target','_blank');
            attr.put('className',className);            
            return attr;
        }

        private Object getPickListTypeAttribute(String fieldName,String label,String className,DescribeFieldResult fieldDesc){
            Map<String,Object> attr = new Map<String,Object>();
            attr.put('placeholder','Choose '+label);
            attr.put('options',getPickListValues(fieldDesc));
            attr.put('value',new Map<String, Object>{'fieldName' => fieldName});
            attr.put('context',new Map<String, Object>{'fieldName' => 'Id'});
            attr.put('variant','label-hidden');
            attr.put('name',fieldName);
            attr.put('label',label);
            attr.put('className',className);
    
            return attr;
        }

        private Object getLinkTypeAttribute(String fieldName){
            Map<String,Object> attr = new Map<String,Object>();
            attr.put('label',new Map<String, Object>{'fieldName' => fieldName});
            attr.put('target','_blank');
    
            return attr;
        }

        private List<Map<String,String>> getPickListValues(DescribeFieldResult fieldDesc){
            List<Map<String,String>> values = new List<Map<String,String>>();
            for( Schema.PicklistEntry pickListVal : fieldDesc.getPicklistValues()){
                values.add(new Map<String, String>{'label' => pickListVal.getLabel(),'value' => pickListVal.getValue()});
            }
    
            List<Map<String,String>> sortedValues = new List<Map<String,String>>();
            for(Integer i = values.size() - 1; i >= 0; i--){
                sortedValues.add(values[i]);
            }
            return sortedValues;
        }
    
    }


    public class columnsAndDatas{
        @AuraEnabled
        public List<Column> columns;
        @AuraEnabled
        public List<Map<String,Object>> datas;

        public columnsAndDatas(List<Column> columns,List<Map<String,Object>> datas){
            this.columns=columns;
            this.datas=datas;
        }
    }


    @AuraEnabled
    public static void updateRecords(List<Sobject> recordsforUpdate) {
        update recordsforUpdate;
    }
}