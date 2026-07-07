public with sharing class PMSchedulerBatch implements Schedulable {

    public void execute(SchedulableContext ctx) {
        // Salesforce calls this method at 2 AM.
        // What should happen here, bro? 🤔
		List<String> errors = PMSchedulerService.processDueSchedules();
        if(!errors.isEmpty()){
            User admin = [SELECT Email FROM User
                          WHERE Profile.Name = 'System Administrator'
                          AND IsActive = true LIMIT 1];
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ admin.Email });
            mail.setSubject('PM Scheduler: errors during last night run');
            mail.setPlainTextBody(
                'The PM Scheduler job ran at 2 AM and hit the following errors.\n' +
                'Failed schedules will retry automatically tomorrow night.\n\n' +
                'Errors:\n' + String.join(errors, '\n')
            );
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        }
        
    }
}