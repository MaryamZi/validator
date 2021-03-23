import ballerina/crypto;
import ballerina/grpc;
import ballerina/sql;
import ballerina/test;

configurable readonly & record {| string path; string password; |} cert = ?;

ValidatorClient validatorClient = check new (string `https://localhost:${port}`, {
    secureSocket: {
        cert: <crypto:TrustStore> cert // Workaround for https://github.com/ballerina-platform/ballerina-lang/issues/29486
    }
});

@test:BeforeGroups {
    value: ["db-backed"]
}
function populateDatabase() returns error? {
    lock {
        sql:ExecutionResult result = check jdbcClient->execute(string `DROP TABLE IF EXISTS ${dbTable}`);
        result = check jdbcClient->execute(string `CREATE TABLE IF NOT EXISTS ${dbTable}(number VARCHAR(50))`);
        result = check jdbcClient->execute(string `INSERT INTO ${dbTable} (number) VALUES ('invalid')`);
        result = check jdbcClient->execute(string `INSERT INTO ${dbTable} (number) VALUES ('10101010')`);
        result = check jdbcClient->execute(string `INSERT INTO ${dbTable} (number) VALUES ('1')`);
        result = check jdbcClient->execute(string `INSERT INTO ${dbTable} (number) VALUES ('2222222222222222')`);
    }
}

@test:AfterGroups {
    value: ["db-backed"]
}
function clearDatabase() returns error? {
    lock {
        check blacklistCache.invalidateAll();
    }

    // lock {
    //     _ = check jdbcClient->execute(string `DROP TABLE ${dbTable}`);
    // }
}

@test:Config {
    groups: ["db-backed"]
}
function testSingleInvalidCreditCardNumberForDbBackedCache() returns error? {
    ValidateStreamingClient validateStreamingClient = check validatorClient->validate();
    
    check validateStreamingClient->sendString("invalid");
    check validateStreamingClient->complete();
    Result receiveResult = check validateStreamingClient->receiveResult();
    test:assertEquals(receiveResult, <Result> {number: "invalid", blacklisted: true});
}

@test:Config {
    groups: ["db-backed"]
}
function testSingleValidCreditCardNumberForDbBackedCache() returns error? {
    ValidateStreamingClient validateStreamingClient = check validatorClient->validate();
    
    check validateStreamingClient->sendString("1111111111111111");
    check validateStreamingClient->complete();
    Result receiveResult = check validateStreamingClient->receiveResult();
    test:assertEquals(receiveResult, <Result> {number: "1111111111111111", blacklisted: false});
}

@test:Config {
    groups: ["db-backed"]
}
function testMultipleInvalidCreditCardNumberForDbBackedCache() returns error? {
    ValidateStreamingClient validateStreamingClient = check validatorClient->validate();

    map<boolean> blacklistedStatus = {
        "invalid": true,
        "10101010": true,
        "1111111122222222": false,
        "1": true,
        "2222222222222222": true
    };

    foreach var num in blacklistedStatus.keys() {
        check validateStreamingClient->sendString(num);
    }
    check validateStreamingClient->complete();

    Result|grpc:Error receiveResult = validateStreamingClient->receiveResult();

    int count = 0; // Workaround to skip extra empty result.

    while !(receiveResult is grpc:EOS) && count < 4 {
        Result result = checkpanic receiveResult;
        string number = result.number;
        test:assertEquals(receiveResult, <Result> {number, blacklisted: blacklistedStatus.get(number)});
        receiveResult = validateStreamingClient->receiveResult();
        count += 1;
    }

    test:assertEquals(count, 4);
}
