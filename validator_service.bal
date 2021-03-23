import ballerina/crypto;
import ballerina/grpc;
import ballerina/log;

configurable int port = ?;
configurable readonly & record {
    string path?; 
    string password?; 
    string certFile?;
    string keyFile?;
    string keyPassword?; } key = ?;

listener grpc:Listener ep = new (port, {
    host: "localhost",
    secureSocket: {
        key: <readonly & crypto:KeyStore|grpc:CertKey> key
    }
});

@grpc:ServiceDescriptor {
    descriptor: ROOT_DESCRIPTOR,
    descMap: getDescriptorMap()
}
service "Validator" on ep {
    isolated remote function validate(ValidatorResultCaller caller, stream<string, grpc:Error> clientStream) returns error? {

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

        check caller->complete();
    }
}

isolated function isBlacklisted(string number) returns boolean => number.length() != 16;
