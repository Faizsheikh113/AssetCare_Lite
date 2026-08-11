@IsTest
private class PMSchedulerServiceTest {

    @TestSetup
    static void makeData(){
        createSchedule();
    }

    private static Customer_Site__c createSite() {
        Customer_Site__c site = new Customer_Site__c(
            Site_Name__c   = 'PM_Test_Site',
            Site_Status__c = 'Active'
        );
        insert site;
        return site;
    }

    private static Machine_Asset__c createAsset() {
        Customer_Site__c site = createSite();
        Machine_Asset__c asset = new Machine_Asset__c(
            Asset_Name__c    = 'PM_Test_Machine',
            Customer_Site__c = site.Id,
            Asset_Status__c  = 'Active',
            Serial_Number__c = 'SN-' + String.valueOf(Math.random()).substring(2, 8)
        );
        insert asset;
        return asset;
    }

    private static PM_Schedule__c createSchedule() {
        Machine_Asset__c asset  = createAsset();
        PM_Schedule__c schedule = new PM_Schedule__c(
            Machine_Asset__c = asset.Id,
            Interval_Days__c = 30
        );
        insert schedule;
        return schedule;
    }

    // Helper for Tests 4, 5, 6, 7 — makes a fresh site+asset+schedule
    // that is DUE (blank Last_Run__c, but this time on its OWN asset,
    // so we can make many of these without them tangling with @TestSetup
    // or with each other).
    private static PM_Schedule__c createDueScheduleOnNewAsset(String uniqueSuffix) {
        Customer_Site__c site = new Customer_Site__c(
            Site_Name__c   = 'PM_Test_Site_' + uniqueSuffix,
            Site_Status__c = 'Active'
        );
        insert site;

        Machine_Asset__c asset = new Machine_Asset__c(
            Asset_Name__c    = 'PM_Test_Machine_' + uniqueSuffix,
            Customer_Site__c = site.Id,
            Asset_Status__c  = 'Active',
            Serial_Number__c = 'SN-' + uniqueSuffix
        );
        insert asset;

        PM_Schedule__c schedule = new PM_Schedule__c(
            Machine_Asset__c = asset.Id,
            Interval_Days__c = 30
        );
        insert schedule;
        return schedule;
    }

    @IsTest
    static void dueSchedule_createsTicketAndStamps() {
        PM_Schedule__c sched = [SELECT Id, Last_Run__c FROM PM_Schedule__c LIMIT 1];

        Test.startTest();
        PMSchedulerService.processDueSchedules();
        Test.stopTest();

        List<Service_Ticket__c> tickets = [
            SELECT Id, Ticket_Type__c, Status__c, Priority__c
            FROM Service_Ticket__c
        ];
        Assert.areEqual(1, tickets.size(), 'One Maintenance ticket should be created');
        Assert.areEqual('Maintenance', tickets[0].Ticket_Type__c, 'Type must be Maintenance');
        Assert.areEqual('Open', tickets[0].Status__c, 'Status must be Open');
        Assert.areEqual('Medium', tickets[0].Priority__c, 'Priority must be Medium');

        PM_Schedule__c after = [SELECT Id, Last_Run__c FROM PM_Schedule__c WHERE Id = :sched.Id];
        Assert.areNotEqual(null, after.Last_Run__c, 'Last_Run should be stamped after success');
    }

    @IsTest
    static void recentlyRunSchedule_createsNothing() {
        Customer_Site__c site = new Customer_Site__c(
            Site_Name__c   = 'PM_Test_Site_Recent',
            Site_Status__c = 'Active'
        );
        insert site;

        Machine_Asset__c asset = new Machine_Asset__c(
            Asset_Name__c    = 'PM_Test_Machine_Recent',
            Customer_Site__c = site.Id,
            Asset_Status__c  = 'Active',
            Serial_Number__c = 'SN-RECENT-01'
        );
        insert asset;

        PM_Schedule__c recentSched = new PM_Schedule__c(
            Machine_Asset__c = asset.Id,
            Interval_Days__c = 30,
            Last_Run__c      = System.now()
			
        );
        insert recentSched;


        Test.startTest();
        PMSchedulerService.processDueSchedules();
        Test.stopTest();

        // Filtered to THIS asset only — doesn't depend on what @TestSetup's schedule does.
        List<Service_Ticket__c> ticketsForThisAsset = [
            SELECT Id FROM Service_Ticket__c WHERE Machine_Asset__c = :asset.Id
        ];
        Assert.areEqual(0, ticketsForThisAsset.size(), 'No ticket should be created for a schedule that ran recently and is not yet due');
    }

    // ---------- TEST 3 — inactive schedule, overdue by date, still skipped ----------
    @IsTest
    static void inactiveSchedule_createsNothing() {
        Customer_Site__c site = new Customer_Site__c(
            Site_Name__c   = 'PM_Test_Site_Inactive',
            Site_Status__c = 'Active'
        );
        insert site;

        Machine_Asset__c asset = new Machine_Asset__c(
            Asset_Name__c    = 'PM_Test_Machine_Inactive',
            Customer_Site__c = site.Id,
            Asset_Status__c  = 'Active',
            Serial_Number__c = 'SN-INACTIVE-01'
        );
        insert asset;

        PM_Schedule__c inactiveSched = new PM_Schedule__c(
            Machine_Asset__c = asset.Id,
            Interval_Days__c = 30,
            Active__c        = false
        );
        insert inactiveSched;

        Test.startTest();
        PMSchedulerService.processDueSchedules();
        Test.stopTest();

        List<Service_Ticket__c> ticketsForThisAsset = [
            SELECT Id FROM Service_Ticket__c WHERE Machine_Asset__c = :asset.Id
        ];
        Assert.areEqual(0, ticketsForThisAsset.size(), 'No ticket should be created for an inactive schedule, even if overdue by date');
    }

    // ---------- TEST 4 — multiple due schedules (bulk) ----------
    @IsTest
    static void multipleDueSchedules_createsTicketForEach() {
        // WHY THIS TEST MATTERS: your class runs SOQL and DML OUTSIDE the for-loop
        // (good — bulk-safe by design), but you've never actually PROVEN that with
        // more than one record. This test creates 5 due schedules and checks
        // that 5 tickets come out. If someone ever "fixes" your code and
        // accidentally moves DML inside the loop, or breaks the results[i] /
        // activeSchedules[i] index matching, this test is what catches it.

        List<PM_Schedule__c> dueSchedules = new List<PM_Schedule__c>();
        for (Integer i = 0; i < 5; i++) {
            dueSchedules.add(createDueScheduleOnNewAsset('BULK' + i));
        }

        Test.startTest();
        PMSchedulerService.processDueSchedules();
        Test.stopTest();

        // We expect 5 tickets from the 5 NEW schedules, PLUS 1 from @TestSetup's
        // own schedule (which is also due — blank Last_Run__c). So total = 6.
        // THINK ABOUT THIS LINE when you review: did you expect 5 or 6?
        // If you expected 5, you forgot @TestSetup's schedule is ALSO due.
        List<Service_Ticket__c> allTickets = [SELECT Id FROM Service_Ticket__c];
        Assert.areEqual(6, allTickets.size(), 'One ticket should be created per due schedule, including the @TestSetup one');

        // Also confirm each of the 5 new schedules individually got stamped.
        List<Id> newScheduleIds = new List<Id>();
        for (PM_Schedule__c s : dueSchedules) {
            newScheduleIds.add(s.Id);
        }
        List<PM_Schedule__c> stamped = [
            SELECT Id, Last_Run__c FROM PM_Schedule__c WHERE Id IN :newScheduleIds AND Last_Run__c != null
        ];
        Assert.areEqual(5, stamped.size(), 'All 5 new due schedules should be stamped with Last_Run__c');
    }

	// ---------- TEST 5 — partial DML failure (allOrNone = false) ----------
    @IsTest
    static void partialFailure_onlySuccessfulScheduleIsStamped() {
        // Machine_Asset__c is required on Service_Ticket__c.
        // Machine_Asset__c is optional on PM_Schedule__c.
        // ticket.Machine_Asset__c = schedule.Machine_Asset__c always copies straight across —
        // so a schedule with a BLANK Machine_Asset__c produces a ticket with a blank
        // required field, which fails with REQUIRED_FIELD_MISSING. This is a real,
        // guaranteed failure — no validation rule needed.
    
        PM_Schedule__c goodSchedule = createDueScheduleOnNewAsset('GOOD');
    
        // "Bad" schedule: due today, but with NO Machine_Asset__c at all.
        PM_Schedule__c badSchedule = new PM_Schedule__c(
            Interval_Days__c = 30
            // Machine_Asset__c left blank on purpose — this is the failure trigger.
            // Last_Run__c left blank too → still due today, same as other due schedules.
        );
        insert badSchedule;
    
        Test.startTest();
        List<String> errors = PMSchedulerService.processDueSchedules();
        Test.stopTest();
    
        // GOOD schedule should be stamped — its ticket succeeded.
        PM_Schedule__c goodAfter = [SELECT Id, Last_Run__c FROM PM_Schedule__c WHERE Id = :goodSchedule.Id];
        Assert.areNotEqual(null, goodAfter.Last_Run__c, 'The successful schedule should be stamped');
    
        // BAD schedule should NOT be stamped — its ticket failed due to the missing
        // required Machine_Asset__c, so it retries tomorrow (your D9 rule).
        PM_Schedule__c badAfter = [SELECT Id, Last_Run__c FROM PM_Schedule__c WHERE Id = :badSchedule.Id];
        Assert.areEqual(null, badAfter.Last_Run__c, 'The failed schedule should NOT be stamped, so it retries tomorrow');
    
        // Exactly one error should be reported, for the one blocked ticket.
        Assert.areEqual(1, errors.size(), 'One error should be reported for the failed ticket insert');
    }

    // ---------- TEST 6 — zero due schedules, no exception, clean empty return ----------
    @IsTest
    static void noDueSchedules_returnsEmptyErrorsAndNoException() {
        // WHY THIS TEST MATTERS: proves the "nothing to do" path doesn't blow up.
        // Your method has an `if (!serviceTickets.isEmpty())` guard around the
        // whole DML block — this test proves that guard actually works when
        // the list is truly empty, instead of throwing a null-pointer or
        // an empty-DML exception.
        //
        // We need ZERO due schedules, but @TestSetup already inserted one
        // that IS due (blank Last_Run__c). So we must first stamp it as
        // "already run" so it's no longer due, before calling the method.

        PM_Schedule__c sched = [SELECT Id FROM PM_Schedule__c LIMIT 1];
        sched.Last_Run__c = System.now(); // stamp it as run today → not due
        update sched;

        Test.startTest();
        List<String> errors = PMSchedulerService.processDueSchedules();
        Test.stopTest();

        Assert.areEqual(0, errors.size(), 'No errors should be returned when there is nothing to process');

        List<Service_Ticket__c> tickets = [SELECT Id FROM Service_Ticket__c];
        Assert.areEqual(0, tickets.size(), 'No tickets should be created when nothing is due');
    }
}