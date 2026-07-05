@isTest
public class MachineAssetServiceTest {

    // ── helper: create Customer Site ──────────────────────
    private static Customer_Site__c createSite() {
        Customer_Site__c site = new Customer_Site__c(
            Site_Name__c = 'Test Site'
        );
        insert site;
        return site;
    }

    // ── helper: create Machine Asset ──────────────────────
    private static Machine_Asset__c createAsset(Id siteId, String status) {
        Machine_Asset__c asset = new Machine_Asset__c(
            Asset_Name__c    = 'Test Machine',
            Customer_Site__c = siteId,
            Asset_Status__c  = status,
            Serial_Number__c = 'SN-' + String.valueOf(Math.random()).substring(2, 8)
        );
        insert asset;
        return asset;
    }

    // ────────────────────────────────────────────────────────
    // TEST 1: prepareAssets — defaults applied on insert
    // ────────────────────────────────────────────────────────
    @isTest
    static void testPrepareAssets_DefaultsApplied() {
        Customer_Site__c site = createSite();

        Machine_Asset__c asset = new Machine_Asset__c(
            Asset_Name__c    = 'New Machine',
            Customer_Site__c = site.Id,
            Serial_Number__c = 'SN-DEFAULT-001'
        );

        Test.startTest();
        insert asset;
        Test.stopTest();

        Machine_Asset__c result = [
            SELECT Asset_Status__c, Warranty_Start__c, Warranty_End__c
            FROM Machine_Asset__c
            WHERE Id = :asset.Id
        ];

        System.assertEquals('Installed', result.Asset_Status__c,
            'Default status should be Installed');
        System.assertEquals(Date.today(), result.Warranty_Start__c,
            'Warranty start should be today');
        System.assertEquals(Date.today().addYears(1), result.Warranty_End__c,
            'Warranty end should be 1 year from today');
    }

    // ────────────────────────────────────────────────────────
    // TEST 2: prepareAssets — existing values NOT overwritten
    // ────────────────────────────────────────────────────────
    @isTest
    static void testPrepareAssets_ExistingValuesNotOverwritten() {
        Customer_Site__c site = createSite();

        Date customStart = Date.today().addDays(-10);
        Date customEnd   = Date.today().addDays(200);

        Machine_Asset__c asset = new Machine_Asset__c(
            Asset_Name__c    = 'Existing Machine',
            Customer_Site__c = site.Id,
            Serial_Number__c = 'SN-NOOVERWRITE-001',
            Asset_Status__c  = 'Decommissioned',
            Warranty_Start__c = customStart,
            Warranty_End__c   = customEnd
        );

        Test.startTest();
        insert asset;
        Test.stopTest();

        Machine_Asset__c result = [
            SELECT Asset_Status__c, Warranty_Start__c, Warranty_End__c
            FROM Machine_Asset__c
            WHERE Id = :asset.Id
        ];

        System.assertEquals('Decommissioned', result.Asset_Status__c);
        System.assertEquals(customStart, result.Warranty_Start__c);
        System.assertEquals(customEnd, result.Warranty_End__c);
    }

    // ────────────────────────────────────────────────────────
    // TEST 3: validateSerialNumbers — duplicate blocked
    // ────────────────────────────────────────────────────────
    @isTest
    static void testValidateSerialNumbers_DuplicateBlocked() {
        Customer_Site__c site = createSite();

        Machine_Asset__c first = new Machine_Asset__c(
            Asset_Name__c    = 'Machine 1',
            Customer_Site__c = site.Id,
            Serial_Number__c = 'SN-DUPE-001'
        );
        insert first;

        Machine_Asset__c duplicate = new Machine_Asset__c(
            Asset_Name__c    = 'Machine 2',
            Customer_Site__c = site.Id,
            Serial_Number__c = 'SN-DUPE-001'
        );

        Test.startTest();
        try {
            insert duplicate;
            System.assert(false, 'Should have thrown DmlException');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Serial Number already exists'),
                'Error should mention duplicate serial: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

	@isTest
	static void testValidateSerialNumbers_InBatchDuplicatesBlocked() {
    	Customer_Site__c site = createSite();

        List<Machine_Asset__c> batch = new List<Machine_Asset__c>{
            new Machine_Asset__c(Asset_Name__c='Batch A', Customer_Site__c=site.Id, Serial_Number__c='SN-INBATCH-001'),
            new Machine_Asset__c(Asset_Name__c='Batch B', Customer_Site__c=site.Id, Serial_Number__c='SN-INBATCH-001')
        };
    
        Test.startTest();
        List<Database.SaveResult> results = Database.insert(batch, false);
        Test.stopTest();
    
        System.assertEquals(false, results[0].isSuccess(), 'First in-batch duplicate must be blocked');
        System.assertEquals(false, results[1].isSuccess(), 'Second in-batch duplicate must be blocked');
	}

    // ────────────────────────────────────────────────────────
    // TEST 4: handleAssetUpdate — ticket created on Under Maintenance
    // ────────────────────────────────────────────────────────
    @isTest
    static void testHandleAssetUpdate_TicketCreatedOnMaintenance() {
        Customer_Site__c site  = createSite();
        Machine_Asset__c asset = createAsset(site.Id, 'Installed');

        Test.startTest();
        asset.Asset_Status__c = 'Under Maintenance';
        update asset;
        Test.stopTest();

        List<Service_Ticket__c> tickets = [
            SELECT Id, Status__c, Priority__c, Machine_Asset__c, Subject__c
            FROM Service_Ticket__c
            WHERE Machine_Asset__c = :asset.Id
        ];

        System.assertEquals(1, tickets.size(),
            'One ticket should be auto-created when status = Under Maintenance');
        System.assertEquals('Open', tickets[0].Status__c);
        System.assertEquals('Medium', tickets[0].Priority__c);
    }

    // ────────────────────────────────────────────────────────
    // TEST 5: handleAssetUpdate — no ticket if status unchanged
    // ────────────────────────────────────────────────────────
    @isTest
    static void testHandleAssetUpdate_NoTicketIfStatusUnchanged() {
        Customer_Site__c site  = createSite();
        Machine_Asset__c asset = createAsset(site.Id, 'Installed');

        Test.startTest();
        asset.Asset_Name__c = 'Updated Name Only';
        update asset;
        Test.stopTest();

        List<Service_Ticket__c> tickets = [
            SELECT Id FROM Service_Ticket__c
            WHERE Machine_Asset__c = :asset.Id
        ];

        System.assertEquals(0, tickets.size(),
            'No ticket should be created if status did not change');
    }

    // ────────────────────────────────────────────────────────
    // TEST 6: handleAssetUpdate — no ticket for other status changes
    // ────────────────────────────────────────────────────────
    @isTest
    static void testHandleAssetUpdate_NoTicketForOtherStatusChange() {
        Customer_Site__c site  = createSite();
        Machine_Asset__c asset = createAsset(site.Id, 'Installed');

        Test.startTest();
        asset.Asset_Status__c = 'Decommissioned'; // not 'Under Maintenance'
        update asset;
        Test.stopTest();

        List<Service_Ticket__c> tickets = [
            SELECT Id FROM Service_Ticket__c
            WHERE Machine_Asset__c = :asset.Id
        ];

        System.assertEquals(0, tickets.size(),
            'No ticket for non-maintenance status change');
    }

    // ────────────────────────────────────────────────────────
    // TEST 7: testTicketCreationBlocked_WithoutPermission — Check Ticket creation for without permission user for securety.
    // ────────────────────────────────────────────────────────
	@isTest
    static void testTicketCreationBlocked_WithoutPermission() {
    
        // ── LANDMINE 1: Mixed DML ──
        // User is a "setup object". Inserting it in the same transaction as
        // normal records (Site/Asset) throws MIXED_DML_OPERATION.
        // Workaround: wrap setup-object DML in runAs(current user).
        User restrictedUser;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile
                         WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
            restrictedUser = new User(
                Alias             = 'rstrct',
                LastName          = 'Restricted',
                Email             = 'restricted@test.example.com',
                // LANDMINE 2: username must be org-unique — timestamp it
                Username          = 'restricted' + DateTime.now().getTime() + '@test.example.com',
                ProfileId         = p.Id,
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey      = 'en_US',
                TimeZoneSidKey    = 'Asia/Kolkata'
            );
            insert restrictedUser;
        }
    
        // Data as admin — normal helpers
        Customer_Site__c site  = createSite();
        Machine_Asset__c asset = createAsset(site.Id, 'Installed');
    
        Test.startTest();
        System.runAs(restrictedUser) {
            // Minimum Access profile has ZERO create on Service_Ticket__c.
            // The asset update itself runs in system mode (plain Apex DML ignores
            // CRUD), but 'insert as user' inside the trigger enforces the
            // RUNNING user's permissions → SecurityException → our catch → addError.
            asset.Asset_Status__c = 'Under Maintenance';
            Database.SaveResult sr = Database.update(asset, false);
            
            System.assertEquals(false, sr.isSuccess(),
                'Asset update must be blocked when user cannot create tickets');
            
            String msg = sr.getErrors()[0].getMessage();   // safe now — we KNOW errors exist
            System.assert(
                msg.contains('missing permissions') || msg.contains('Ticket creation failed'),
                'Expected our custom block message, got: ' + msg);
        }
        Test.stopTest();
    }
}