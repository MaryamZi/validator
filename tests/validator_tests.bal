import ballerina/grpc;
import ballerina/test;

ValidatorClient validatorClient = check new (string `http://localhost:${port}`);

@test:Config
function testSingleInvalidCreditCardNumber() returns error? {
    ValidateStreamingClient validateStreamingClient = check validatorClient->validate();
    
    check validateStreamingClient->sendString("invalid");
    check validateStreamingClient->complete();
    Result receiveResult = check validateStreamingClient->receiveResult();
    test:assertEquals(receiveResult, <Result> {number: "invalid", blacklisted: true});
}

@test:Config
function testSingleValidCreditCardNumber() returns error? {
    ValidateStreamingClient validateStreamingClient = check validatorClient->validate();
    
    check validateStreamingClient->sendString("1111111111111111");
    check validateStreamingClient->complete();
    Result receiveResult = check validateStreamingClient->receiveResult();
    test:assertEquals(receiveResult, <Result> {number: "1111111111111111", blacklisted: false});
}

@test:Config
function testMultipleInvalidCreditCardNumber() returns error? {
    ValidateStreamingClient validateStreamingClient = check validatorClient->validate();

    map<boolean> blacklistedStatus = {
        "invalid": true,
        "10101010": true,
        "1111111122222222": false,
        "1": true
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
}
