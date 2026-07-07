public with sharing class PMSchedulerService {
    public static List<String> processDueSchedules() {
        List<PM_Schedule__c> activeschedules = [ SELECT Id, Name, Machine_Asset__c, Machine_Asset__r.Asset_Name__c From PM_Schedule__c 
                                                WHERE Active__c = true AND Next_Run__c <= TODAY LIMIT 200 ];
        List<Service_Ticket__c> serviceTicket = new List<Service_Ticket__c>();
        List<String> errors = new List<String>();
        
        for(PM_Schedule__c schedule : activeschedules ){
            
                    String ticketType = 'Maintenance';
                    Service_Ticket__c ticket = new Service_Ticket__c();
                    ticket.Machine_Asset__c = schedule.Machine_Asset__c;
                    ticket.Subject__c       = 'PM Due: ' + schedule.Machine_Asset__r.Asset_Name__c + ' needs maintenance';
                    ticket.Status__c        = 'Open';
                    ticket.Priority__c      = 'Medium';
                    ticket.Ticket_Type__c   = ticketType;
                    ticket.SLA_Level__c     = 'Bronze';
                    ticket.SLA_Due_Date__c  = DateTime.now().addHours(48);
                    serviceTicket.add(ticket);
        }
        if(!serviceTicket.isEmpty()){
                try {
                      insert as user serviceTicket;
                      List<PM_Schedule__c> schedulesToStamp = new List<PM_Schedule__c>();
                      for(PM_Schedule__c schedule : activeschedules){
                          schedulesToStamp.add(new PM_Schedule__c(
                              Id          = schedule.Id,
                              Last_Run__c = DateTime.now()
                          ));
                      }
                      update as user schedulesToStamp;
                    } catch (System.SecurityException e) {
                        errors.add('Permission error: ' + e.getMessage());
                    } catch (DmlException e) {
                        errors.add('Ticket insert failed: ' + e.getDmlMessage(0));
                    }
        }
        return errors;
    }
}