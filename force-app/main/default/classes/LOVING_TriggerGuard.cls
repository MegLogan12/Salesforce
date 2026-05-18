/**
 * LOVING_TriggerGuard
 * Prevents recursive trigger execution across all LOVING triggers.
 * Usage: check hasAlreadyRun() at the top of every trigger; call setAlreadyRun() before delegating.
 */
public class LOVING_TriggerGuard {
    private static Set<String> processedObjects = new Set<String>();

    public static Boolean hasAlreadyRun(String objectName) {
        return processedObjects.contains(objectName);
    }

    public static void setAlreadyRun(String objectName) {
        processedObjects.add(objectName);
    }

    public static void clearAlreadyRun(String objectName) {
        processedObjects.remove(objectName);
    }

    @TestVisible
    public static void reset() {
        processedObjects.clear();
    }
}
