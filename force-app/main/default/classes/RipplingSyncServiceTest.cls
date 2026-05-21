/**
 * Test coverage for RipplingSyncService + RipplingSyncScheduler + RipplingTimeEntryBatcher.
 * Uses HttpCalloutMock to simulate Rippling responses for employees, time entries, and time off.
 */
@IsTest(seeAllData=false)
private class RipplingSyncServiceTest {

    private class RipplingMultiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            String url = req.getEndpoint();
            String currentUserEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;

            // V2: /departments/ — must match before /workers/ to avoid substring collision
            if (url.contains('/departments')) {
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'results' => new List<Object>{
                        new Map<String, Object>{'id' => 'dept-land', 'name' => 'Landscape'},
                        new Map<String, Object>{'id' => 'dept-fin',  'name' => 'Finance'}
                    }
                }));
                return res;
            }

            // V2: /users/ — name and phone
            if (url.contains('/users')) {
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'results' => new List<Object>{
                        new Map<String, Object>{
                            'id' => 'user-001',
                            'name' => new Map<String, Object>{'given_name' => 'Alex', 'family_name' => 'Foreman'},
                            'phone_numbers' => new List<Object>{
                                new Map<String, Object>{'type' => 'WORK', 'value' => '555-0101'}
                            }
                        },
                        new Map<String, Object>{
                            'id' => 'user-002',
                            'name' => new Map<String, Object>{'given_name' => 'Sam', 'family_name' => 'Crew'},
                            'phone_numbers' => new List<Object>()
                        },
                        new Map<String, Object>{
                            'id' => 'user-003',
                            'name' => new Map<String, Object>{'given_name' => 'Pat', 'family_name' => 'Accountant'},
                            'phone_numbers' => new List<Object>()
                        },
                        new Map<String, Object>{
                            'id' => 'user-004',
                            'name' => new Map<String, Object>{'given_name' => 'Dan', 'family_name' => 'Corrigan'},
                            'phone_numbers' => new List<Object>()
                        }
                    }
                }));
                return res;
            }

            // V2: /workers/
            if (url.contains('/workers') || url.contains('/employees')) {
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'results' => new List<Object>{
                        new Map<String, Object>{
                            'id'            => 'emp-001',
                            'user_id'       => 'user-001',
                            'department_id' => 'dept-land',
                            'work_email'    => currentUserEmail,
                            'title'         => 'Lead Technician',
                            'status'        => 'ACTIVE',
                            'start_date'    => '2022-01-15',
                            'custom_fields' => new Map<String, Object>{'is_driver' => true}
                        },
                        new Map<String, Object>{
                            'id'            => 'emp-002',
                            'user_id'       => 'user-002',
                            'department_id' => 'dept-land',
                            'work_email'    => 'sam.crew@example.com',
                            'title'         => 'Technician',
                            'status'        => 'ACTIVE',
                            'custom_fields' => new Map<String, Object>{'is_driver' => false}
                        },
                        new Map<String, Object>{
                            'id'            => 'emp-003',
                            'user_id'       => 'user-003',
                            'department_id' => 'dept-fin',
                            'title'         => 'Accountant',
                            'status'        => 'ACTIVE'
                        },
                        new Map<String, Object>{
                            'id'            => 'emp-004',
                            'user_id'       => 'user-004',
                            'department_id' => 'dept-land',
                            'work_email'    => 'dan.corrigan@example.com',
                            'title'         => 'Scheduling Manager',
                            'status'        => 'ACTIVE'
                        }
                    }
                }));
                return res;
            }
            // V2: worker_id field (not employee_id) in time entries
            if (url.contains('/time-entries') || url.contains('/time_entries')) {
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'results' => new List<Object>{
                        new Map<String, Object>{
                            'id'              => 'te-001',
                            'worker_id'       => 'emp-001',
                            'clock_in'        => DateTime.now().addHours(-2).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
                            'clock_out'       => null,
                            'department_name' => 'Landscape',
                            'job_code'        => 'JOB-1'
                        }
                    }
                }));
                return res;
            }
            // V2: worker_id field in time off
            if (url.contains('/time-off') || url.contains('/time_off_requests')) {
                Date today = Date.today();
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'results' => new List<Object>{
                        new Map<String, Object>{
                            'id'          => 'to-001',
                            'worker_id'   => 'emp-002',
                            'start_date'  => String.valueOf(today),
                            'end_date'    => String.valueOf(today.addDays(2)),
                            'policy_type' => 'vacation',
                            'status'      => 'approved',
                            'hours'       => 24.0
                        }
                    }
                }));
                return res;
            }
            res.setStatusCode(404);
            res.setBody('{}');
            return res;
        }
    }

    @IsTest
    static void syncEmployees_filtersToTargetDepartments() {
        Test.setMock(HttpCalloutMock.class, new RipplingMultiMock());
        Test.startTest();
        RipplingSyncService.syncEmployees();
        Test.stopTest();

        List<Employee__c> emps = [SELECT Id, Rippling_Id__c, Department__c, Is_Driver__c, Role__c, User__c FROM Employee__c];
        // emp-003 (Finance) filtered out; emp-001, emp-002, emp-004 (Landscape) included
        System.assertEquals(3, emps.size(), 'Only in-scope departments should be synced');
        Map<String, Employee__c> byRipId = new Map<String, Employee__c>();
        for (Employee__c e : emps) byRipId.put(e.Rippling_Id__c, e);

        System.assert(byRipId.containsKey('emp-001'));
        System.assert(byRipId.containsKey('emp-002'));
        System.assert(byRipId.containsKey('emp-004'));
        System.assert(!byRipId.containsKey('emp-003'));

        // Role derivation: emp-001 "Lead Technician" → Foreman, emp-002 "Technician" → Tech,
        // emp-004 Dan Corrigan name override → Schedule Manager/Dispatch Supervisor
        System.assertEquals('Foreman',                          byRipId.get('emp-001').Role__c);
        System.assertEquals('Tech',                             byRipId.get('emp-002').Role__c);
        System.assertEquals('Schedule Manager/Dispatch Supervisor', byRipId.get('emp-004').Role__c);
        System.assertNotEquals(null, byRipId.get('emp-001').User__c, 'Work email should backfill User__c');
    }

    @IsTest
    static void backfillEmployeeUserAndCrewLinks_mapsCrew() {
        User currentUser = [SELECT Id, Email FROM User WHERE Id = :UserInfo.getUserId()];

        Employee__c employee = new Employee__c(
            Name = 'Mapped Employee',
            Rippling_Id__c = 'emp-map',
            First_Name__c = 'Mapped',
            Last_Name__c = 'Employee',
            Work_Email__c = currentUser.Email,
            Status__c = 'Active'
        );
        insert employee;

        Test.startTest();
        RipplingSyncService.backfillEmployeeUserAndCrewLinks();
        Test.stopTest();

        Employee__c updated = [SELECT User__c, Crew__c FROM Employee__c WHERE Id = :employee.Id];
        System.assertNotEquals(null, updated.User__c);

        Crew__c crew = new Crew__c(
            Name = 'Rippling Crew',
            Active__c = true,
            Foreman__c = updated.User__c
        );
        insert crew;

        update new Employee__c(Id = employee.Id, Crew__c = null);

        RipplingSyncService.backfillEmployeeUserAndCrewLinks();

        updated = [SELECT User__c, Crew__c FROM Employee__c WHERE Id = :employee.Id];
        System.assertEquals(crew.Id, updated.Crew__c);
    }

    @IsTest
    static void mapRole_titlePatterns() {
        System.assertEquals('Foreman',          RipplingSyncService.mapRole('', 'Nobody',   'Lead Technician'));
        System.assertEquals('Foreman',          RipplingSyncService.mapRole('', 'Nobody',   'Foreman'));
        System.assertEquals('Tech',             RipplingSyncService.mapRole('', 'Nobody',   'Technician'));
        System.assertEquals('Tech',             RipplingSyncService.mapRole('', 'Nobody',   'Crew Member'));
        System.assertEquals('Tech',             RipplingSyncService.mapRole('', 'Nobody',   'Landscape Tech'));
        System.assertEquals('Schedule Manager/Dispatch Supervisor', RipplingSyncService.mapRole('', 'Nobody', 'Scheduling Manager'));
        System.assertEquals('Schedule Manager/Dispatch Supervisor', RipplingSyncService.mapRole('', 'Nobody', 'Manager, Scheduling'));
        System.assertEquals('Schedule Manager/Dispatch Supervisor', RipplingSyncService.mapRole('', 'Nobody', 'Dispatch Supervisor'));
        System.assertEquals('CSM',              RipplingSyncService.mapRole('', 'Nobody',   'Customer Success Manager'));
        System.assertEquals('Designer',         RipplingSyncService.mapRole('', 'Nobody',   'Landscape Designer'));
        System.assertEquals(null,               RipplingSyncService.mapRole('', 'Nobody',   null));
    }

    @IsTest
    static void mapRole_nameOverrides() {
        // Dan Corrigan → Schedule Manager/Dispatch Supervisor regardless of title
        System.assertEquals('Schedule Manager/Dispatch Supervisor', RipplingSyncService.mapRole('Dan', 'Corrigan', 'Accountant'));
        System.assertEquals('Schedule Manager/Dispatch Supervisor', RipplingSyncService.mapRole('Dan', 'Corrigan', null));
        // Erica (any last name other than Corrigan) → CSM
        System.assertEquals('CSM', RipplingSyncService.mapRole('Erica', 'Smith', 'Office Admin'));
        System.assertEquals('CSM', RipplingSyncService.mapRole('Erica', 'Jones', null));
    }

    @IsTest
    static void syncTimeEntries_setsClockedInFlag() {
        Employee__c e = new Employee__c(
            Name = 'Alex Foreman',
            Rippling_Id__c = 'emp-001',
            First_Name__c = 'Alex',
            Last_Name__c = 'Foreman',
            Department__c = 'Landscape',
            Status__c = 'Active',
            Is_Driver__c = true
        );
        insert e;

        Test.setMock(HttpCalloutMock.class, new RipplingMultiMock());
        Test.startTest();
        RipplingSyncService.syncTimeEntries(null);
        Test.stopTest();

        List<Rippling_Time_Entry__c> entries = [SELECT Id, Clock_Out__c FROM Rippling_Time_Entry__c WHERE Employee__c = :e.Id];
        System.assertEquals(1, entries.size());
        System.assertEquals(null, entries[0].Clock_Out__c);

        Employee__c reloaded = [SELECT Id, Currently_Clocked_In__c, Current_Shift_Start__c FROM Employee__c WHERE Id = :e.Id];
        System.assertEquals(true, reloaded.Currently_Clocked_In__c);
        System.assertNotEquals(null, reloaded.Current_Shift_Start__c);
    }

    @IsTest
    static void syncTimeOff_setsOnPtoTodayFlag() {
        Employee__c e = new Employee__c(
            Name = 'Sam Crew',
            Rippling_Id__c = 'emp-002',
            First_Name__c = 'Sam',
            Last_Name__c = 'Crew',
            Department__c = 'Landscape',
            Status__c = 'Active',
            Is_Driver__c = false
        );
        insert e;

        Test.setMock(HttpCalloutMock.class, new RipplingMultiMock());
        Test.startTest();
        RipplingSyncService.syncTimeOff();
        Test.stopTest();

        List<Rippling_Time_Off__c> tos = [SELECT Id, Status__c FROM Rippling_Time_Off__c WHERE Employee__c = :e.Id];
        System.assertEquals(1, tos.size());
        System.assertEquals('Approved', tos[0].Status__c);

        Employee__c reloaded = [SELECT Id, On_PTO_Today__c FROM Employee__c WHERE Id = :e.Id];
        System.assertEquals(true, reloaded.On_PTO_Today__c);
    }

    @IsTest
    static void getAvailableForemen_respectsDriverAndPto() {
        Employee__c driver = new Employee__c(
            Name = 'Drive Able',
            Rippling_Id__c = 'emp-d',
            First_Name__c = 'Drive',
            Last_Name__c = 'Able',
            Department__c = 'Landscape',
            Status__c = 'Active',
            Is_Driver__c = true,
            On_PTO_Today__c = false
        );
        Employee__c crew = new Employee__c(
            Name = 'Crew Member',
            Rippling_Id__c = 'emp-c',
            First_Name__c = 'Crew',
            Last_Name__c = 'Member',
            Department__c = 'Landscape',
            Status__c = 'Active',
            Is_Driver__c = false,
            On_PTO_Today__c = false
        );
        Employee__c ptoDriver = new Employee__c(
            Name = 'Pto Driver',
            Rippling_Id__c = 'emp-p',
            First_Name__c = 'Pto',
            Last_Name__c = 'Driver',
            Department__c = 'Landscape',
            Status__c = 'Active',
            Is_Driver__c = true,
            On_PTO_Today__c = true
        );
        insert new List<Employee__c>{driver, crew, ptoDriver};

        List<Employee__c> withDriver = RipplingSyncService.getAvailableForemen(Date.today(), true);
        System.assertEquals(1, withDriver.size());
        System.assertEquals(driver.Id, withDriver[0].Id);

        List<Employee__c> anyForeman = RipplingSyncService.getAvailableForemen(Date.today(), false);
        System.assertEquals(2, anyForeman.size());
    }

    @IsTest
    static void scheduler_andBatcher_runWithoutErrors() {
        Test.setMock(HttpCalloutMock.class, new RipplingMultiMock());
        Test.startTest();
        Database.executeBatch(new RipplingTimeEntryBatcher(), 1);
        Test.stopTest();

        // Scheduler exercise runs outside Test.start/stopTest so @future calls inside
        // the execute methods are allowed (Schedulable is not a future context anyway).
        RipplingSyncScheduler sched = new RipplingSyncScheduler('EMPLOYEE');
        sched.execute(null);

        RipplingSyncScheduler sched2 = new RipplingSyncScheduler('TIME_OFF');
        sched2.execute(null);

        RipplingSyncScheduler sched3 = new RipplingSyncScheduler('PTO_ROLLUP');
        sched3.execute(null);

        RipplingSyncScheduler sched4 = new RipplingSyncScheduler();
        System.assertEquals('EMPLOYEE', sched4.jobType);
    }

    @IsTest
    static void scheduler_scheduleDaily_registersJobs() {
        Test.setMock(HttpCalloutMock.class, new RipplingMultiMock());
        Test.startTest();
        RipplingSyncScheduler.scheduleDaily();
        Test.stopTest();
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name IN ('Rippling Employee Sync', 'Rippling Time Off Sync', 'Rippling PTO Rollup')
        ];
        System.assertEquals(3, jobs.size());
        // Second call should abort and re-register without error.
        RipplingSyncScheduler.scheduleDaily();
    }
}