import ballerina/cache;
import ballerina/sql;
import ballerinax/java.jdbc;

final configurable string dbUrl = ?;
final configurable string dbTable = ?;
final configurable string dbUser = ?;
final configurable string dbPassword = ?;

isolated cache:Cache blacklistCache = new ({defaultMaxAge: 30 * 60, cleanupInterval: 10 * 60});

function init() {
    checkpanic loadDataFromDatabase();
}

isolated jdbc:Client jdbcClient = check new (dbUrl, dbUser, dbPassword);

isolated function loadDataFromDatabase() returns error? {
    string[] & readonly numbers = [];
    lock {
        string[] mutableNumberArray = [];
        sql:ExecutionResult executionResult = check jdbcClient->execute(string `CREATE TABLE IF NOT EXISTS ${dbTable}(number VARCHAR(50))`);
        stream<record{}, error> resultStream = jdbcClient->query(string `SELECT * from ${dbTable}`);
        record { any|error value; }? rec  = check resultStream.next();
        while !(rec is ()) {
            record {} valueRec = <record {}> check rec.value;
            mutableNumberArray.push(<string> valueRec["number"]);
            rec  = check resultStream.next();
        }

        numbers = <readonly & string[]> mutableNumberArray.cloneReadOnly();
    }
    
    lock {
        foreach string number in numbers {
            check blacklistCache.put(number, true);
        }
    }
}

isolated function hasEntryInDatabase(string number) returns boolean {
    lock {
        stream<record {| anydata...; |}, sql:Error> query = jdbcClient->query(`SELECT * from ${dbTable} where number = ${number}`);
        return query.next() is record {| anydata...; |};
    }
}
