public class DivisionKpiScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        DivisionKpiRecalcBatch.run();
    }
}
