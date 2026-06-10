import { SalesforceService } from '@/salesforce/SalesforceService';

async function main() {
  const instanceUrl = process.env.EXPO_PUBLIC_SF_INSTANCE_URL;
  const accessToken = process.env.EXPO_PUBLIC_SF_ACCESS_TOKEN;
  const serviceResourceId = process.env.SMOKE_SERVICE_RESOURCE_ID ?? '0HnVu0000007nbtKAA';
  const date = process.env.SMOKE_DATE ?? '2026-05-13';

  if (!instanceUrl || !accessToken) {
    throw new Error('Missing EXPO_PUBLIC_SF_INSTANCE_URL or EXPO_PUBLIC_SF_ACCESS_TOKEN');
  }

  const service = new SalesforceService({ instanceUrl, accessToken });
  const myDay = await service.getMyDay(serviceResourceId, date);
  const first = myDay.serviceAppointments[0];
  if (!first) {
    throw new Error(`No appointments returned for resource ${serviceResourceId} on ${date}`);
  }

  const appointmentDetail = await service.getServiceAppointmentDetail(first.id);
  const workOrderId = appointmentDetail.workOrderId;
  if (!workOrderId) {
    throw new Error(`Appointment ${first.id} returned no related WorkOrder`);
  }
  const workOrderDetail = await service.getWorkOrderDetail(workOrderId, first.id);

  console.log(
    JSON.stringify(
      {
        resourceId: serviceResourceId,
        date,
        appointmentIds: myDay.serviceAppointments.map((row) => row.id),
        firstAppointmentId: first.id,
        firstWorkOrderId: workOrderId,
        workType: appointmentDetail.workTypeName,
        market: appointmentDetail.marketName,
        missingAppointmentFlags: appointmentDetail.missingDataFlags,
        missingWorkOrderFlags: workOrderDetail.missingDataFlags
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
