public with sharing class AssetQueryService {
// ─────────────────────────────────────────────
    // SOQL 1: Get all assets where service is due
    // ─────────────────────────────────────────────
    public static List<Machine_Asset__c> getServiceDueAssets() {
        return [
            SELECT Id, Name, Asset_Name__c, Asset_Status__c,
                   Last_Service_Date__c, Next_Maintenance_Due__c,
                   Customer_Site__r.Site_Name__c,
                   Customer_Site__r.City__c
            FROM Machine_Asset__c
            WHERE Asset_Status__c = 'Service Due'
            AND Customer_Site__r.Site_Status__c = 'Active'
            ORDER BY Next_Maintenance_Due__c ASC NULLS LAST
            LIMIT 200
        ];
    }

    // ─────────────────────────────────────────────
    // SOQL 2: Get open ticket count per site
    // ─────────────────────────────────────────────
    public static List<AggregateResult> getOpenTicketCountPerSite() {
        return [
            SELECT Machine_Asset__r.Customer_Site__r.Site_Name__c siteName,
                   COUNT(Id) ticketCount,
                   MAX(SLA_Due_Date__c) latestSLA
            FROM Service_Ticket__c
            WHERE Status__c NOT IN ('Closed', 'Resolved')
            GROUP BY Machine_Asset__r.Customer_Site__r.Site_Name__c
            ORDER BY COUNT(Id) DESC
        ];
    }

    // ─────────────────────────────────────────────
    // SOQL 3: Get assets with expired warranty
    // ─────────────────────────────────────────────
    public static List<Machine_Asset__c> getWarrantyExpiredAssets() {
        return [
            SELECT Id, Asset_Name__c, Asset_Status__c,
                   Warranty_End__c, Serial_Number__c,
                   Customer_Site__r.Site_Name__c
            FROM Machine_Asset__c
            WHERE Warranty_End__c < TODAY
            AND Asset_Status__c != 'Warranty Expired'
            AND Asset_Status__c != 'Decommissioned'
            ORDER BY Warranty_End__c ASC
            LIMIT 200
        ];
    }

    // ─────────────────────────────────────────────
    // SOQL 4: Get tickets breaching SLA
    // ─────────────────────────────────────────────
    public static List<Service_Ticket__c> getSLABreachedTickets() {
        return [
            SELECT Id, Name, Subject__c, Status__c,
                   Priority__c, SLA_Due_Date__c,
                   Machine_Asset__r.Asset_Name__c,
                   Machine_Asset__r.Customer_Site__r.Site_Name__c
            FROM Service_Ticket__c
            WHERE SLA_Due_Date__c < :DateTime.now()
            AND Status__c NOT IN ('Closed', 'Resolved')
            ORDER BY SLA_Due_Date__c ASC
            LIMIT 200
        ];
    }

    // ─────────────────────────────────────────────
    // SOQL 5: Parent-Child — Site with all assets
    // ─────────────────────────────────────────────
    public static List<Customer_Site__c> getSitesWithAssets() {
        return [
            SELECT Id, Site_Name__c, Site_Status__c,
                   City__c, State__c,
                   Total_Installed_Assets__c,
                   (
                       SELECT Id, Asset_Name__c, Asset_Status__c,
                              Product_Type__c, Serial_Number__c,
                              Last_Service_Date__c
                       FROM Machine_Assets__r
                       ORDER BY Asset_Status__c
                   )
            FROM Customer_Site__c
            WHERE Site_Status__c = 'Active'
            ORDER BY Total_Installed_Assets__c DESC NULLS LAST
            LIMIT 50
        ];
    }

    // ─────────────────────────────────────────────
    // SOSL 1: Global search across Asset + Ticket
    // ─────────────────────────────────────────────
    public static Map<String, List<SObject>> globalSearch(String keyword) {
        String searchKey = '*' + keyword + '*';

        List<List<SObject>> results = [
            FIND :searchKey
            IN ALL FIELDS
            RETURNING
                Machine_Asset__c(
                    Id, Asset_Name__c, Asset_Status__c,
                    Serial_Number__c,
                    Customer_Site__r.Site_Name__c
                ),
                Service_Ticket__c(
                    Id, Name, Subject__c, Status__c,
                    Priority__c,
                    Machine_Asset__r.Asset_Name__c
                ),
				Customer_Site__c(
                    Id, Site_Name__c, City__c, Site_Status__c,
                    State__c,Total_Installed_Assets__c
                )
            LIMIT 20
        ];

        Map<String, List<SObject>> resultMap = new Map<String, List<SObject>>();
			resultMap.put('assets', results.size() > 0 ? results[0] : new List<SObject>());

			resultMap.put('tickets', results.size() > 1 ? results[1] : new List<SObject>());

			resultMap.put('site', results.size() > 2 ? results[2] : new List<SObject>());

			return resultMap;
    }

    // ─────────────────────────────────────────────
    // SOSL 2: Search technician's tickets + assets
    // ─────────────────────────────────────────────
    public static Map<String, List<SObject>> searchByTechnician(String techName) {
        String searchKey = '*' + techName + '*';

        List<List<SObject>> results = [
            FIND :searchKey
            IN NAME FIELDS
            RETURNING
                Service_Ticket__c(
                    Id, Name, Subject__c, Status__c,
                    Priority__c, SLA_Due_Date__c,
                    Machine_Asset__r.Asset_Name__c,
                    Machine_Asset__r.Customer_Site__r.Site_Name__c
                    WHERE Status__c NOT IN ('Closed', 'Resolved')
                )
            LIMIT 50
        ];

        Map<String, List<SObject>> resultMap = new Map<String, List<SObject>>();
        resultMap.put('tickets', results.size() > 0 ? results[0] : new List<SObject>());
        return resultMap;
    }
}