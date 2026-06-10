/**
 * LovingTestContext
 * -----------------------------------------------------------------------------
 * Shared Apex-test helper that works around a platform quirk in this org:
 *
 *   A user with "View All Data" / "Modify All Data" CANNOT insert Account
 *   records inside an Apex test context. The insert fails with
 *   INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY (cross-reference id: []).
 *   A System Administrator user WITHOUT View-All/Modify-All inserts Accounts
 *   fine. Because every admin who runs a deploy has View All Data, RunLocalTests
 *   trips on every test class that inserts an Account.
 *
 * Proven head-to-head: full-MAD admin → fail, minimal (MAD=false) admin → ok.
 *
 * Fix: create test data while running as a minimal-privilege System Administrator
 *      via System.runAs(LovingTestContext.minimalAdmin()) { ... }.
 *
 * This changes NOTHING about production permissions or runtime behavior — it only
 * controls which user the *test* uses to create its fixture data.
 *
 * Usage in @TestSetup (or any test method that inserts Accounts):
 *
 *   @TestSetup static void makeData() {
 *       System.runAs(LovingTestContext.minimalAdmin()) {
 *           // ... all record DML (Account, WorkOrder, custom objects) ...
 *       }
 *   }
 *
 * If the setup ALSO inserts User records, create/insert those Users OUTSIDE the
 * runAs(minimalAdmin) block (User DML is "setup-object" DML and must be isolated
 * from the non-setup DML to avoid MIXED_DML_OPERATION). minimalAdmin() already
 * isolates its own User insert, so you can call it freely.
 */
@IsTest
public class LovingTestContext {

    private static User cachedAdmin;

    /**
     * Returns (creating once per transaction) a minimal-privilege System Administrator
     * user that can insert Accounts in test context. The User DML is isolated in its own
     * System.runAs context so callers never hit MIXED_DML_OPERATION.
     */
    public static User minimalAdmin() {
        if (cachedAdmin != null) return cachedAdmin;
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id profileId = resolveMinimalAdminProfileId();
            // Unique-but-deterministic-enough username; CrytoUtil-free to avoid governor noise.
            String uniq = String.valueOf(System.currentTimeMillis())
                        + String.valueOf(Math.abs(UserInfo.getUserId().hashCode()));
            u = new User(
                Username          = 'ltc.' + uniq + '@loving.test.invalid',
                Email             = 'ltc.admin@loving.test.invalid',
                LastName          = 'LovingTestAdmin',
                Alias             = 'ltcadm',
                ProfileId         = profileId,
                TimeZoneSidKey    = 'America/New_York',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            );
            insert u;
        }
        cachedAdmin = u;
        return u;
    }

    /**
     * Prefer a System Administrator profile WITHOUT Modify All Data (the combination that
     * can insert Accounts in test context). Fall back progressively so this never throws
     * in an org whose profile names differ.
     */
    private static Id resolveMinimalAdminProfileId() {
        // Primary: the dedicated test-runner profile created for this purpose.
        List<Profile> ps = [
            SELECT Id FROM Profile
            WHERE Name = 'LOVING Test Runner (Minimal Admin)' AND PermissionsModifyAllData = false
            LIMIT 1
        ];
        if (!ps.isEmpty()) return ps[0].Id;

        // Backward-compat: catch the pre-rename profile name if it ever resurfaces in another org.
        ps = [
            SELECT Id FROM Profile
            WHERE Name = 'System Administrator' AND PermissionsModifyAllData = false
            LIMIT 1
        ];
        if (!ps.isEmpty()) return ps[0].Id;

        ps = [SELECT Id FROM Profile WHERE PermissionsModifyAllData = false AND UserLicense.Name = 'Salesforce'
              ORDER BY Name LIMIT 1];
        if (!ps.isEmpty()) return ps[0].Id;

        // Last resort: any Salesforce-license profile.
        return [SELECT Id FROM Profile WHERE UserLicense.Name = 'Salesforce' ORDER BY Name LIMIT 1].Id;
    }
}