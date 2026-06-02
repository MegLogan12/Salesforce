trigger ODLTaskTrigger on Task (after insert, after update) {
    ODLInboundResponseService.stampFromTasks(Trigger.new);
}