export const endpoints = {
  myDay: '/services/apexrest/loving/mobile/v1/my-day',
  serviceAppointmentDetail: (serviceAppointmentId: string) =>
    `/services/apexrest/loving/mobile/v1/service-appointments/${serviceAppointmentId}`,
  workOrderDetail: (workOrderId: string) =>
    `/services/apexrest/loving/mobile/v1/work-orders/${workOrderId}`,
  syncBatch: '/services/apexrest/loving/mobile/v1/sync/batch'
} as const;
