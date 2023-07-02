import XCTest
@testable import AutoGraphParser
import Parsing

// TODO: Once we support converting schemas to JSON ASTs within this library, use this
// test which appears to cover everything:
// https://github.com/GraphQLSwift/GraphQL/blob/main/Tests/GraphQLTests/LanguageTests/schema-kitchen-sink.graphql
// TODO: Possibly add tests with github schema too so we get more variety.

final class IntrospectionSchemaParsingTests: XCTestCase {
    class SchemaLoader {
        private(set) var swapiSchema: __Schema!
        private(set) var otherSWAPISchema: __Schema!  // This one has Union types while the original doesn't.
        private(set) var baseTypesSchema: __Schema!  // This one tests Interfaces with no possible types and `isRepeatable` where the others do not.
        
        func load() throws {
            guard
                self.swapiSchema == nil,
                self.otherSWAPISchema == nil,
                self.baseTypesSchema == nil
            else { return }
            
            let components = URL(fileURLWithPath: #file).pathComponents
            guard let sourcePath = components.filter({ $0 != "/" }).split(separator: "Tests").first?.joined(separator: "/") else {
                XCTFail("Unable to find root directory of project. Make sure your tests are in a folder named `Tests` in the root directory")
                return
            }

            let filePath = "/\(sourcePath)"
            let schemaPath = "\(filePath)/Tests/AutoGraphParserTests/star_wars_schema.json"
            self.swapiSchema = try __Schema.loadFrom(jsonSchemaPath: schemaPath)
            
            let otherSchemaPath = "\(filePath)/Tests/AutoGraphParserTests/star_wars_other_schema.json"
            self.otherSWAPISchema = try __Schema.loadFrom(jsonSchemaPath: otherSchemaPath)
            
            let baseTypesSchemaPath = "\(filePath)/Tests/AutoGraphParserTests/base_types_2021_schema.json"
            self.baseTypesSchema = try __Schema.loadFrom(jsonSchemaPath: baseTypesSchemaPath)
        }
    }
    
    static let schemaLoader = SchemaLoader()
    
    var swapiSchema: __Schema! {
        IntrospectionSchemaParsingTests.schemaLoader.swapiSchema!
    }
    
    var otherSWAPISchema: __Schema! {
        IntrospectionSchemaParsingTests.schemaLoader.otherSWAPISchema!
    }
    
    var baseTypesSchema: __Schema! {
        IntrospectionSchemaParsingTests.schemaLoader.baseTypesSchema!
    }
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        try IntrospectionSchemaParsingTests.schemaLoader.load()
    }
    
    func testParseJSONStarWarsSchema() throws {
        XCTAssertEqual(swapiSchema.queryType.name, "Query")
        XCTAssertEqual(swapiSchema.mutationType?.name, "Mutation")
        XCTAssertEqual(swapiSchema.subscriptionType?.name, "Subscription")
        
        XCTAssertEqual(self.swapiSchema.types.filter { $0.kind == .enum }.count, 17)
        XCTAssertEqual(self.swapiSchema.types.filter { $0.kind == .object }.count, 50)
        XCTAssertEqual(self.swapiSchema.types.filter { $0.kind == .inputObject }.count, 54)
        XCTAssertEqual(self.swapiSchema.types.filter { $0.kind == .interface }.count, 1)
        XCTAssertEqual(self.swapiSchema.types.filter { $0.kind == .scalar }.count, 6)
        XCTAssertEqual(self.swapiSchema.types.filter { $0.kind == .list }.count, 0)
        XCTAssertEqual(self.swapiSchema.types.filter { $0.kind == .nonNull }.count, 0)
        XCTAssertEqual(self.swapiSchema.types.filter { $0.kind == .union }.count, 0)
        
        XCTAssertEqual(
            swapiSchema.types[0],
            __Type(kind: __TypeKind.object,
                   name: "AddToFilmPlanetsPayload",
                   description: nil,
                   fields: [
                       __Field(name: "filmsFilm",
                               description: nil,
                               args: [],
                               type: OfType.object(OfType.__TypeReference(kind: .object, name: "Film", description: nil)),
                               isDeprecated: false,
                               deprecationReason: nil),
                       __Field(name: "planetsPlanet",
                               description: nil,
                               args: [],
                               type: OfType.object(OfType.__TypeReference(kind: .object, name: "Planet", description: nil)),
                               isDeprecated: false,
                               deprecationReason: nil),
                   ],
                   interfaces: [],
                   possibleTypes: nil,
                   enumValues: nil,
                   inputFields: nil,
                   ofType: nil)
        )
        XCTAssertEqual(
            swapiSchema.types[10],
            __Type(kind: __TypeKind.inputObject,
                   name: "AssetSubscriptionFilter",
                   description: nil,
                   fields: nil,
                   interfaces: nil,
                   possibleTypes: nil,
                   enumValues: nil,
                   inputFields: [
                       __InputValue(
                           name: "AND",
                           description: "Logical AND on all given filters.",
                           type: OfType.list(
                               OfType.__TypeReference(kind: .list),
                               ofType: OfType.nonNull(
                                   OfType.__TypeReference(kind: .nonNull),
                                   ofType: OfType.inputObject(
                                       OfType.__TypeReference(kind: .inputObject,
                                                              name: "AssetSubscriptionFilter", description: nil))
                               )
                           ),
                           defaultValue: nil
                       ),
                       __InputValue(
                           name: "OR",
                           description: "Logical OR on all given filters.",
                           type: OfType.list(
                               OfType.__TypeReference(kind: .list),
                               ofType: OfType.nonNull(
                                   OfType.__TypeReference(kind: .nonNull),
                                   ofType: OfType.inputObject(
                                       OfType.__TypeReference(kind: .inputObject,
                                                              name: "AssetSubscriptionFilter", description: nil))
                               )
                           ),
                           defaultValue: nil
                       ),
                       __InputValue(
                           name: "mutation_in",
                           description: "The subscription event gets dispatched when it\'s listed in mutation_in",
                           type: OfType.list(
                               OfType.__TypeReference(kind: .list),
                               ofType: OfType.nonNull(
                                   OfType.__TypeReference(kind: .nonNull),
                                   ofType: .enum(OfType.__TypeReference(kind: .enum, name: "_ModelMutationType", description: nil))
                               )
                           ),
                           defaultValue: nil
                       ),
                       __InputValue(
                           name: "updatedFields_contains",
                           description: "The subscription event gets only dispatched when one of the updated fields names is included in this list",
                           type: .scalar(OfType.__TypeReference(kind: .scalar, name: "String", description: nil)),
                           defaultValue: nil
                       ),
                       __InputValue(
                           name: "updatedFields_contains_every",
                           description: "The subscription event gets only dispatched when all of the field names included in this list have been updated",
                           type: OfType.list(
                               OfType.__TypeReference(kind: .list),
                               ofType: OfType.nonNull(
                                   OfType.__TypeReference(kind: .nonNull),
                                   ofType: .scalar(OfType.__TypeReference(kind: .scalar, name: "String", description: nil))
                               )
                           ),
                           defaultValue: nil
                       ),
                       __InputValue(
                           name: "updatedFields_contains_some",
                           description: "The subscription event gets only dispatched when some of the field names included in this list have been updated",
                           type: OfType.list(
                               OfType.__TypeReference(kind: .list),
                               ofType: OfType.nonNull(
                                   OfType.__TypeReference(kind: .nonNull),
                                   ofType: .scalar(OfType.__TypeReference(kind: .scalar, name: "String", description: nil))
                               )
                           ),
                           defaultValue: nil
                       ),
                       __InputValue(
                           name: "node",
                           description: nil,
                           type: .inputObject(OfType.__TypeReference(kind: .inputObject, name: "AssetSubscriptionFilterNode", description: nil)),
                           defaultValue: nil
                       ),
                   ],
                   ofType: nil)
        )
    }
    
    func testParseJSONOtherStarWarsSchema() throws {
        XCTAssertEqual(self.otherSWAPISchema.queryType.name, "Query")
        XCTAssertEqual(self.otherSWAPISchema.mutationType?.name, "Mutation")
        XCTAssertEqual(self.otherSWAPISchema.subscriptionType?.name, "Subscription")
        
        XCTAssertEqual(self.otherSWAPISchema.types.filter { $0.kind == .enum }.count, 4)
        XCTAssertEqual(self.otherSWAPISchema.types.filter { $0.kind == .object }.count, 16)
        XCTAssertEqual(self.otherSWAPISchema.types.filter { $0.kind == .inputObject }.count, 2)
        XCTAssertEqual(self.otherSWAPISchema.types.filter { $0.kind == .interface }.count, 1)
        XCTAssertEqual(self.otherSWAPISchema.types.filter { $0.kind == .scalar }.count, 5)
        XCTAssertEqual(self.otherSWAPISchema.types.filter { $0.kind == .list }.count, 0)
        XCTAssertEqual(self.otherSWAPISchema.types.filter { $0.kind == .nonNull }.count, 0)
        XCTAssertEqual(self.otherSWAPISchema.types.filter { $0.kind == .union }.count, 1)
    }
    
    func testParseJSONBaseTypesSchema() throws {
        XCTAssertEqual(self.baseTypesSchema.queryType.name, "MyQuery")
        XCTAssertEqual(self.baseTypesSchema.mutationType?.name, "MyMutation")
        XCTAssertEqual(self.baseTypesSchema.subscriptionType?.name, "MySubscription")

        XCTAssertEqual(self.baseTypesSchema.types.filter { $0.kind == .enum }.count, 2)
        XCTAssertEqual(self.baseTypesSchema.types.filter { $0.kind == .object }.count, 6)
        XCTAssertEqual(self.baseTypesSchema.types.filter { $0.kind == .inputObject }.count, 0)
        XCTAssertEqual(self.baseTypesSchema.types.filter { $0.kind == .interface }.count, 1)
        XCTAssertEqual(self.baseTypesSchema.types.filter { $0.kind == .scalar }.count, 2)
        XCTAssertEqual(self.baseTypesSchema.types.filter { $0.kind == .list }.count, 0)
        XCTAssertEqual(self.baseTypesSchema.types.filter { $0.kind == .nonNull }.count, 0)
        XCTAssertEqual(self.baseTypesSchema.types.filter { $0.kind == .union }.count, 0)
    }
    
    func testParsedEnum() {
        let `enum` = self.otherSWAPISchema.types.first { $0.kind == .enum }
        XCTAssertEqual(`enum`,
            __Type(kind: .enum,
                   name: "Episode",
                   description: "The episodes in the Star Wars trilogy",
                   fields: nil,
                   interfaces: nil,
                   possibleTypes: nil,
                   enumValues: [
                    __EnumValue(name: "NEWHOPE",
                                description: "Star Wars Episode IV: A New Hope, released in 1977.",
                                isDeprecated: false,
                                deprecationReason: nil),
                    __EnumValue(name: "EMPIRE",
                                description: "Star Wars Episode V: The Empire Strikes Back, released in 1980.",
                                isDeprecated: false,
                                deprecationReason: nil),
                    __EnumValue(name: "JEDI",
                                description: "Star Wars Episode VI: Return of the Jedi, released in 1983.",
                                isDeprecated: false,
                                deprecationReason: nil)
                   ], inputFields: nil, ofType: nil))
    }
    
    func testParsedObject() {
        let __fieldObject = self.swapiSchema.types.first { $0.kind == .object && $0.name == "__Field" }
        XCTAssertEqual(__fieldObject,
            __Type(kind: .object,
                   name: "__Field",
                   description: "Object and Interface types are described by a list of Fields, each of which has a name, potentially a list of arguments, and a return type.",
                   fields: [
                    __Field(name: "name",
                            description: nil,
                            args: [],
                            type: .nonNull(OfType.__TypeReference(kind: .nonNull, name: nil, description: nil),
                                           ofType: .scalar(OfType.__TypeReference(kind: .scalar,
                                                                                  name: "String",
                                                                                  description: nil))),
                            isDeprecated: false,
                            deprecationReason: nil),
                    __Field(name: "description",
                            description: nil,
                            args: [],
                            type: .scalar(OfType.__TypeReference(kind: .scalar, name: Optional("String"), description: nil)),
                            isDeprecated: false,
                            deprecationReason: nil),
                    __Field(name: "args",
                            description: nil,
                            args: [],
                            type: .nonNull(OfType.__TypeReference(kind: .nonNull, name: nil, description: nil),
                                           ofType: .list(OfType.__TypeReference(kind: .list, name: nil, description: nil),
                                                         ofType: .nonNull(OfType.__TypeReference(kind: .nonNull, name: nil, description: nil),
                                                                          ofType: .object(OfType.__TypeReference(kind: .object,
                                                                                                                 name: "__InputValue",
                                                                                                                 description: nil))))),
                            isDeprecated: false,
                            deprecationReason: nil),
                    __Field(name: "type",
                            description: nil,
                            args: [],
                            type: .nonNull(OfType.__TypeReference(kind: .nonNull, name: nil, description: nil),
                                           ofType: .object(OfType.__TypeReference(kind: .object, name: "__Type", description: nil))),
                            isDeprecated: false,
                            deprecationReason: nil),
                    __Field(name: "isDeprecated",
                            description: nil,
                            args: [],
                            type: .nonNull(OfType.__TypeReference(kind: .nonNull, name: nil, description: nil),
                                           ofType: .scalar(OfType.__TypeReference(kind: .scalar, name: "Boolean", description: nil))),
                            isDeprecated: false,
                            deprecationReason: nil),
                    __Field(name: "deprecationReason",
                            description: nil,
                            args: [],
                            type: OfType.scalar(OfType.__TypeReference(kind: .scalar, name: "String", description: nil)),
                            isDeprecated: false,
                            deprecationReason: nil)
                   ],
                   interfaces: [], possibleTypes: nil, enumValues: nil, inputFields: nil, ofType: nil))
    }
    
    func testParsedInputObject() {
        let inputObject = self.otherSWAPISchema.types.first { $0.kind == .inputObject && $0.name == "ReviewInput" }
        XCTAssertEqual(inputObject,
            __Type(kind: .inputObject,
                   name: "ReviewInput",
                   description: "The input object sent when someone is creating a new review",
                   fields: nil,
                   interfaces: nil,
                   possibleTypes: nil,
                   enumValues: nil,
                   inputFields: [
                    __InputValue(
                        name: "stars",
                        description: "0-5 stars",
                        type: .nonNull(OfType.__TypeReference(kind: .nonNull,
                                                                       name: nil,
                                                                       description: nil),
                                                ofType: .scalar(OfType.__TypeReference(kind: .scalar,
                                                                                       name: "Int",
                                                                                       description: nil))),
                                 defaultValue: nil),
                    __InputValue(
                        name: "commentary",
                        description: "Comment about the movie, optional",
                        type: .scalar(OfType.__TypeReference(kind: .scalar, name: "String", description: nil)),
                                 defaultValue: nil),
                    __InputValue(
                        name: "favorite_color",
                        description: "Favorite color, optional",
                        type: .inputObject(OfType.__TypeReference(kind: .inputObject, name: Optional("ColorInput"), description: nil)),
                                 defaultValue: nil)
                   ], ofType: nil))
    }
    
    func testDefaultValueIsString() {
        XCTAssertEqual(self.otherSWAPISchema.directives[2].args[0].defaultValue, "\"No longer supported\"")
    }
    
    func testParsedScalar() {
        let scalar = self.otherSWAPISchema.types.first { $0.kind == .scalar }
        XCTAssertEqual(scalar,
                       __Type(kind: .scalar,
                              name: "ID",
                              description: "The `ID` scalar type represents a unique identifier, often used to refetch an object or as key for a cache. The ID type appears in a JSON response as a String; however, it is not intended to be human-readable. When expected as an input type, any string (such as `\"4\"`) or integer (such as `4`) input value will be accepted as an ID.",
                              fields: nil, interfaces: nil, possibleTypes: nil, enumValues: nil, inputFields: nil, ofType: nil))
    }
    
    func testParsedInterface() {
        let interface = self.otherSWAPISchema.types.first { $0.kind == .interface }
        XCTAssertEqual(interface,
            __Type(kind: .interface,
                   name: "Character",
                   description: "A character from the Star Wars universe",
                   fields: [
                    __Field(name: "id",
                            description: "The ID of the character",
                            args: [],
                            type: .nonNull(OfType.__TypeReference(kind: .nonNull, name: nil, description: nil),
                                           ofType: .scalar(OfType.__TypeReference(kind: .scalar, name: "ID", description: nil))),
                            isDeprecated: false,
                            deprecationReason: nil),
                    __Field(name: "name",
                            description: "The name of the character",
                            args: [],
                            type: .nonNull(OfType.__TypeReference(kind: .nonNull, name: nil, description: nil),
                                           ofType: .scalar(OfType.__TypeReference(kind: .scalar, name: "String", description: nil))),
                            isDeprecated: false,
                            deprecationReason: nil),
                    __Field(name: "friends",
                            description: "The friends of the character, or an empty list if they have none",
                            args: [],
                            type: .list(OfType.__TypeReference(kind: .list, name: nil, description: nil),
                                        ofType: .interface(OfType.__TypeReference(kind: .interface, name: "Character", description: nil))),
                            isDeprecated: false,
                            deprecationReason: nil),
                    __Field(name: "friendsConnection",
                            description: "The friends of the character exposed as a connection with edges",
                            args: [
                                __InputValue(
                                    name: "first",
                                    description: "",
                                    type: .scalar(OfType.__TypeReference(kind: .scalar, name: "Int", description: nil)),
                                             defaultValue: nil),
                                __InputValue(
                                    name: "after",
                                    description: "",
                                    type: .scalar(OfType.__TypeReference(kind: .scalar, name: "ID", description: nil)),
                                             defaultValue: nil)
                            ],
                            type: .nonNull(OfType.__TypeReference(kind: .nonNull, name: nil, description: nil),
                                           ofType: .object(OfType.__TypeReference(kind: .object, name: "FriendsConnection", description: nil))),
                            isDeprecated: false,
                            deprecationReason: nil),
                    __Field(name: "appearsIn",
                            description: "The movies this character appears in",
                            args: [],
                            type: .nonNull(OfType.__TypeReference(kind: .nonNull, name: nil, description: nil),
                                           ofType: .list(OfType.__TypeReference(kind: .list, name: nil, description: nil),
                                                         ofType: .enum(OfType.__TypeReference(kind: .enum, name: "Episode", description: nil)))),
                            isDeprecated: false,
                            deprecationReason: nil)
                   ],
                   interfaces: nil,
                   possibleTypes: [
                    .object(OfType.__TypeReference(kind: .object, name: Optional("Human"), description: nil)),
                    .object(OfType.__TypeReference(kind: .object, name: Optional("Droid"), description: nil))
                   ],
                   enumValues: nil, inputFields: nil, ofType: nil))
    }
    
    func testParsedUnion() {
        let union = self.otherSWAPISchema.types.first { $0.kind == .union }
        XCTAssertEqual(union,
            __Type(kind: .union,
                   name: "SearchResult",
                   description: "",
                   fields: nil,
                   interfaces: nil,
                   possibleTypes: [
                    .object(OfType.__TypeReference(kind: .object, name: Optional("Human"), description: nil)),
                    .object(OfType.__TypeReference(kind: .object, name: Optional("Droid"), description: nil)),
                    .object(OfType.__TypeReference(kind: .object, name: Optional("Starship"), description: nil))
                   ],
                   enumValues: nil, inputFields: nil, ofType: nil))
    }
}
