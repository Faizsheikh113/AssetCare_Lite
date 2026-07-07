@isTest
public class AssetQueryServiceTest {
// ──────────────────────────────────────────────
    // TEST DATA SETUP — shared across all test methods
    // ──────────────────────────────────────────────
@TestSetup
    static void setupTestData() {
        // ---- Customer Sites ----
        Customer_Site__c activeSite = new Customer_Site__c(
            Site_Name__c   = 'Test Active Site',
            City__c        = 'Indore',
            State__c       = 'Madhya Pradesh',
            Site_Status__c = 'Active'
        );
        Customer_Site__c inactiveSite = new Customer_Site__c(
            Site_Name__c   = 'Test Inactive Site',
            City__c        = 'Bhopal',
            State__c       = 'Madhya Pradesh',
            Site_Status__c = 'Maintenance'
        );
        insert new List<Customer_Site__c>{ activeSite, inactiveSite };

        // ---- Machine Assets ----
        Machine_Asset__c serviceDueAsset = new Machine_Asset__c(
            Asset_Name__c     = 'Service Due Test Asset',
            Serial_Number__c  = 'SN-TEST-SD-001',
            Product_Type__c   = 'Compressor',
            Asset_Status__c   = 'Service Due',
            Customer_Site__c  = activeSite.Id,
            Warranty_Start__c = Date.today().addYears(-1),
            Warranty_End__c   = Date.today().addYears(1)
        );

        Machine_Asset__c expiredWarrantyAsset = new Machine_Asset__c(
            Asset_Name__c     = 'Expired Warranty Test Asset',
            Serial_Number__c  = 'SN-TEST-EW-001',
            Product_Type__c   = 'Motor',
            Asset_Status__c   = 'Active',
            Customer_Site__c  = activeSite.Id,
            Warranty_Start__c = Date.today().addYears(-5),
            Warranty_End__c   = Date.today().addDays(-30)
        );

        Machine_Asset__c activeAssetOnInactiveSite = new Machine_Asset__c(
            Asset_Name__c     = 'Asset On Inactive Site',
            Serial_Number__c  = 'SN-TEST-IS-001',
            Product_Type__c   = 'Generator',
            Asset_Status__c   = 'Service Due',
            Customer_Site__c  = inactiveSite.Id
        );

        insert new List<Machine_Asset__c>{
            serviceDueAsset, expiredWarrantyAsset, activeAssetOnInactiveSite
        };

        // ---- Service Tickets ----
        Service_Ticket__c breachedTicket = new Service_Ticket__c(
            Machine_Asset__c = serviceDueAsset.Id,
            Subject__c       = 'SLA Breach Test Ticket',
            Status__c        = 'Assigned',
            Priority__c      = 'High',
            Ticket_Type__c   = 'Hardware Issue',
            SLA_Level__c     = 'Gold',
			Description__c   = 'This is for testing',
            SLA_Due_Date__c  = DateTime.now().addDays(-2)
        );

        Service_Ticket__c openTicket = new Service_Ticket__c(
            Machine_Asset__c = expiredWarrantyAsset.Id,
            Subject__c       = 'Open Ticket Test',
            Status__c        = 'In Progress',
            Priority__c      = 'Medium',
            Ticket_Type__c   = 'Inspection',
            SLA_Level__c     = 'Silver',
            SLA_Due_Date__c  = DateTime.now().addDays(2)
        );

        Service_Ticket__c closedTicket = new Service_Ticket__c(
            Machine_Asset__c = serviceDueAsset.Id,
            Subject__c       = 'Closed Ticket Test',
            Status__c        = 'Closed',
            Priority__c      = 'Low',
            Ticket_Type__c   = 'General Inquiry',
            SLA_Level__c     = 'Bronze',
            Resolution_Notes__c = 'Ticket Resolved',
            SLA_Due_Date__c  = DateTime.now().addDays(-10)
        );

        insert new List<Service_Ticket__c>{ breachedTicket, openTicket, closedTicket };
    }

	@isTest
    static void testGetServiceDueAssets() {
        Test.startTest();
        List<Machine_Asset__c> results = AssetQueryService.getServiceDueAssets();
        Test.stopTest();

        System.assertEquals(1, results.size(),
            'Only the Service Due asset on an Active site should return');
        System.assertEquals('Service Due Test Asset', results[0].Asset_Name__c);
    }

    // ──────────────────────────────────────────────
    // TEST 2: getOpenTicketCountPerSite
    // ──────────────────────────────────────────────
    @isTest
    static void testGetOpenTicketCountPerSite() {
        Test.startTest();
        List<AggregateResult> results = AssetQueryService.getOpenTicketCountPerSite();
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Should return at least one grouped site');

        Boolean foundActiveSite = false;
        for (AggregateResult ar : results) {
            if (ar.get('siteName') == 'Test Active Site') {
                foundActiveSite = true;
                System.assertEquals(2, (Integer) ar.get('ticketCount'),
    								'Two open tickets should count for Test Active Site (closed ticket excluded)');
            }
        }
        System.assert(foundActiveSite, 'Test Active Site should appear in grouped results');
    }

    // ──────────────────────────────────────────────
    // TEST 3: getWarrantyExpiredAssets
    // ──────────────────────────────────────────────
    @isTest
    static void testGetWarrantyExpiredAssets() {
        Test.startTest();
        List<Machine_Asset__c> results = AssetQueryService.getWarrantyExpiredAssets();
        Test.stopTest();

        System.assertEquals(1, results.size(),
            'Only the asset with past Warranty_End__c and non-expired status should return');
        System.assertEquals('Expired Warranty Test Asset', results[0].Asset_Name__c);
    }

    // ──────────────────────────────────────────────
    // TEST 4: getSLABreachedTickets
    // ──────────────────────────────────────────────
    @isTest
    static void testGetSLABreachedTickets() {
        Test.startTest();
        List<Service_Ticket__c> results = AssetQueryService.getSLABreachedTickets();
        Test.stopTest();

        System.assertEquals(1, results.size(),
            'Only the open ticket with a past SLA Due Date should return');
        System.assertEquals('SLA Breach Test Ticket', results[0].Subject__c);
    }

    // ──────────────────────────────────────────────
    // TEST 5: getSitesWithAssets
    // ──────────────────────────────────────────────
    @isTest
    static void testGetSitesWithAssets() {
        Test.startTest();
        List<Customer_Site__c> results = AssetQueryService.getSitesWithAssets();
        Test.stopTest();

        System.assertEquals(1, results.size(),
            'Only Active sites should return (Maintenance site excluded)');
        System.assertEquals('Test Active Site', results[0].Site_Name__c);
        System.assertEquals(2, results[0].Machine_Assets__r.size(),
            'Active site should have 2 related Machine Assets');
    }

    // ──────────────────────────────────────────────
    // TEST 6: globalSearch (SOSL)
    // ──────────────────────────────────────────────
    @isTest
    static void testGlobalSearch() {
        // Fetch real Ids inserted in setup to simulate SOSL index results
        Machine_Asset__c asset = [
            SELECT Id FROM Machine_Asset__c
            WHERE Asset_Name__c = 'Service Due Test Asset'
            LIMIT 1
        ];
        Service_Ticket__c ticket = [
            SELECT Id FROM Service_Ticket__c
            WHERE Subject__c = 'SLA Breach Test Ticket'
            LIMIT 1
        ];
        Customer_Site__c site = [
            SELECT Id FROM Customer_Site__c
            WHERE Site_Name__c = 'Test Active Site'
            LIMIT 1
        ];

        Test.setFixedSearchResults(new List<Id>{ asset.Id, ticket.Id, site.Id });

        Test.startTest();
        Map<String, List<SObject>> results = AssetQueryService.globalSearch('Test');
        Test.stopTest();

        System.assert(results.containsKey('assets'), 'Result map should contain assets key');
        System.assert(results.containsKey('tickets'), 'Result map should contain tickets key');
        System.assert(results.containsKey('site'), 'Result map should contain site key');
    }

    // ──────────────────────────────────────────────
    // TEST 7: searchByTechnician (SOSL)
    // ──────────────────────────────────────────────
    @isTest
    static void testSearchByTechnician() {
        Service_Ticket__c ticket = [
            SELECT Id FROM Service_Ticket__c
            WHERE Subject__c = 'SLA Breach Test Ticket'
            LIMIT 1
        ];

        Test.setFixedSearchResults(new List<Id>{ ticket.Id });

        Test.startTest();
        Map<String, List<SObject>> results = AssetQueryService.searchByTechnician('Faiz');
        Test.stopTest();

        System.assert(results.containsKey('tickets'), 'Result map should contain tickets key');
    }

    // ──────────────────────────────────────────────
    // TEST 8: Bulk test — confirm methods don't break on larger data volume
    // ──────────────────────────────────────────────
    @isTest
    static void testBulkServiceDueAssets() {
        Customer_Site__c bulkSite = new Customer_Site__c(
            Site_Name__c   = 'Bulk Test Site',
            Site_Status__c = 'Active'
        );
        insert bulkSite;

        List<Machine_Asset__c> bulkAssets = new List<Machine_Asset__c>();
        for (Integer i = 0; i < 50; i++) {
            bulkAssets.add(new Machine_Asset__c(
                Asset_Name__c    = 'Bulk Asset ' + i,
                Serial_Number__c = 'SN-BULK-' + i,
                Product_Type__c  = 'Compressor',
                Asset_Status__c  = 'Service Due',
                Customer_Site__c = bulkSite.Id
            ));
        }

        Test.startTest();
        insert bulkAssets;
        List<Machine_Asset__c> results = AssetQueryService.getServiceDueAssets();
        Test.stopTest();

        System.assert(results.size() >= 50,
            'Bulk insert of 50 Service Due assets should be reflected in query results');
    }
}