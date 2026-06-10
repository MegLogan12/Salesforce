@IsTest
private class SchedulingConsoleRefreshQueueTest {

    private class CombinedRefreshMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();
            String currentUserEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;

            if (endpoint.contains('/departments')) {
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'results' => new List<Object>{
                        new Map<String, Object>{'id' => 'dept-land', 'name' => 'Landscape'}
                    }
                }));
                return res;
            }

            if (endpoint.contains('/users')) {
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
                        }
                    }
                }));
                return res;
            }

            if (endpoint.contains('/workers') || endpoint.contains('/employees')) {
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
                        }
                    }
                }));
                return res;
            }

            if (endpoint.contains('/time-off') || endpoint.contains('/time_off_requests')) {
                Date today = Date.today();
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'results' => new List<Object>{
                        new Map<String, Object>{
                            'id'          => 'to-001',
                            'worker_id'   => 'emp-002',
                            'start_date'  => String.valueOf(today),
                            'end_date'    => String.valueOf(today.addDays(1)),
                            'policy_type' => 'vacation',
                            'status'      => 'approved',
                            'hours'       => 16.0
                        }
                    }
                }));
                return res;
            }

            if (endpoint.contains('userauth/login')) {
                res.setBody('{"data":{"token":"mock-session-token"}}');
                return res;
            }

            if (endpoint.contains('vehicle/location')) {
                res.setBody('{"data":[{"id":"VV001","latitude":33.66,"longitude":-111.92,"fix_time_gmt":"2024-06-01T14:00:00Z","inst_speed":25,"heading":90,"ignition":"on","address":"456 Elm St","first_name":"Jane","last_name":"Smith"}]}');
                return res;
            }

            if (endpoint.contains('/driver')) {
                res.setBody('{"data":[{"id":"DR001","first_name":"Jane","last_name":"Smith","vehicle_id":"VV001","active":true}]}');
                return res;
            }

            if (endpoint.contains('/vehicle')) {
                res.setBody('{"data":[{"id":"VV001","label":"Truck 1","make":"Ford","model":"F-150","year":2021,"vin":"1FTFW1E5XMFC00001","license_plate":"ABC-123","odometer":15000}]}');
                return res;
            }

            res.setBody('{}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        upsert new GPS_Insight_Config__c(
            Username__c = 'testuser',
            App_Token__c = 'testapp',
            Session_Token__c = 'valid-cached-token',
            Token_Expiry__c = DateTime.now().addDays(3)
        );
    }

    @IsTest
    static void refreshSchedulingConsole_completesWithoutException() {
        // refreshSchedulingConsole is a cachebuster no-op — it logs the event and returns.
        Test.startTest();
        try {
            SchedulingConsoleController.refreshSchedulingConsole();
            System.assert(true, 'Refresh should complete without throwing');
        } catch (Exception e) {
            System.assert(false, 'Refresh should not throw: ' + e.getMessage());
        }
        Test.stopTest();
    }
}