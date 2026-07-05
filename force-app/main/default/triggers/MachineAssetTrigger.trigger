trigger MachineAssetTrigger on Machine_Asset__c (before insert, before update, after insert, after update) {

    MachineAssetTriggerHandler handler = new MachineAssetTriggerHandler();

    if(Trigger.isBefore){
        if(Trigger.isInsert){
            handler.beforeInsert(Trigger.new);
            handler.validateDuplicateSerialNumbers(Trigger.new);
        }
        if(Trigger.isUpdate){
            handler.validateDuplicateSerialNumbers(Trigger.new);
        }
    }
    if(Trigger.isAfter){
        if(Trigger.isInsert){
            handler.afterInsert(Trigger.new);
        }
        if(Trigger.isUpdate){
            handler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}