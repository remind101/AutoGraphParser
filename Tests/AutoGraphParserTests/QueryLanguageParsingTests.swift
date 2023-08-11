import XCTest
@testable import AutoGraphParser
import Parsing

// TODO: Use Prop Tests.

final class QueryLanguageParsingTests: XCTestCase {
    func testGraphQL() throws {
        // TODO: Test a full Document once ready.
    }
    
    func testNameParsing() throws {
        let input = "Some_Name_1234"
        let name = try Name.parserPrinter.parse(input)
        XCTAssertEqual(name.value, "Some_Name_1234")
    }
    
    func testArgumentParsing() throws {
        var input = "arg:true"
        var argument = try Argument<IsConst>.parser.parse(input)
        XCTAssertEqual(argument, Argument<IsConst>(name: Name("arg"), value: .bool(true)))

        input = "arg:true"
        argument = try Argument<IsConst>.parser.parse(input)
        XCTAssertEqual(argument, Argument<IsConst>(name: Name("arg"), value: .bool(true)))

        input = "arg :1"
        argument = try Argument<IsConst>.parser.parse(input)
        XCTAssertEqual(argument, Argument<IsConst>(name: Name("arg"), value: .int(1)))

        input = "arg: 1.0"
        argument = try Argument<IsConst>.parser.parse(input)
        XCTAssertEqual(argument, Argument<IsConst>(name: Name("arg"), value: .float(1.0)))

        input = "arg: \"1.0\""
        argument = try Argument<IsConst>.parser.parse(input)
        XCTAssertEqual(argument, Argument<IsConst>(name: Name("arg"), value: .string("1.0")))

        input = "arg: \" false\""
        argument = try Argument<IsConst>.parser.parse(input)
        XCTAssertEqual(argument, Argument<IsConst>(name: Name("arg"), value: .string(" false")))

        input = "{ bool: \"false\" }"
        let objectValue = try ObjectValue<IsConst>.parser.parse(input)
        XCTAssertEqual(objectValue, .init(fields: [.init(name: Name("bool"), value: .string("false"))]))

        input = "var: $yeet"
        var varArgument = try Argument<IsVariable>.parser.parse(input)
        XCTAssertEqual(varArgument, Argument<IsVariable>(
            name: Name("var"),
            value: .variable(Variable(name: Name("yeet")), IsVariable()))
        )
        
        input = "obj: { var: $yeet}"
        varArgument = try Argument<IsVariable>.parser.parse(input)
        XCTAssertEqual(varArgument, Argument<IsVariable>(
            name: Name("obj"),
            value: .object(.init(fields: [
                .init(name: Name("var"), value: .variable(Variable(name: Name("yeet")), IsVariable()))
            ]))
        ))
        
        input = "obj: { bool: \" false\", list :[1, 2, 3], var: $yeet}"
        varArgument = try Argument<IsVariable>.parser.parse(input)
        XCTAssertEqual(varArgument, Argument<IsVariable>(
            name: Name("obj"),
            value: .object(.init(fields: [
                .init(name: Name("bool"), value: .string(" false")),
                .init(name: Name("list"), value: .list([.int(1), .int(2), .int(3)])),
                .init(name: Name("var"), value: .variable(Variable(name: Name("yeet")), IsVariable()))
            ]))
        ))
    }
    
    func testDirectiveParsing() throws {
        // @ Name Arguments_?Const-opt
        var input = "@dir"
        var directive = try Directive<IsVariable>.parser.parse(input)
        XCTAssertEqual(directive, Directive(name: Name("dir"), arguments: nil))

        input = "@dir( obj: { bool: \" false\", list :[1, 2, 3], var: $yeet}, scalar: 1 )"
        directive = try Directive<IsVariable>.parser.parse(input)
        XCTAssertEqual(directive, Directive(name: Name("dir"), arguments: [
            Argument<IsVariable>(
                name: Name("obj"),
                value: .object(.init(fields: [
                    .init(name: Name("bool"), value: .string(" false")),
                    .init(name: Name("list"), value: .list([.int(1), .int(2), .int(3)])),
                    .init(name: Name("var"), value: .variable(Variable(name: Name("yeet")), IsVariable()))
                ]))
            ),
            Argument<IsVariable>(name: Name("scalar"), value: .int(1))
        ]))
        
        input = "dir"
        XCTAssertThrowsError(try Directive<IsVariable>.parser.parse(input))
        
        input = "@dir( )"
        XCTAssertThrowsError(try Directive<IsVariable>.parser.parse(input))
    }
    
    func testNamedTypeParsing() throws {
        /// NamedType:
        ///   Name
        let input = "Some_Name_1234"
        let name = try NamedType.parser.parse(input)
        XCTAssertEqual(name.name.value, "Some_Name_1234")
    }
    
    func testTypeParsing() throws {
        /// Type:
        ///   NamedType
        ///   ListType
        ///   NonNullType
        /// ListType:
        ///   `[` Type `]`
        /// NonNullType:
        ///   NamedType `!`
        ///   ListType `!`
        var input = "Some_Name_1234"
        var type = try `Type`.namedTypeParser.parse(input)
        XCTAssertEqual(type, .namedType(NamedType(name: Name("Some_Name_1234"))))
        
        input = "Some_Name_1234"
        type = try `Type`.parser.parse(input)
        XCTAssertEqual(type, .namedType(NamedType(name: Name("Some_Name_1234"))))

        // nonull.
        input = "Some_Name_1234!"
        type = try `Type`.nonNullTypeParser.parse(input)
        XCTAssertEqual(type, .nonNullType(.namedType(NamedType(name: Name("Some_Name_1234")))))
        
        input = "Some_Name_1234!"
        type = try `Type`.parser.parse(input)
        XCTAssertEqual(type, .nonNullType(.namedType(NamedType(name: Name("Some_Name_1234")))))

        // list.
        input = "[Some_Name_1234]"
        type = try `Type`.listTypeParser.parse(input)
        XCTAssertEqual(type, .listType(.namedType(NamedType(name: Name("Some_Name_1234")))))
        
        input = "[Some_Name_1234]"
        type = try `Type`.parser.parse(input)
        XCTAssertEqual(type, .listType(.namedType(NamedType(name: Name("Some_Name_1234")))))

        // list-nonull.
        input = "[Some_Name_1234!]"
        type = try `Type`.listTypeParser.parse(input)
        XCTAssertEqual(type, .listType(.nonNullType(.namedType(NamedType(name: Name("Some_Name_1234"))))))
        
        input = "[Some_Name_1234!]"
        type = try `Type`.parser.parse(input)
        XCTAssertEqual(type, .listType(.nonNullType(.namedType(NamedType(name: Name("Some_Name_1234"))))))

        // nonull-list.
        input = "[Some_Name_1234]!"
        type = try `Type`.nonNullTypeParser.parse(input)
        XCTAssertEqual(type, .nonNullType(.listType(.namedType(NamedType(name: Name("Some_Name_1234"))))))
        
        input = "[Some_Name_1234]!"
        type = try `Type`.parser.parse(input)
        XCTAssertEqual(type, .nonNullType(.listType(.namedType(NamedType(name: Name("Some_Name_1234"))))))
        
        // nonnull-list-nonnull.
        input = "[Some_Name_1234!]!"
        type = try `Type`.nonNullTypeParser.parse(input)
        XCTAssertEqual(type, .nonNullType(.listType(.nonNullType(.namedType(NamedType(name: Name("Some_Name_1234")))))))
        input = "[Some_Name_1234!]!"
        type = try `Type`.parser.parse(input)
        XCTAssertEqual(type, .nonNullType(.listType(.nonNullType(.namedType(NamedType(name: Name("Some_Name_1234")))))))
        
        // errors.
        input = "[Some_Name_1234, Another_Type]"
        XCTAssertThrowsError(try `Type`.parser.parse(input))
        
        input = "[Some_Name_1234"
        XCTAssertThrowsError(try `Type`.parser.parse(input))
        
        input = "Some_Name_1234]"
        XCTAssertThrowsError(try `Type`.parser.parse(input))
    }
    
    func testVariable() throws {
        ///  Variable:
        ///    $`Name`
        var input = "$Some_Name_1234"
        let variable = try Variable.parser.parse(input)
        XCTAssertEqual(variable, Variable(name: Name("Some_Name_1234")))
        
        input = "Some_Name_1234"
        XCTAssertThrowsError(try Variable.parser.parse(input))
    }
    
    func testValue() throws {
        /// Value_Const:
        ///   [if not Const] Variable
        ///   IntValue
        ///   FloatValue
        ///   StringValue
        ///   BooleanValue
        ///   NullValue
        ///   EnumValue
        ///   ListValue_?Const
        ///   ObjectValue_?Const
        
        // variable
        var input = "$Some_Var_1234"
        var valueVar = try Value<IsVariable>.parser.parse(input)
        XCTAssertEqual(valueVar, .variable(Variable(name: "Some_Var_1234"), IsVariable()))
        
        // int.
        input = "1"
        var value = try Value<IsConst>.parser.parse(input)
        XCTAssertEqual(value, .int(1))
        
        // float.
        input = "1.0"
        value = try Value<IsConst>.parser.parse(input)
        XCTAssertEqual(value, .float(1.0))
        
        // string.
        input = "\"1.0\""
        value = try Value<IsConst>.parser.parse(input)
        XCTAssertEqual(value, .string("1.0"))
        
        // bool.
        input = "true"
        value = try Value<IsConst>.parser.parse(input)
        XCTAssertEqual(value, .bool(true))
        
        input = "false"
        value = try Value<IsConst>.parser.parse(input)
        XCTAssertEqual(value, .bool(false))
        
        input = "null"
        value = try Value<IsConst>.parser.parse(input)
        XCTAssertEqual(value, .null)
        
        // enum.
        input = "Some_Enum_1234"
        value = try Value<IsConst>.parser.parse(input)
        XCTAssertEqual(value, .enum("Some_Enum_1234"))
        
        // list.
        input = "[Some_Enum_1234, 1, \"1\", $var]"
        valueVar = try Value<IsVariable>.parser.parse(input)
        XCTAssertEqual(valueVar, .list([.enum("Some_Enum_1234"), .int(1), .string("1"), .variable(Variable(name: "var"), IsVariable())]))
        
        // obj.
        input = """
        {
            a: Some_Enum_1234,
            b: 1.0,
            c: true,
            d: null,
            e: [false, $var] }
        """
        valueVar = try Value<IsVariable>.parser.parse(input)
        XCTAssertEqual(valueVar, .object(ObjectValue(fields: [
            ObjectField(name: "a", value: .enum("Some_Enum_1234")),
            ObjectField(name: "b", value: .float(1.0)),
            ObjectField(name: "c", value: .bool(true)),
            ObjectField(name: "d", value: .null),
            ObjectField(name: "e", value: .list([.bool(false), .variable(Variable(name: "var"), IsVariable())]))
        ])))
    }
    
    func testVariableDefinition() throws {
        /// VariableDefinition
        ///   Variable `:` Type DefaultValue_opt Directives_Const_opt
        /// DefaultValue:
        ///   = Value_Const
        var input = "$Some_Name_1234: Some_Type_1234"
        var varDefinition = try VariableDefinition.parser.parse(input)
        XCTAssertEqual(varDefinition,
                       VariableDefinition(
                        variable: Variable(name: Name("Some_Name_1234")),
                        type: .namedType(NamedType(name: Name("Some_Type_1234"))),
                        defaultValue: nil,
                        directives: nil))
        
        input = "$Some_Name_1234 :Some_Type_1234"
        varDefinition = try VariableDefinition.parser.parse(input)
        XCTAssertEqual(varDefinition,
                       VariableDefinition(
                        variable: Variable(name: Name("Some_Name_1234")),
                        type: .namedType(NamedType(name: Name("Some_Type_1234"))),
                        defaultValue: nil,
                        directives: nil))
        
        // default value.
        input = "$Some_Name_1234: Some_Type_1234 = \"abc\""
        varDefinition = try VariableDefinition.parser.parse(input)
        XCTAssertEqual(varDefinition,
                       VariableDefinition(
                        variable: Variable(name: Name("Some_Name_1234")),
                        type: .namedType(NamedType(name: Name("Some_Type_1234"))),
                        defaultValue: .string("abc"),
                        directives: nil))
        
        input = "$Some_Name_1234: Some_Type_1234=1.0"
        varDefinition = try VariableDefinition.parser.parse(input)
        XCTAssertEqual(varDefinition,
                       VariableDefinition(
                        variable: Variable(name: Name("Some_Name_1234")),
                        type: .namedType(NamedType(name: Name("Some_Type_1234"))),
                        defaultValue: .float(1.0),
                        directives: nil))
        
        input = "$Some_Name_1234: Some_Type_1234 =[1,{ a: \"a\",b :null, c : c }]"
        varDefinition = try VariableDefinition.parser.parse(input)
        XCTAssertEqual(varDefinition,
                       VariableDefinition(
                        variable: Variable(name: Name("Some_Name_1234")),
                        type: .namedType(NamedType(name: Name("Some_Type_1234"))),
                        defaultValue: .list([
                            .int(1),
                            .object(ObjectValue(fields: [
                                ObjectField(name: "a", value: .string("a")),
                                ObjectField(name: "b", value: .null),
                                ObjectField(name: "c", value: .enum("c"))
                            ]))
                        ]),
                        directives: nil))
        
        // directives.
        input = "$Some_Name_1234: Some_Type_1234 @dir1 @dir2(aaa: true, b_123: [1, 1.0])"
        varDefinition = try VariableDefinition.parser.parse(input)
        XCTAssertEqual(varDefinition,
                       VariableDefinition(
                        variable: Variable(name: Name("Some_Name_1234")),
                        type: .namedType(NamedType(name: Name("Some_Type_1234"))),
                        defaultValue: nil,
                        directives: [
                            Directive(name: "dir1", arguments: nil),
                            Directive(name: "dir2", arguments: [
                                Argument(name: "aaa", value: .bool(true)),
                                Argument(name: "b_123", value: .list([
                                    .int(1),
                                    .float(1.0)
                                ]))
                            ])
                        ]))
        
        // error.
        input = "$Some_Name_1234: Some_Type_1234 1.0"
        XCTAssertThrowsError(try VariableDefinition.parser.parse(input))
    }
    
    func testField() throws {
        /// Field:
        ///   Alias-opt Name Arguments_opt Directives_opt SelectionSet_opt
        var input = "Some_Name_1234"
        var field = try Field.parser.parse(input)
        XCTAssertEqual(field, Field(alias: nil, name: "Some_Name_1234", arguments: nil, directives: nil, selectionSet: nil))
        
        input = "Alias_1234 : Some_Name_1234"
        field = try Field.parser.parse(input)
        XCTAssertEqual(field, Field(alias: "Alias_1234", name: "Some_Name_1234", arguments: nil, directives: nil, selectionSet: nil))
        
        input = "Alias_1234:Some_Name_1234"
        field = try Field.parser.parse(input)
        XCTAssertEqual(field, Field(alias: "Alias_1234", name: "Some_Name_1234", arguments: nil, directives: nil, selectionSet: nil))
        
        input = "Some_Name_1234(b_123: [1, 1.0], aaa: true)"
        field = try Field.parser.parse(input)
        XCTAssertEqual(field, Field(alias: nil, name: "Some_Name_1234", arguments: [
            Argument(name: "b_123", value: .list([
                .int(1),
                .float(1.0)
            ])),
            Argument(name: "aaa", value: .bool(true))
        ], directives: nil, selectionSet: nil))
        
        input = "Some_Name_1234 @dir1 @dir2(aaa: true, b_123: [1, 1.0])"
        field = try Field.parser.parse(input)
        XCTAssertEqual(field, Field(alias: nil, name: "Some_Name_1234", arguments: nil, directives: [
            Directive(name: "dir1", arguments: nil),
            Directive(name: "dir2", arguments: [
                Argument(name: "aaa", value: .bool(true)),
                Argument(name: "b_123", value: .list([
                    .int(1),
                    .float(1.0)
                ]))
            ])
        ], selectionSet: nil))
        
        input = "Some_Name_1234{ alias: Some_Name_1234 }"
        field = try Field.parser.parse(input)
        XCTAssertEqual(field, Field(alias: nil,
                                    name: "Some_Name_1234",
                                    arguments: nil,
                                    directives: nil,
                                    selectionSet: SelectionSet(selections: [
                                        .field(Field(alias: "alias",
                                                     name: "Some_Name_1234",
                                                     arguments: nil,
                                                     directives: nil,
                                                     selectionSet: nil))
                                    ])))
        
        // Kitchen sink
        input = "Some_Name_1234 @dir1 @dir2(aaa: true, b_123: [1, 1.0]) { alias: Some_Name_1234 }"
        field = try Field.parser.parse(input)
        XCTAssertEqual(field, Field(alias: nil, name: "Some_Name_1234", arguments: nil, directives: [
            Directive(name: "dir1", arguments: nil),
            Directive(name: "dir2", arguments: [
                Argument(name: "aaa", value: .bool(true)),
                Argument(name: "b_123", value: .list([
                    .int(1),
                    .float(1.0)
                ]))
            ])
        ],
        selectionSet: SelectionSet(selections: [
            .field(Field(alias: "alias",
                         name: "Some_Name_1234",
                         arguments: nil,
                         directives: nil,
                         selectionSet: nil))
        ])))
    }
    
    func testFragmentSpread() throws {
        /// FragmentSpread:
        ///   ...FragmentName Directives-opt
        /// FragmentName:
        ///   Name but not `on`
        var input = "...Some_Name_1234"
        var fragmentSpread = try FragmentSpread.parser.parse(input)
        XCTAssertEqual(fragmentSpread, FragmentSpread(name: "Some_Name_1234", directives: nil))
        
        input = "...  Some_Name_1234"
        fragmentSpread = try FragmentSpread.parser.parse(input)
        XCTAssertEqual(fragmentSpread, FragmentSpread(name: "Some_Name_1234", directives: nil))
        
        input = "...Some_Name_1234  @dir1 @dir2(aaa: true, b_123: [1, 1.0])"
        fragmentSpread = try FragmentSpread.parser.parse(input)
        XCTAssertEqual(fragmentSpread, FragmentSpread(name: "Some_Name_1234", directives: [
            Directive(name: "dir1", arguments: nil),
            Directive(name: "dir2", arguments: [
                Argument(name: "aaa", value: .bool(true)),
                Argument(name: "b_123", value: .list([
                    .int(1),
                    .float(1.0)
                ]))
            ])
        ]))
        
        input = "...on"
        XCTAssertThrowsError(try FragmentSpread.parser.parse(input))
        
        input = "...on @dir"
        XCTAssertThrowsError(try FragmentSpread.parser.parse(input))
    }
    
    func testTypeCondition() throws {
        /// TypeCondition:
        ///   `on` NamedType
        let input = "on Some_Name_1234"
        let typeCondition = try TypeCondition.parser.parse(input)
        XCTAssertEqual(typeCondition, TypeCondition(name: NamedType(name: "Some_Name_1234")))
    }
    
    func testInlineFragment() throws {
        ///  InlineFragment:
        ///    ... TypeCondition_opt Directives_opt SelectionSet
        var input = "...{ field }"
        var inlineFragment = try InlineFragment.parser.parse(input)
        XCTAssertEqual(inlineFragment,
                       InlineFragment(typeCondition: nil,
                                      directives: nil,
                                      selectionSet: SelectionSet(selections: [
                                        .field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))
                                      ])))
        
        input = "... on Some_Name_1234 @dir1 @dir2(a: $a) { alias: Some_Name_1234 }"
        inlineFragment = try InlineFragment.parser.parse(input)
        XCTAssertEqual(inlineFragment,
                       InlineFragment(typeCondition: TypeCondition(name: NamedType(name: "Some_Name_1234")),
                                      directives: [
                                        Directive<IsVariable>(name: "dir1", arguments: nil),
                                        Directive<IsVariable>(name: "dir2", arguments: [
                                            Argument<IsVariable>(name: "a", value: .variable(Variable(name: "a"), IsVariable()))
                                        ])
                                      ],
                                      selectionSet: SelectionSet(selections: [
                                        .field(Field(alias: "alias", name: "Some_Name_1234", arguments: nil, directives: nil, selectionSet: nil))
                                      ])))
    }
    
    func testSelection() throws {
        /// Selection:
        ///   Field
        ///   FragmentSpread
        ///   InlineFragment
        var input = "Alias_1234: Some_Name_1234"
        var selection = try Selection.parser.parse(input)
        XCTAssertEqual(selection, Selection.field(Field(alias: "Alias_1234", name: "Some_Name_1234", arguments: nil, directives: nil, selectionSet: nil)))
        
        input = "...Some_Name_1234  @dir1 @dir2(aaa: true, b_123: [1, 1.0])"
        selection = try Selection.parser.parse(input)
        XCTAssertEqual(selection, Selection.fragmentSpread(FragmentSpread(name: "Some_Name_1234", directives: [
            Directive(name: "dir1", arguments: nil),
            Directive(name: "dir2", arguments: [
                Argument(name: "aaa", value: .bool(true)),
                Argument(name: "b_123", value: .list([
                    .int(1),
                    .float(1.0)
                ]))
            ])
        ])))
        
        input = "...{ Alias_1234 :Some_Name_1234 alias2: field2 ...Some_Name_1234 }"
        selection = try Selection.parser.parse(input)
        XCTAssertEqual(selection, Selection.inlineFragment(InlineFragment(
            typeCondition: nil,
            directives: nil,
            selectionSet: SelectionSet(selections: [
                .field(Field(alias: "Alias_1234", name: "Some_Name_1234", arguments: nil, directives: nil, selectionSet: nil)),
                .field(Field(alias: "alias2", name: "field2", arguments: nil, directives: nil, selectionSet: nil)),
                .fragmentSpread(FragmentSpread(name: "Some_Name_1234", directives: nil))
            ]))))
    }
    
    func testOperationType() throws {
        /// OperationType: oneof
        ///   query    mutation    subscription
        var input = "query"
        var operationType = try OperationDefinition.OperationType.parser.parse(input)
        XCTAssertEqual(operationType, .query)
        
        input = "mutation"
        operationType = try OperationDefinition.OperationType.parser.parse(input)
        XCTAssertEqual(operationType, .mutation)
        
        input = "subscription"
        operationType = try OperationDefinition.OperationType.parser.parse(input)
        XCTAssertEqual(operationType, .subscription)
    }
    
    func testOperationDefinition() throws {
        /// OperationDefinition:
        ///   OperationType Name_opt VariableDefinitions_opt Directives_opt SelectionSet
        var input = """
        query {
            alias: field(a: $a)
            ...on Some_Name_1234 { field } # comment
            ...Some_Name_1234  @dir1 @dir2( aaa: true, b_123: [ 1, 1.0 ] )
            obj @dir1 {
                #junk
                a b c @dir1 { d }
            }
        }
        """
        var operationDefinition = try OperationDefinition.parser.parse(input)
        XCTAssertEqual(
            operationDefinition,
            OperationDefinition(
                operation: .query,
                name: nil,
                variableDefinitions: nil,
                directives: nil,
                selectionSet: SelectionSet(selections: [
                    .field(Field(alias: "alias",
                                 name: "field",
                                 arguments: [
                                    Argument(name: "a", value: .variable(Variable(name: "a"), IsVariable()))
                                 ],
                                 directives: nil,
                                 selectionSet: nil)),
                    .inlineFragment(InlineFragment(typeCondition: TypeCondition(name: NamedType(name: "Some_Name_1234")),
                                                   directives: nil,
                                                   selectionSet: SelectionSet(selections: [
                                                    .field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))
                                                   ]))),
                    .fragmentSpread(FragmentSpread(name: "Some_Name_1234", directives: [
                        Directive(name: "dir1", arguments: nil),
                        Directive(name: "dir2", arguments: [
                            Argument(name: "aaa", value: .bool(true)),
                            Argument(name: "b_123", value: .list([
                                .int(1),
                                .float(1.0)
                            ]))
                        ])
                    ])),
                    .field(Field(alias: nil,
                                 name: "obj",
                                 arguments: nil, directives: [
                                    Directive(name: "dir1", arguments: nil)
                                 ],
                                 selectionSet: SelectionSet(selections: [
                                    .field(Field(alias: nil, name: "a", arguments: nil, directives: nil, selectionSet: nil)),
                                    .field(Field(alias: nil, name: "b", arguments: nil, directives: nil, selectionSet: nil)),
                                    .field(Field(alias: nil,
                                                 name: "c",
                                                 arguments: nil,
                                                 directives: [
                                                    Directive(name: "dir1", arguments: nil)
                                                 ],
                                                 selectionSet: SelectionSet(selections: [
                                                    .field(Field(alias: nil, name: "d", arguments: nil, directives: nil, selectionSet: nil))
                                                 ])))
                                 ])))
                ]))
        )
        
        input = "mutation Some_Op_1234 { field }"
        operationDefinition = try OperationDefinition.parser.parse(input)
        XCTAssertEqual(operationDefinition, OperationDefinition(operation: .mutation, name: "Some_Op_1234", variableDefinitions: nil, directives: nil, selectionSet: SelectionSet(selections: [.field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))])))
        
        input = "subscription { field }"
        operationDefinition = try OperationDefinition.parser.parse(input)
        XCTAssertEqual(operationDefinition, OperationDefinition(operation: .subscription, name: nil, variableDefinitions: nil, directives: nil, selectionSet: SelectionSet(selections: [.field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))])))
    }
    
    func testFragmentDefinition() throws {
        /// FragmentDefinition:
        ///   `fragment` FragmentName TypeCondition Directives_opt SelectionSet
        var input = """
        fragment CoolFragment_1234 on Some_Type_1234 { field }
        """
        var fragmentDefinition = try FragmentDefinition.parser.parse(input)
        XCTAssertEqual(
            fragmentDefinition,
            FragmentDefinition(name: "CoolFragment_1234", typeCondition: TypeCondition(name: NamedType(name: "Some_Type_1234")), directives: nil, selectionSet: SelectionSet(selections: [.field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))]))
        )
        
        input = """
        fragment CoolFragment_1234 on Some_Type_1234 @dir(a: true) {
            alias: field(a: $a)
            ...on Some_Name_1234 { field }
            ...Some_Name_1234  @dir1 @dir2(aaa: true, b_123: [1, 1.0])
            obj @dir1 {
                a b c @dir1 { d }
            }
        }
        """
        fragmentDefinition = try FragmentDefinition.parser.parse(input)
        XCTAssertEqual(
            fragmentDefinition,
            FragmentDefinition(
                name: "CoolFragment_1234",
                typeCondition: TypeCondition(name: NamedType(name: "Some_Type_1234")),
                directives: [
                    Directive(name: "dir", arguments: [
                        Argument(name: "a", value: .bool(true))
                    ])
                ],
                selectionSet: SelectionSet(selections: [
                    .field(Field(alias: "alias",
                                 name: "field",
                                 arguments: [
                                    Argument(name: "a", value: .variable(Variable(name: "a"), IsVariable()))
                                 ],
                                 directives: nil,
                                 selectionSet: nil)),
                    .inlineFragment(InlineFragment(typeCondition: TypeCondition(name: NamedType(name: "Some_Name_1234")),
                                                   directives: nil,
                                                   selectionSet: SelectionSet(selections: [
                                                    .field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))
                                                   ]))),
                    .fragmentSpread(FragmentSpread(name: "Some_Name_1234", directives: [
                        Directive(name: "dir1", arguments: nil),
                        Directive(name: "dir2", arguments: [
                            Argument(name: "aaa", value: .bool(true)),
                            Argument(name: "b_123", value: .list([
                                .int(1),
                                .float(1.0)
                            ]))
                        ])
                    ])),
                    .field(Field(alias: nil,
                                 name: "obj",
                                 arguments: nil, directives: [
                                    Directive(name: "dir1", arguments: nil)
                                 ],
                                 selectionSet: SelectionSet(selections: [
                                    .field(Field(alias: nil, name: "a", arguments: nil, directives: nil, selectionSet: nil)),
                                    .field(Field(alias: nil, name: "b", arguments: nil, directives: nil, selectionSet: nil)),
                                    .field(Field(alias: nil,
                                                 name: "c",
                                                 arguments: nil,
                                                 directives: [
                                                    Directive(name: "dir1", arguments: nil)
                                                 ],
                                                 selectionSet: SelectionSet(selections: [
                                                    .field(Field(alias: nil, name: "d", arguments: nil, directives: nil, selectionSet: nil))
                                                 ])))
                                 ])))
                ]))
        )
    }
    
    func testExecutableDefinition() throws {
        /// ExecutableDefinition:
        ///   OperationDefinition
        ///   FragmentDefinition
        var input = """
        fragment CoolFragment_1234 on Some_Type_1234 { field }
        """
        var executableDefinition = try ExecutableDefinition.parser.parse(input)
        XCTAssertEqual(
            executableDefinition,
            .fragmentDefinition(
                FragmentDefinition(name: "CoolFragment_1234", typeCondition: TypeCondition(name: NamedType(name: "Some_Type_1234")), directives: nil, selectionSet: SelectionSet(selections: [.field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))]))
            )
        )
        
        input = "mutation Some_Op_1234 { field }"
        executableDefinition = try ExecutableDefinition.parser.parse(input)
        XCTAssertEqual(
            executableDefinition,
            .operationDefinition(
                OperationDefinition(operation: .mutation, name: "Some_Op_1234", variableDefinitions: nil, directives: nil, selectionSet: SelectionSet(selections: [.field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))]))
            )
        )
    }
    
    func testExecutableDocument() throws {
        /// ExecutableDocument:
        ///   ExecutableDefinition_list
        var input = """
        fragment CoolFragment_1234 on Some_Type_1234 { field } mutation Some_Op_1234 { field } query { field }
        """
        var executableDocument = try ExecutableDocument.parser.parse(input)
        XCTAssertEqual(
            executableDocument,
            ExecutableDocument(executableDefinitions: [
                .fragmentDefinition(
                    FragmentDefinition(name: "CoolFragment_1234", typeCondition: TypeCondition(name: NamedType(name: "Some_Type_1234")), directives: nil, selectionSet: SelectionSet(selections: [.field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))]))
                ),
                .operationDefinition(
                    OperationDefinition(operation: .mutation, name: "Some_Op_1234", variableDefinitions: nil, directives: nil, selectionSet: SelectionSet(selections: [.field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))]))
                ),
                .operationDefinition(
                    OperationDefinition(operation: .query, name: nil, variableDefinitions: nil, directives: nil, selectionSet: SelectionSet(selections: [.field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))]))
                )
            ])
        )
        
        // Inlude some newlines.
        input = """
        \nfragment CoolFragment_1234 on Some_Type_1234 { field } #Comment
        
        mutation Some_Op_1234 { field }
        query { field }\n
        """
        executableDocument = try ExecutableDocument.parser.parse(input)
        XCTAssertEqual(
            executableDocument,
            ExecutableDocument(executableDefinitions: [
                .fragmentDefinition(
                    FragmentDefinition(name: "CoolFragment_1234", typeCondition: TypeCondition(name: NamedType(name: "Some_Type_1234")), directives: nil, selectionSet: SelectionSet(selections: [.field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))]))
                ),
                .operationDefinition(
                    OperationDefinition(operation: .mutation, name: "Some_Op_1234", variableDefinitions: nil, directives: nil, selectionSet: SelectionSet(selections: [.field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))]))
                ),
                .operationDefinition(
                    OperationDefinition(operation: .query, name: nil, variableDefinitions: nil, directives: nil, selectionSet: SelectionSet(selections: [.field(Field(alias: nil, name: "field", arguments: nil, directives: nil, selectionSet: nil))]))
                )
            ])
        )
    }
    
    func testIgnoredTokens() throws {
        var input = ",,,"
        try IgnoredTokens().parse(input)
        XCTAssertEqual(input, ",,,")
        
        input = """
        
           ,,,, # this is junk
        
        """
        let inputCopy = input
        try IgnoredTokens().parse(input)
        XCTAssertEqual(input, inputCopy)
        
        input = """
        c,,,a #junk
        1
        t
        """
        let parser = Parse {
            "c".utf8
            IgnoredTokens()
            "a".utf8
            IgnoredTokens()
            Int.parser()
            IgnoredTokens()
            "t".utf8
            IgnoredTokens()
        }
        let output = try parser.parse(input)
        XCTAssertEqual(output, 1)
    }
}
