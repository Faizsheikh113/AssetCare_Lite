public with sharing class MachineAssetTriggerHandler {
	
    public void beforeInsert(List<Machine_Asset__c> newAssets){
        MachineAssetService.prepareAssets(newAssets);
    }

	public void afterInsert(List<Machine_Asset__c> newAssets){
    	MachineAssetService.handleAssetUpdate(newAssets, null, true);
	}
    
    public void afterUpdate(
        List<Machine_Asset__c> newAssets,
        Map<Id,Machine_Asset__c> oldMap
    ){
        MachineAssetService.handleAssetUpdate(newAssets,oldMap, false);
    }

	public void validateDuplicateSerialNumbers(
    	List<Machine_Asset__c> assets
	){
    	MachineAssetService.validateSerialNumbers(assets);
	}
    
}