import ballerina/grpc;

public type Result record {|
    string number = "";
    boolean blacklisted = false;
    
|};

public client class ValidatorResultCaller {
    private grpc:Caller caller;

    public isolated function init(grpc:Caller caller) {
        self.caller = caller;
    }

    public isolated function getId() returns int {
        return self.caller.getId();
    }
    
    isolated remote function sendResult(Result response) returns grpc:Error? {
        return self.caller->send(response);
    }

    isolated remote function sendContextResult(ContextResult response) returns grpc:Error? {
        return self.caller->send(response);
    }
    
    isolated remote function sendError(grpc:Error response) returns grpc:Error? {
        return self.caller->sendError(response);
    }

    isolated remote function complete() returns grpc:Error? {
        return self.caller->complete();
    }
}


public client class ValidatorClient {

    *grpc:AbstractClientEndpoint;

    private grpc:Client grpcClient;

    public isolated function init(string url, *grpc:ClientConfiguration config) returns grpc:Error? {
        self.grpcClient = check new(url, config);
        check self.grpcClient.initStub(self, ROOT_DESCRIPTOR, getDescriptorMap());
    }

    isolated remote function validate() returns (ValidateStreamingClient|grpc:Error) {
        grpc:StreamingClient sClient = check self.grpcClient->executeBidirectionalStreaming("Validator/validate");
        return new ValidateStreamingClient(sClient);
    }
}


public client class ValidateStreamingClient {
    private grpc:StreamingClient sClient;

    isolated function init(grpc:StreamingClient sClient) {
        self.sClient = sClient;
    }

    isolated remote function sendString(string message) returns grpc:Error? {
        
        return self.sClient->send(message);
    }

    isolated remote function sendContextString(ContextString message) returns grpc:Error? {
        return self.sClient->send(message);
    }

    isolated remote function receiveResult() returns Result|grpc:Error {
        [anydata, map<string|string[]>] [payload, headers] = check self.sClient->receive();
        return <Result>payload;
    }

    isolated remote function receiveContextResult() returns ContextResult|grpc:Error {
        [anydata, map<string|string[]>] [payload, headers] = check self.sClient->receive();
        
        return {content: <Result>payload, headers: headers};
        
    }

    isolated remote function sendError(grpc:Error response) returns grpc:Error? {
        return self.sClient->sendError(response);
    }

    isolated remote function complete() returns grpc:Error? {
        return self.sClient->complete();
    }
}


public type ContextStringStream record {|
    stream<string> content;
    map<string|string[]> headers;
|};
public type ContextString record {|
    string content;
    map<string|string[]> headers;
|};


public type ContextResultStream record {|
    stream<Result> content;
    map<string|string[]> headers;
|};
public type ContextResult record {|
    Result content;
    map<string|string[]> headers;
|};

const string ROOT_DESCRIPTOR = "0A0A746573742E70726F746F1A1E676F6F676C652F70726F746F6275662F77726170706572732E70726F746F22420A06526573756C7412160A066E756D62657218012001280952066E756D62657212200A0B626C61636B6C6973746564180220012808520B626C61636B6C697374656432420A0956616C696461746F7212350A0876616C6964617465121C2E676F6F676C652E70726F746F6275662E537472696E6756616C75651A072E526573756C7428013001620670726F746F33";
isolated function getDescriptorMap() returns map<string> {
    return {
        "test.proto":"0A0A746573742E70726F746F1A1E676F6F676C652F70726F746F6275662F77726170706572732E70726F746F22420A06526573756C7412160A066E756D62657218012001280952066E756D62657212200A0B626C61636B6C6973746564180220012808520B626C61636B6C697374656432420A0956616C696461746F7212350A0876616C6964617465121C2E676F6F676C652E70726F746F6275662E537472696E6756616C75651A072E526573756C7428013001620670726F746F33",
        "google/protobuf/wrappers.proto":"0A1E676F6F676C652F70726F746F6275662F77726170706572732E70726F746F120F676F6F676C652E70726F746F62756622230A0B446F75626C6556616C756512140A0576616C7565180120012801520576616C756522220A0A466C6F617456616C756512140A0576616C7565180120012802520576616C756522220A0A496E74363456616C756512140A0576616C7565180120012803520576616C756522230A0B55496E74363456616C756512140A0576616C7565180120012804520576616C756522220A0A496E74333256616C756512140A0576616C7565180120012805520576616C756522230A0B55496E74333256616C756512140A0576616C756518012001280D520576616C756522210A09426F6F6C56616C756512140A0576616C7565180120012808520576616C756522230A0B537472696E6756616C756512140A0576616C7565180120012809520576616C756522220A0A427974657356616C756512140A0576616C756518012001280C520576616C756542570A13636F6D2E676F6F676C652E70726F746F627566420D577261707065727350726F746F50015A057479706573F80101A20203475042AA021E476F6F676C652E50726F746F6275662E57656C6C4B6E6F776E5479706573620670726F746F33"
        
    };
}
