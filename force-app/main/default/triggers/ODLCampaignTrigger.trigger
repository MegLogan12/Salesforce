trigger ODLCampaignTrigger on Campaign (after insert) {
    ODLVoucherLifecycleService.ensureCampaignMemberStatuses(Trigger.new);
}