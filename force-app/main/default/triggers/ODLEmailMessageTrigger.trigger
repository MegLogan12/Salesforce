trigger ODLEmailMessageTrigger on EmailMessage (after insert) {
    ODLInboundResponseService.stampFromEmailMessages(Trigger.new);
}
