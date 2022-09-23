import XCTest
@testable import AutoGraphParser
import Parsing

// TODO: Use Prop Tests.

final class AutoGraphParserTests: XCTestCase {
    func testExample() throws {
        let input = """
          1,Blob,true
          2,Blob Jr.,false
          3,Blob Sr.,true
          """

        struct User {
          let id: Int
          let name: String
          let isAdmin: Bool
        }
        
        let user = Parse {
          User(id: $0, name: String($1), isAdmin: $2)
        } with: {
          Int.parser()
          ","
          Prefix { $0 != "," }
          ","
          Bool.parser()
        }
        
        let users = Many {
          user
        } separator: {
          "\n"
        }
        
        let parsed = try users.parse(input)
        print(parsed)
    }
    
    func testGraphQL() throws {
        // TODO: Test a full Document once ready.
        // TODO: Remember that whitespace (amongst other characters) is ignored. https://spec.graphql.org/October2021/#Ignored
    }
    
    func testNameParsing() throws {
        let input = "Some_Name_1234"
        let name = try Parse {
            Name.parser
        }.parse(input)
        XCTAssertEqual(name.val, "Some_Name_1234")
    }
    
    func testArgumentParsing() throws {
        var input = "arg:true"
        var argument = try Argument<IsConst>.parser.parse(input)
        XCTAssertEqual(argument, Argument<IsConst>(name: Name(val: "arg"), value: .bool(true)))
        
        input = "arg:true"
        argument = try Argument<IsConst>.parser.parse(input)
        XCTAssertEqual(argument, Argument<IsConst>(name: Name(val: "arg"), value: .bool(true)))
        
        input = "arg :1"
        argument = try Argument<IsConst>.parser.parse(input)
        XCTAssertEqual(argument, Argument<IsConst>(name: Name(val: "arg"), value: .int(1)))
        
        input = "arg: 1.0"
        argument = try Argument<IsConst>.parser.parse(input)
        XCTAssertEqual(argument, Argument<IsConst>(name: Name(val: "arg"), value: .float(1.0)))
        
        input = "arg: \"1.0\""
        argument = try Argument<IsConst>.parser.parse(input)
        XCTAssertEqual(argument, Argument<IsConst>(name: Name(val: "arg"), value: .string("1.0")))
        
        input = "arg: \" false\""
        argument = try Argument<IsConst>.parser.parse(input)
        XCTAssertEqual(argument, Argument<IsConst>(name: Name(val: "arg"), value: .string(" false")))
        
        input = "{ bool: \"false\" }"
        let objectValue = try ObjectValue<IsConst>.parser.parse(input)
        XCTAssertEqual(objectValue, .init(fields: [.init(name: Name(val: "bool"), value: .string("false"))]))
        
        
        input = "obj: { bool: \" false\", list :[1, 2, 3], var: $yeet}    "
        let varArgument = try Argument<IsVariable>.parser.parse(input)
        XCTAssertEqual(varArgument, Argument<IsVariable>(
            name: Name(val: "obj"),
            value: .object(.init(fields: [
                .init(name: Name(val: "bool"), value: .string(" false")),
                .init(name: Name(val: "list"), value: .list([.int(1), .int(2), .int(3)])),
                .init(name: Name(val: "var"), value: .variable(Variable(name: Name(val: "yeet")), IsVariable()))
            ]))
        ))
    }
}
