public with sharing class PMSchedulerService {
    public static List<String> processDueSchedules() {
        List<PM_Schedule__c> activeSchedules = [ SELECT Id, Name, Machine_Asset__c, Machine_Asset__r.Asset_Name__c From PM_Schedule__c 
                                                WHERE Active__c = true AND Next_Run__c <= TODAY LIMIT 200 ];
        List<Service_Ticket__c> serviceTickets = new List<Service_Ticket__c>();
        List<String> errors = new List<String>();
        
        for(PM_Schedule__c schedule : activeSchedules ){
            
                    String ticketType = 'Maintenance';
                    Service_Ticket__c ticket = new Service_Ticket__c();
                    ticket.Machine_Asset__c = schedule.Machine_Asset__c;
                    ticket.Subject__c       = 'PM Due: ' + schedule.Machine_Asset__r.Asset_Name__c + ' needs maintenance';
                    ticket.Status__c        = 'Open';
                    ticket.Priority__c      = 'Medium';
                    ticket.Ticket_Type__c   = ticketType;
                    ticket.SLA_Level__c     = 'Bronze';
                    ticket.SLA_Due_Date__c  = DateTime.now().addHours(48);
                    serviceTickets.add(ticket);
        }
        if(!serviceTickets.isEmpty()){
                try {
                      List<Database.SaveResult> results = Database.insert(serviceTickets, false, AccessLevel.USER_MODE);
                      List<PM_Schedule__c> schedulesToStamp = new List<PM_Schedule__c>();

                        for (Integer i = 0; i < results.size(); i++) {
                            if (results[i].isSuccess()) {
                                // winner → stamp its schedule
                                schedulesToStamp.add(new PM_Schedule__c(
                                    Id          = activeSchedules[i].Id,
                                    Last_Run__c = DateTime.now()
                                ));
                            } else {
                                // loser → report it, do NOT stamp (retries tomorrow — D9 lives!)
                                errors.add('Schedule ' + activeSchedules[i].Name + ': '
                                           + results[i].getErrors()[0].getMessage());
                            }
                        }
                        
                        if (!schedulesToStamp.isEmpty()) {
                            update as user schedulesToStamp;
                        }
                    } catch (System.SecurityException e) {
                        errors.add('Permission error: ' + e.getMessage());
                    } catch (DmlException e) {
                        errors.add('Ticket insert failed: ' + e.getDmlMessage(0));
                    }
        }
        return errors;
    }
}