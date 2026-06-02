@IsTest
private class IntegrationSecretsTest {

    @IsTest
    static void getMissingReturnsEmpty() {
        IntegrationSecrets.Secret s = IntegrationSecrets.get('Does_Not_Exist');
        System.assertEquals(null, s.token);
    }

    @IsTest
    static void getBlankReturnsEmpty() {
        IntegrationSecrets.Secret s = IntegrationSecrets.get('');
        System.assertEquals(null, s.token);
    }

    @IsTest
    static void authHeaderMissingReturnsNull() {
        System.assertEquals(null, IntegrationSecrets.authHeader('Does_Not_Exist'));
    }

    @IsTest
    static void applyAuthMissingIsNoop() {
        HttpRequest req = new HttpRequest();
        IntegrationSecrets.applyAuth(req, 'Does_Not_Exist');
        System.assertEquals(null, req.getHeader('Authorization'));
    }

    @IsTest
    static void authHeaderWithFormatProducesPrefixedValue() {
        IntegrationSecrets.Secret s = new IntegrationSecrets.Secret();
        s.token = 'abc123';
        s.headerFormat = 'Bearer';
        IntegrationSecrets.testOverrides.put('UnitTest_Bearer', s);
        System.assertEquals('Bearer abc123', IntegrationSecrets.authHeader('UnitTest_Bearer'));
    }

    @IsTest
    static void authHeaderTokenOnlyReturnsRaw() {
        IntegrationSecrets.Secret s = new IntegrationSecrets.Secret();
        s.token = 'rawtoken';
        IntegrationSecrets.testOverrides.put('UnitTest_Raw', s);
        System.assertEquals('rawtoken', IntegrationSecrets.authHeader('UnitTest_Raw'));
    }

    @IsTest
    static void applyAuthSetsHeader() {
        IntegrationSecrets.Secret s = new IntegrationSecrets.Secret();
        s.token = 'xyz';
        s.headerFormat = 'Bearer';
        IntegrationSecrets.testOverrides.put('UnitTest_Apply', s);
        HttpRequest req = new HttpRequest();
        IntegrationSecrets.applyAuth(req, 'UnitTest_Apply');
        System.assertEquals('Bearer xyz', req.getHeader('Authorization'));
    }
}