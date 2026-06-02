/**
 * BuilderPoTimingRuleSeeder
 * Seeds (upserts) Builder_PO_Timing_Rule__c configuration records.
 * Run from Anonymous Apex after deploying phase-wo-life-path-production.xml:
 *   BuilderPoTimingRuleSeeder.seed();
 */
public with sharing class BuilderPoTimingRuleSeeder {

    public static void seed() {
        List<Builder_PO_Timing_Rule__c> rules = new List<Builder_PO_Timing_Rule__c>{

            new Builder_PO_Timing_Rule__c(
                Name                    = 'DR Horton Charlotte',
                Parent_Builder_Name__c  = 'DR Horton',
                Division_Builder_Name__c = 'DR Horton Charlotte',
                Division_Code__c        = 'CLT',
                Division_Name__c        = 'Charlotte',
                Min_Days_Before_Start__c = 120,
                Max_Days_Before_Start__c = 180,
                Business_Days__c        = false,
                Active__c               = true
            ),
            new Builder_PO_Timing_Rule__c(
                Name                    = 'DR Horton Asheville',
                Parent_Builder_Name__c  = 'DR Horton',
                Division_Builder_Name__c = 'DR Horton Asheville',
                Division_Code__c        = 'ASH',
                Division_Name__c        = 'Asheville',
                Min_Days_Before_Start__c = 150,
                Max_Days_Before_Start__c = 180,
                Business_Days__c        = false,
                Active__c               = true
            ),
            new Builder_PO_Timing_Rule__c(
                Name                    = 'Lennar Charlotte',
                Parent_Builder_Name__c  = 'Lennar',
                Division_Builder_Name__c = 'Lennar Charlotte',
                Division_Code__c        = 'CLT',
                Division_Name__c        = 'Charlotte',
                Min_Days_Before_Start__c = 10,
                Max_Days_Before_Start__c = 10,
                Business_Days__c        = true,
                Active__c               = true
            ),
            new Builder_PO_Timing_Rule__c(
                Name                    = 'Lennar Triad',
                Parent_Builder_Name__c  = 'Lennar',
                Division_Builder_Name__c = 'Lennar Triad',
                Division_Code__c        = 'TRIA',
                Division_Name__c        = 'Triad',
                Min_Days_Before_Start__c = 10,
                Max_Days_Before_Start__c = 10,
                Business_Days__c        = true,
                Active__c               = true
            ),
            new Builder_PO_Timing_Rule__c(
                Name                    = 'Lennar Greenville',
                Parent_Builder_Name__c  = 'Lennar',
                Division_Builder_Name__c = 'Lennar Greenville',
                Division_Code__c        = 'GRVL',
                Division_Name__c        = 'Greenville',
                Min_Days_Before_Start__c = 10,
                Max_Days_Before_Start__c = 10,
                Business_Days__c        = true,
                Active__c               = true
            ),
            new Builder_PO_Timing_Rule__c(
                Name                    = 'Lennar Columbia',
                Parent_Builder_Name__c  = 'Lennar',
                Division_Builder_Name__c = 'Lennar Columbia',
                Division_Code__c        = 'COLM',
                Division_Name__c        = 'Columbia',
                Min_Days_Before_Start__c = 10,
                Max_Days_Before_Start__c = 10,
                Business_Days__c        = true,
                Active__c               = true
            ),
            new Builder_PO_Timing_Rule__c(
                Name                    = 'Great Southern Homes',
                Parent_Builder_Name__c  = 'Great Southern Homes',
                Division_Builder_Name__c = 'Great Southern Homes',
                Min_Days_Before_Start__c = 60,
                Max_Days_Before_Start__c = 60,
                Business_Days__c        = false,
                Active__c               = true
            ),
            new Builder_PO_Timing_Rule__c(
                Name                    = 'Davidson Homes',
                Parent_Builder_Name__c  = 'Davidson Homes',
                Division_Builder_Name__c = 'Davidson Homes',
                Min_Days_Before_Start__c = 10,
                Max_Days_Before_Start__c = 15,
                Business_Days__c        = true,
                Active__c               = true
            ),
            new Builder_PO_Timing_Rule__c(
                Name                    = 'Yellowstone',
                Parent_Builder_Name__c  = 'Yellowstone',
                Division_Builder_Name__c = 'Yellowstone',
                Min_Days_Before_Start__c = 5,
                Max_Days_Before_Start__c = 5,
                Business_Days__c        = true,
                Active__c               = true
            ),
            new Builder_PO_Timing_Rule__c(
                Name                    = 'Ryan Homes',
                Parent_Builder_Name__c  = 'Ryan Homes',
                Division_Builder_Name__c = 'Ryan Homes',
                Min_Days_Before_Start__c = 90,
                Max_Days_Before_Start__c = 120,
                Business_Days__c        = false,
                Active__c               = true
            ),
            new Builder_PO_Timing_Rule__c(
                Name                    = 'Meritage',
                Parent_Builder_Name__c  = 'Meritage',
                Division_Builder_Name__c = 'Meritage',
                Min_Days_Before_Start__c = 30,
                Max_Days_Before_Start__c = 60,
                Business_Days__c        = false,
                Active__c               = true
            ),
            new Builder_PO_Timing_Rule__c(
                Name                    = 'Toll Brothers',
                Parent_Builder_Name__c  = 'Toll Brothers',
                Division_Builder_Name__c = 'Toll Brothers',
                Min_Days_Before_Start__c = 10,
                Max_Days_Before_Start__c = 10,
                Business_Days__c        = true,
                Active__c               = true
            ),
            new Builder_PO_Timing_Rule__c(
                Name                    = 'Pinnacle',
                Parent_Builder_Name__c  = 'Pinnacle',
                Division_Builder_Name__c = 'Pinnacle',
                Min_Days_Before_Start__c = 5,
                Max_Days_Before_Start__c = 5,
                Business_Days__c        = true,
                Active__c               = true
            )
        };

        // Upsert on Name (unique rule name per builder/division)
        upsert rules Name;

        System.debug('BuilderPoTimingRuleSeeder: seeded ' + rules.size() + ' timing rules.');
    }
}