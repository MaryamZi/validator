import ballerina/grpc;
import ballerina/log;

configurable int port = ?;

listener grpc:Listener ep = new (port);

@grpc:ServiceDescriptor {
    descriptor: ROOT_DESCRIPTOR,
    descMap: getDescriptorMap()
}
service "Validator" on ep {
    remote function validate(ValidatorResultCaller caller, stream<string, grpc:Error> clientStream) returns error? {

        record {| string value; |}? next = check clientStream.next();

        while !(next is ()) {
            string number = next.value;
            boolean blacklisted = isBlacklisted(number);

            log:printDebug(string `Validation result for`, num = number, blacklisted = blacklisted);
            
            grpc:Error? sendStatus = caller->sendResult({number, blacklisted});
            if !(sendStatus is ()) {
                log:printError(string `Error sending result for ${number}`, 'error = sendStatus);
            }

            next = check clientStream.next();
        }

        return caller->complete();
    }
}

isolated function isBlacklisted(string number) returns boolean => number.length() != 16;
