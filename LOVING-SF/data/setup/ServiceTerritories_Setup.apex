/**
 * ServiceTerritories_Setup.apex
 *
 * Anonymous Apex setup script — creates the 7 approved LOVING operating market
 * territories. Run once in production after FSL is installed and configured.
 *
 * Prerequisites before running:
 *   1. FSL managed package must be installed in the org.
 *   2. At least one OperatingHours record must exist ("LOVING Operating Hours").
 *   3. Running user must have Field Service Admin or Customize Application permission.
 *
 * How to run:
 *   Setup → Developer Console → Debug → Open Execute Anonymous Window
 *   Paste this script → Execute
 *
 * Safe to re-run: checks for existing territories by Name before inserting.
 *
 * DO NOT run against sandbox without verifying FSL is installed.
 */

// ── Step 1: Confirm FSL is available ──────────────────────────────────────
// If this line throws a compile error, FSL is not installed.
List<ServiceTerritory> existingCheck = [SELECT Id, Name FROM ServiceTerritory LIMIT 1];
System.debug('FSL ServiceTerritory accessible. Existing territory count in org (spot): '
    + existingCheck.size());

// ── Step 2: Get Operating Hours ────────────────────────────────────────────
// Must match exactly the Operating Hours record created in FSL setup.
List<OperatingHours> opHours = [
    SELECT Id, Name FROM OperatingHours
    WHERE Name = 'LOVING Operating Hours'
    LIMIT 1
];

if (opHours.isEmpty()) {
    System.debug('ERROR: OperatingHours record "LOVING Operating Hours" not found. '
        + 'Create it first: Setup → Field Service → Operating Hours → New.');
    return;
}
Id opHoursId = opHours[0].Id;
System.debug('Using OperatingHours: ' + opHours[0].Name + ' (' + opHoursId + ')');

// ── Step 3: Define the 7 approved markets ─────────────────────────────────
List<Map<String, String>> territories = new List<Map<String, String>>{
    new Map<String, String>{
        'Name'          => 'Charlotte - North',
        'DeveloperName' => 'Charlotte_North',
        'Description'   => 'Charlotte North market — includes northern Mecklenburg and southern Iredell.'
    },
    new Map<String, String>{
        'Name'          => 'Charlotte - South',
        'DeveloperName' => 'Charlotte_South',
        'Description'   => 'Charlotte South market — includes southern Mecklenburg, Union County.'
    },
    new Map<String, String>{
        'Name'          => 'Asheville',
        'DeveloperName' => 'Asheville',
        'Description'   => 'Asheville market — includes Buncombe County and surrounding western NC.'
    },
    new Map<String, String>{
        'Name'          => 'Triad',
        'DeveloperName' => 'Triad',
        'Description'   => 'Triad market — includes Greensboro, Winston-Salem, High Point area.'
    },
    new Map<String, String>{
        'Name'          => 'Greenville',
        'DeveloperName' => 'Greenville',
        'Description'   => 'Greenville market — includes Greenville SC and Upstate SC communities.'
    },
    new Map<String, String>{
        'Name'          => 'Columbia',
        'DeveloperName' => 'Columbia',
        'Description'   => 'Columbia market — includes Columbia SC and Midlands SC communities.'
    },
    new Map<String, String>{
        'Name'          => 'Triangle',
        'DeveloperName' => 'Triangle',
        'Description'   => 'Triangle market — includes Raleigh, Durham, Chapel Hill area.'
    }
};

// ── Step 4: Check which territories already exist ─────────────────────────
Set<String> existingNames = new Set<String>();
for (ServiceTerritory st : [
    SELECT Name FROM ServiceTerritory
    WHERE Name IN ('Charlotte - North', 'Charlotte - South', 'Asheville',
                   'Triad', 'Greenville', 'Columbia', 'Triangle')
]) {
    existingNames.add(st.Name);
    System.debug('Already exists — skipping: ' + st.Name);
}

// ── Step 5: Insert missing territories ────────────────────────────────────
List<ServiceTerritory> toInsert = new List<ServiceTerritory>();

for (Map<String, String> t : territories) {
    if (!existingNames.contains(t.get('Name'))) {
        ServiceTerritory st   = new ServiceTerritory();
        st.Name               = t.get('Name');
        st.DeveloperName      = t.get('DeveloperName');
        st.Description        = t.get('Description');
        st.OperatingHoursId   = opHoursId;
        st.IsActive           = true;
        toInsert.add(st);
    }
}

if (toInsert.isEmpty()) {
    System.debug('All 7 territories already exist. Nothing inserted.');
} else {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' territories:');
    for (ServiceTerritory st : toInsert) {
        System.debug('  → ' + st.Name + ' (Id: ' + st.Id + ')');
    }
}

// ── Step 6: Verify final state ─────────────────────────────────────────────
List<ServiceTerritory> finalList = [
    SELECT Id, Name, DeveloperName, IsActive, OperatingHoursId
    FROM ServiceTerritory
    WHERE Name IN ('Charlotte - North', 'Charlotte - South', 'Asheville',
                   'Triad', 'Greenville', 'Columbia', 'Triangle')
    ORDER BY Name
];

System.debug('=== FINAL STATE — 7 Approved Markets ===');
for (ServiceTerritory st : finalList) {
    System.debug('MARKET: ' + st.Name
        + ' | DeveloperName: ' + st.DeveloperName
        + ' | Active: ' + st.IsActive
        + ' | Id: ' + st.Id);
}

if (finalList.size() < 7) {
    System.debug('WARNING: Only ' + finalList.size() + ' of 7 territories found. '
        + 'Check for duplicates or naming differences.');
} else {
    System.debug('SUCCESS: All 7 approved markets are present and active.');
}
