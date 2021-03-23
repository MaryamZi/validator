import ballerina/cache;
import ballerina/crypto;
import ballerina/grpc;
import ballerina/log;

final configurable int port = ?;

final configurable readonly & record {
    string path?; 
    string password?; 
    string certFile?;
    string keyFile?;
    string keyPassword?; } key = ?;

listener grpc:Listener ep = new (port, {
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

isolated function isBlacklisted(string number) returns boolean {
    boolean|cache:Error result;
    lock {
        result = <boolean|cache:Error> blacklistCache.get(number);
    }

    if result is boolean {
        return true;
    }
    
    boolean hasEntry = hasEntryInDatabase(number);
    if hasEntry {
        lock {
            checkpanic blacklistCache.put(number, true);
        }
    }
    return hasEntry;
}
