trigger ODLEventTrigger on Event (after insert, after update) {
    ODLInboundResponseService.stampFromEvents(Trigger.new);
}
