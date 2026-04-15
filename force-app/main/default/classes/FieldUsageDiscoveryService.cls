/**
 * @description Service to analyze field fill rates and dependency metadata.
 */
public with sharing class FieldUsageDiscoveryService {
    public class FieldInput {
        public String objectApiName;
        public String fieldApiName;
        public Decimal fillRate;
        public Integer totalCount;
        public Integer filledCount;
        public FieldInput() {}
        public FieldInput(String objectApi, String fieldApi) {
            objectApiName = objectApi;
            fieldApiName = fieldApi;
        }
    }

    public class DependencyInfo {
        public String componentType;
        public String componentName;
        public DependencyInfo(String typeName, String name) {
            componentType = typeName;
            componentName = name;
        }
    }

    public class FieldResult {
        public String objectApiName;
        public String fieldApiName;
        public String label;
        public String dataType;
        public Decimal fillRate;
        public Integer totalCount;
        public Integer filledCount;
        public List<DependencyInfo> dependencies = new List<DependencyInfo>();
        public List<String> permissionSets = new List<String>();
        public List<String> profiles = new List<String>();
        public List<String> notes = new List<String>();
    }

    public class DiscoveryOptions {
        public Boolean sampleFillRate;
        public Boolean includeToolingDependencies;
        public Boolean includeFieldPermissions;
        public DiscoveryOptions() {
            sampleFillRate = true;
            includeToolingDependencies = true;
            includeFieldPermissions = true;
        }
    }

    /**
     * @description Analyze a list of fields.
     * @param inputs Field inputs.
     * @param options Options.
     * @return List of results.
     */
    public static List<FieldResult> analyze(List<FieldInput> inputs, DiscoveryOptions options) {
        List<FieldResult> results = new List<FieldResult>();
        if (inputs == null || inputs.isEmpty()) {
            return results;
        }
        if (options == null) {
            options = new DiscoveryOptions();
        }
        for (FieldInput input : inputs) {
            FieldResult result = analyzeSingle(input, options);
            results.add(result);
        }
        return results;
    }

    private static FieldResult analyzeSingle(FieldInput input, DiscoveryOptions options) {
        FieldResult result = new FieldResult();
        result.objectApiName = input.objectApiName;
        result.fieldApiName = input.fieldApiName;

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(input.objectApiName);
        if (objType == null) {
            result.notes.add('Object not found');
            return result;
        }
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        if (!objDescribe.isAccessible()) {
            result.notes.add('Object not accessible for current user');
            return result;
        }
        Schema.SObjectField fieldToken = objDescribe.fields.getMap().get(input.fieldApiName);
        if (fieldToken == null) {
            result.notes.add('Field not found');
            return result;
        }
        Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
        if (!fieldDescribe.isAccessible()) {
            result.notes.add('Field not accessible for current user');
            return result;
        }
        result.label = fieldDescribe.getLabel();
        result.dataType = String.valueOf(fieldDescribe.getType());

        if (options.sampleFillRate && (input.totalCount == null || input.filledCount == null)) {
            fillRateFromData(objDescribe.getName(), input.fieldApiName, result);
        } else {
            result.totalCount = input.totalCount;
            result.filledCount = input.filledCount;
            result.fillRate = input.fillRate;
        }

        if (options.includeFieldPermissions) {
            populateFieldPermissions(objDescribe.getName(), input.fieldApiName, result);
        }
        if (options.includeToolingDependencies) {
            populateDependencies(objDescribe.getName(), input.fieldApiName, result);
        }
        return result;
    }

    private static void fillRateFromData(String objectApiName, String fieldApiName, FieldResult result) {
        try {
            String baseQuery = 'SELECT count() cnt FROM ' + objectApiName;
            AggregateResult totalRes = (AggregateResult) Database.query(baseQuery, AccessLevel.USER_MODE);
            Integer total = (Integer) totalRes.get('cnt');
            String filledQuery = 'SELECT count() cnt FROM ' + objectApiName + ' WHERE ' + fieldApiName + ' != null';
            AggregateResult filledRes = (AggregateResult) Database.query(filledQuery, AccessLevel.USER_MODE);
            Integer filled = (Integer) filledRes.get('cnt');
            result.totalCount = total;
            result.filledCount = filled;
            if (total != null && total > 0) {
                result.fillRate = (Decimal) filled / (Decimal) total;
            } else {
                result.fillRate = 0;
            }
        } catch (Exception ex) {
            result.notes.add('Fill rate sampling failed: ' + ex.getMessage());
        }
    }

    private static void populateFieldPermissions(String objectApiName, String fieldApiName, FieldResult result) {
        if (!Schema.sObjectType.FieldPermissions.isAccessible()) {
            result.notes.add('FieldPermissions not accessible');
            return;
        }
        try {
            String fullField = objectApiName + '.' + fieldApiName;
            String soql = 'SELECT Parent.Profile.Name, Parent.Name, PermissionsRead, PermissionsEdit ' +
                'FROM FieldPermissions ' +
                'WHERE SobjectType = \'' + String.escapeSingleQuotes(objectApiName) + '\' ' +
                'AND Field = \'' + String.escapeSingleQuotes(fullField) + '\'';
            List<FieldPermissions> perms = (List<FieldPermissions>) Database.query(soql, AccessLevel.USER_MODE);
            for (FieldPermissions fp : perms) {
                if (fp.Parent != null && fp.Parent.ProfileId != null) {
                    result.profiles.add(fp.Parent.Profile.Name);
                } else if (fp.Parent != null) {
                    result.permissionSets.add(fp.Parent.Name);
                }
            }
        } catch (Exception ex) {
            result.notes.add('FieldPermissions query failed: ' + ex.getMessage());
        }
    }

    private static void populateDependencies(String objectApiName, String fieldApiName, FieldResult result) {
        try {
            String fieldDurableId = fetchFieldDurableId(objectApiName, fieldApiName);
            if (String.isBlank(fieldDurableId)) {
                result.notes.add('DurableId not found for field');
                return;
            }
            String depQuery = 'SELECT MetadataComponentName, MetadataComponentType, RefMetadataComponentName, RefMetadataComponentType ' +
                'FROM MetadataComponentDependency WHERE RefMetadataComponentId = \'' + fieldDurableId + '\'';
            List<Object> depRecords = ToolingApiClient.query(depQuery);
            for (Object record : depRecords) {
                Map<String, Object> row = (Map<String, Object>) record;
                String typeName = (String) row.get('MetadataComponentType');
                String compName = (String) row.get('MetadataComponentName');
                if (!String.isBlank(typeName) || !String.isBlank(compName)) {
                    result.dependencies.add(new DependencyInfo(typeName, compName));
                }
            }
        } catch (Exception ex) {
            result.notes.add('Dependency lookup failed: ' + ex.getMessage());
        }
    }

    private static String fetchFieldDurableId(String objectApiName, String fieldApiName) {
        String soql = 'SELECT DurableId FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = \'' +
            objectApiName + '\' AND QualifiedApiName = \'' + fieldApiName + '\'';
        List<Object> records = ToolingApiClient.query(soql);
        if (records.isEmpty()) {
            return null;
        }
        Map<String, Object> row = (Map<String, Object>) records[0];
        return (String) row.get('DurableId');
    }

    /**
     * @description Build CSV content from results.
     * @param results Results list.
     * @return CSV string.
     */
    public static String toCsv(List<FieldResult> results) {
        List<String> lines = new List<String>();
        lines.add('ObjectApi,FieldApi,Label,DataType,FillRate,TotalCount,FilledCount,Dependencies,Profiles,PermissionSets,Notes');
        for (FieldResult r : results) {
            String deps = joinDependencies(r.dependencies);
            String profiles = String.join(r.profiles, ';');
            String permsets = String.join(r.permissionSets, ';');
            String notes = String.join(r.notes, ';');
            lines.add(csvEscape(r.objectApiName) + ',' +
                csvEscape(r.fieldApiName) + ',' +
                csvEscape(r.label) + ',' +
                csvEscape(r.dataType) + ',' +
                csvEscape(r.fillRate == null ? null : String.valueOf(r.fillRate)) + ',' +
                csvEscape(r.totalCount == null ? null : String.valueOf(r.totalCount)) + ',' +
                csvEscape(r.filledCount == null ? null : String.valueOf(r.filledCount)) + ',' +
                csvEscape(deps) + ',' +
                csvEscape(profiles) + ',' +
                csvEscape(permsets) + ',' +
                csvEscape(notes)
            );
        }
        return String.join(lines, '\n');
    }

    private static String joinDependencies(List<DependencyInfo> deps) {
        List<String> tokens = new List<String>();
        for (DependencyInfo d : deps) {
            tokens.add((d.componentType == null ? '' : d.componentType) + ':' + (d.componentName == null ? '' : d.componentName));
        }
        return String.join(tokens, ';');
    }

    private static String csvEscape(String value) {
        if (value == null) {
            return '';
        }
        String v = value.replace('"', '""');
        if (v.contains(',') || v.contains('\n') || v.contains('"')) {
            v = '"' + v + '"';
        }
        return v;
    }
}
