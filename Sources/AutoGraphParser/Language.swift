import Parsing

// TODO: Eventually re-order to match spec's documentation order.
// TODO: Make everything a ParserPrinter.
// TODO: Make things Equatable.

/// https://spec.graphql.org/October2021/#sec-Document
/// TODO: Currently only handling Query, not Schema, parsing; not yet implemented:
/// ~~Definition:~~
///   ~~ExecutableDefinition~~
///   ~~TypeSystemDefinitionOrExtension~~
/// ~~Document:~~
///   ~~Definition_list~~

/// https://spec.graphql.org/October2021/#sec-Document
/// ExecutableDocument:
///   ExecutableDefinition_list
public struct ExecutableDocument: Hashable {
    let executableDefinitions: [ExecutableDefinition]
    
    static var parser: some Parser<Substring.UTF8View, ExecutableDocument> {
        Many {
            ExecutableDefinition.parser
        } separator: {
            Whitespace()
        }
        .map { ExecutableDocument(executableDefinitions: $0) }
    }
}

/// https://spec.graphql.org/October2021/#sec-Document
/// ExecutableDefinition:
///   OperationDefinition
///   FragmentDefinition
public enum ExecutableDefinition: Hashable {
    case operationDefinition(OperationDefinition)
    case fragmentDefinition(FragmentDefinition)
    
    static var parser: some Parser<Substring.UTF8View, ExecutableDefinition> {
        OneOf {
            OperationDefinition.parser.map { Self.operationDefinition($0) }
            FragmentDefinition.parser.map { Self.fragmentDefinition($0) }
        }
    }
}

/// https://spec.graphql.org/October2021/#sec-Language.Operations
/// OperationDefinition:
///   OperationType Name_opt VariableDefinitions_opt Directives_opt SelectionSet
///   ~~SelectionSet~~ We won't allow SelectionSet only queries.
public struct OperationDefinition: Hashable {
    /// OperationType: oneof
    ///   query    mutation    subscription
    public enum OperationType: String, Hashable {
        case query
        case mutation
        case subscription
        
        static var parser: some Parser<Substring.UTF8View, OperationType> {
            OneOf {
                "query".utf8.map { Self.query }
                "mutation".utf8.map { Self.mutation }
                "subscription".utf8.map { Self.subscription }
            }
        }
    }
    
    public let operation: OperationType
    public let name: Name?
    public let variableDefinitions: VariableDefinitions?
    public let directives: [Directive<IsVariable>]?
    public let selectionSet: SelectionSet
    
    static var parser: some Parser<Substring.UTF8View, OperationDefinition> {
        Parse {
            OperationType.parser
            Optionally {
                Whitespace()
                Name.parser
            }
            Optionally {
                Whitespace()
                VariableDefinitions.parser
            }
            Optionally {
                Whitespace()
                Directive<IsVariable>.listParser
            }
            Whitespace()
            SelectionSet.parser
        }
        .map { OperationDefinition(operation: $0.0, name: $0.1, variableDefinitions: $0.2, directives: $0.3, selectionSet: $0.4) }
    }
}

/// https://spec.graphql.org/October2021/#Alias
/// Alias:
///   Name `:`
///
/// Typealias to `Name` since it reduces to `Name :`.
public typealias Alias = Name

/// https://spec.graphql.org/October2021/#Name
public struct Name: Hashable, ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    public var value: String
    
    public init(stringLiteral value: String) {
        self.init(value)
    }
    
    public init(_ value: String) {
        self.value = value
    }
    
    struct NameParser: ParserPrinter {
        let parsePrinter = ParsePrint {
            Many(1, into: "") { string, fragment in
                string.append(contentsOf: fragment)
            } decumulator: { string in
                string.map(String.init).reversed().makeIterator()
            } element: {
                Prefix { $0.isNameCharacter }.map(.string)
            }
        }
        
        public func print(_ output: Name, into input: inout Substring.UTF8View) throws {
            try self.parsePrinter.print(output.value, into: &input)
        }
        
        public func parse(_ input: inout Substring.UTF8View) throws -> Name {
            // TODO: Somehow turn this into the NameParser itself.
            let parsed = try self.parsePrinter.parse(&input)
            return Name(parsed)
        }
    }
    
    // TODO: Swift 5.7  https://github.com/apple/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md
    // should make it possible to do `some Parser<String.SubSequence, Name>` and we won't need an
    // additional struct.
    static var parser: NameParser {
        NameParser()
    }
    
    static var aliasParser: some Parser<Substring.UTF8View, Name> {
        Parse {
            NameParser()
            Whitespace()
            ":".utf8
        }
    }
    
    static var fragmentNameParser: some Parser<Substring.UTF8View, Name> {
        struct NameIsOnError: Error {
            var localizedDescription: String {
                "FragmentName cannot be \"on\""
            }
        }
        return Name.parser.flatMap {
            if $0.value == "on" { Fail<Substring.UTF8View, Name>(throwing: NameIsOnError()) }
            else { Always($0) }
        }
    }
    
    static var butNotTrueOrFalseOrNullParser: some Parser<Substring.UTF8View, Name> {
        struct NameIsTrueOrFalseOrNullError: Error {
            var localizedDescription: String {
                "Enum case name cannot be \"true\" or \"false\" or \"null\""
            }
        }
        return self.parser.flatMap {
            if $0.value == "true" || $0.value == "false" || $0.value == "null" {
                Fail<Substring.UTF8View, Name>(throwing: NameIsTrueOrFalseOrNullError())
            }
            else {
                Always($0)
            }
        }
    }
}

/// https://github.com/pointfreeco/swift-parsing/blob/bc92e84968990b41640214b636667f35b6e5d44c/Sources/swift-parsing-benchmark/JSON.swift#L168
extension UTF8.CodeUnit {
    // TODO: Use new RegexBuilders.
    fileprivate var isNameCharacter: Bool {
        (.init(ascii: "0") ... .init(ascii: "9")).contains(self)
        || (.init(ascii: "A") ... .init(ascii: "Z")).contains(self)
        || (.init(ascii: "a") ... .init(ascii: "z")).contains(self)
        || self == .init(ascii: "_")
    }
    
    fileprivate var isHexDigit: Bool {
        (.init(ascii: "0") ... .init(ascii: "9")).contains(self)
        || (.init(ascii: "A") ... .init(ascii: "F")).contains(self)
        || (.init(ascii: "a") ... .init(ascii: "f")).contains(self)
    }
    
    fileprivate var isUnescapedJSONStringByte: Bool {
        self != .init(ascii: "\"") && self != .init(ascii: "\\") && self >= .init(ascii: " ")
    }
    
    public var isNumeric: Bool {
        (.init(ascii: "0") ... .init(ascii: "9")).contains(self)
    }
}

extension Conversion where Self == AnyConversion<Substring.UTF8View, String> {
    fileprivate static var unicode: Self {
        Self(
            apply: {
                UInt32(Substring($0), radix: 16)
                    .flatMap(UnicodeScalar.init)
                    .map(String.init)
            },
            unapply: {
                $0.unicodeScalars.first
                    .map { String(UInt32($0), radix: 16)[...].utf8 }
            }
        )
    }
}

public protocol ConstGrammar: Hashable {}
public typealias IsConst = Never
extension IsConst: ConstGrammar {}
public struct IsVariable: ConstGrammar {}

/// https://spec.graphql.org/October2021/#SelectionSet
/// SelectionSet:
///   { Selection_list }
public struct SelectionSet: Hashable {
    public let selections: [Selection]
    
    static var parser: some Parser<Substring.UTF8View, SelectionSet> {
        Parse {
            "{".utf8
            Whitespace()
            // Circular.
            Lazy {
                // Compiler internal failure from circular some types.
                // TODO: Report a bug.
                AnyParser(Selection.listParser)
            }
            Whitespace()
            "}".utf8
        }
        .map { SelectionSet(selections: $0) }
    }
}

/// https://spec.graphql.org/October2021/#Selection
/// Selection:
///   Field
///   FragmentSpread
///   InlineFragment
public indirect enum Selection: Hashable {
    public enum Kind: String {
        case field = "Field"
        case fragmentSpread = "FragmentSpread"
        case inlineFragment = "InlineFragment"
    }
    
    case field(Field)
    case fragmentSpread(FragmentSpread)
    case inlineFragment(InlineFragment)
    
    public var rawValue: String {
        switch self {
        case .field(_):
            return Kind.field.rawValue
        case .fragmentSpread(_):
            return Kind.fragmentSpread.rawValue
        case .inlineFragment(_):
            return Kind.inlineFragment.rawValue
        }
    }
    
    static var parser: some Parser<Substring.UTF8View, Selection> {
        OneOf {
            Field.parser.map { Selection.field($0) }
            FragmentSpread.parser.map { Selection.fragmentSpread($0) }
            InlineFragment.parser.map { Selection.inlineFragment($0) }
        }
    }
    
    static var listParser: some Parser<Substring.UTF8View, [Selection]> {
        Many {
            Selection.parser
        } separator: {
            Whitespace()
        }
    }
}

/// https://spec.graphql.org/October2021/#FragmentSpread
/// FragmentSpread:
///   ...FragmentName Directives-opt
/// FragmentName:
///   Name but not `on`
public struct FragmentSpread: Hashable {
    public let name: Name
    public let directives: [Directive<IsVariable>]?
    
    static var parser: some Parser<Substring.UTF8View, FragmentSpread> {
        Parse {
            "...".utf8
            Whitespace()
            Name.fragmentNameParser
            Optionally {
                Whitespace()
                Directive<IsVariable>.listParser
            }
        }
        .map {
            FragmentSpread(name: $0.0, directives: $0.1)
        }
    }
}

/// https://spec.graphql.org/October2021/#FragmentDefinition
/// FragmentDefinition:
///   `fragment` FragmentName TypeCondition Directives_opt SelectionSet
public struct FragmentDefinition: Hashable {
    public let name: Name
    public let typeCondition: TypeCondition
    public let directives: [Directive<IsVariable>]?
    public let selectionSet: SelectionSet
    
    static var parser: some Parser<Substring.UTF8View, FragmentDefinition> {
        Parse {
            "fragment".utf8
            Whitespace()
            Name.fragmentNameParser
            Whitespace()
            TypeCondition.parser
            Optionally {
                Whitespace()
                Directive<IsVariable>.listParser
            }
            Whitespace()
            SelectionSet.parser
        }
        .map { FragmentDefinition(name: $0.0, typeCondition: $0.1, directives: $0.2, selectionSet: $0.3) }
    }
}


/// https://spec.graphql.org/October2021/#sec-Type-Conditions
/// TypeCondition:
///   `on` NamedType
public struct TypeCondition: Hashable {
    public let name: NamedType
    
    static var parser: some Parser<Substring.UTF8View, TypeCondition> {
        Parse {
            "on".utf8
            Whitespace()
            NamedType.parser
        }
        .map { TypeCondition(name: $0) }
    }
}

/// https://spec.graphql.org/October2021/#sec-Inline-Fragments
///  InlineFragment:
///    ... TypeCondition_opt Directives_opt SelectionSet
public struct InlineFragment: Hashable {
    public let typeCondition: TypeCondition?
    public let directives: [Directive<IsVariable>]?
    public let selectionSet: SelectionSet
    
    static var parser: some Parser<Substring.UTF8View, InlineFragment> {
        Parse {
            "...".utf8
            Optionally {
                Whitespace()
                TypeCondition.parser
            }
            Optionally {
                Whitespace()
                Directive<IsVariable>.listParser
            }
            Whitespace()
            SelectionSet.parser
        }
        .map { InlineFragment(typeCondition: $0.0, directives: $0.1, selectionSet: $0.2) }
    }
}

/// https://spec.graphql.org/October2021/#sec-Language.Fields
/// Field:
///   Alias-opt Name Arguments_opt Directives_opt SelectionSet_opt
public struct Field: Hashable {
    public let alias: Alias?
    public let name: Name
    public let arguments: [Argument<IsVariable>]?
    public let directives: [Directive<IsVariable>]?
    public let selectionSet: SelectionSet?
    
    static var parser: some Parser<Substring.UTF8View, Field> {
        Parse {
            Optionally {
                Alias.aliasParser
                Whitespace()
            }
            Name.parser
            Optionally {
                Whitespace()
                Argument<IsVariable>.listParser
            }
            Optionally {
                Whitespace()
                Directive<IsVariable>.listParser
            }
            Optionally {
                Whitespace()
                SelectionSet.parser
            }
        }
        .map {
            Field(alias: $0.0, name: $0.1, arguments: $0.2, directives: $0.3, selectionSet: $0.4)
        }
    }
}

/// https://spec.graphql.org/October2021/#Argument
/// Arguments_Const:
///   ( Argument_?Const_list )
///
/// Argument_Const:
///   Name: Value_?Const
public struct Argument<ConstParam: ConstGrammar>: Hashable {
    public let name: Name
    public let value: Value<ConstParam>
    
    struct ArgumentParser: Parser {
        let parser = Parse {
            Whitespace()
            Name.parser
            Whitespace()
            ":".utf8
            Whitespace()
            Value<ConstParam>.parser
        }
        .map {
            Argument(name: $0.0, value: $0.1)
        }
        
        public func parse(_ input: inout Substring.UTF8View) throws -> Argument<ConstParam> {
            try self.parser.parse(&input)
        }
    }
    
    static var parser: ArgumentParser {
        ArgumentParser()
    }
    
    struct ArgumentsParser: Parser {
        let parser = Parse {
            "(".utf8
            Many {
                Whitespace()
                Argument<ConstParam>.parser
                Whitespace()
            } separator: {
                // TODO: Notable that `,` is not specified as a delimeter in the grammer
                // but is in all the examples. This is a mistake in the spec that needs to be fixed.
                ",".utf8
            } terminator: {
                ")".utf8
            }
        }
        
        public func parse(_ input: inout Substring.UTF8View) throws -> [Argument<ConstParam>] {
            try self.parser.parse(&input)
        }
    }
    
    static var listParser: ArgumentsParser {
        ArgumentsParser()
    }
}

/// https://spec.graphql.org/October2021/#Value
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
public indirect enum Value<ConstParam: ConstGrammar>: Hashable {
    public enum Kind: String {
        case variable = "Variable"
        case intValue = "IntValue"
        case floatValue = "FloatValue"
        case stringValue = "StringValue"
        case booleanValue = "BooleanValue"
        case nullValue = "NullValue"
        case enumValue = "EnumValue"
        case listValue = "ListValue"
        case objectValue = "ObjectValue"
    }
    
    case variable(Variable, _ phantom: ConstParam)
    case int(Int)
    case float(Double)
    case string(String)
    case bool(Bool)
    case null
    /// https://spec.graphql.org/October2021/#sec-Enum-Value
    /// EnumValue:
    ///   Name but not `true` or `false` or `null`
    case `enum`(Name)
    /// https://spec.graphql.org/October2021/#sec-List-Value
    ///  ListValue_Const:
    ///    []
    ///    [ Value_?Const_list ]
    case list([Value<ConstParam>])
    case object(ObjectValue<ConstParam>)
    
    struct ValueParser: Parser {
        // Ripped from https://github.com/pointfreeco/swift-parsing/blob/main/Sources/swift-parsing-benchmark/JSON.swift .
        let unicode = ParsePrint(.unicode) {
            Prefix(4) { $0.isHexDigit }
        }

        var value: AnyParser<Substring.UTF8View, Value<ConstParam>> {
            let escape = Parse {
                "\\".utf8

                OneOf {
                    "\"".utf8.map { "\"" }
                    "\\".utf8.map { "\\" }
                    "/".utf8.map { "/" }
                    "b".utf8.map { "\u{8}" }
                    "f".utf8.map { "\u{c}" }
                    "n".utf8.map { "\n" }
                    "r".utf8.map { "\r" }
                    "t".utf8.map { "\t" }
                    self.unicode
                }
            }
            
            // https://spec.graphql.org/October2021/#sec-String-Value
            // TODO: Actually match spec for parsing StringValue.
            let string = ParsePrint {
                "\"".utf8
                Many(into: "") { string, fragment in
                    string.append(contentsOf: fragment)
                } decumulator: { string in
                    string.map(String.init).reversed().makeIterator()
                } element: {
                    OneOf {
                        Prefix(1...) { $0.isUnescapedJSONStringByte }.map(.string)
                        escape
                    }
                } terminator: {
                    "\"".utf8
                }
            }
            
            let list = Parse {
                "[".utf8
                Many {
                    // Cycle.
                    Whitespace()
                    Lazy { self.value }
                    Whitespace()
                } separator: {
                    ",".utf8
                } terminator: {
                    "]".utf8
                }
            }
            
            // TODO: When we use ParsePrint these will need `.map(.case(...))`.
            let variableCase = Variable.parser.map { Value<ConstParam>.variable($0, IsVariable() as! ConstParam) }
            let constCases = OneOf {
                // Order here matters. TODO: Test against order!
                IntParser<Substring.UTF8View, Int>().map(.case(Value<ConstParam>.int))
                Double.parser().map(.case(Value<ConstParam>.float))
                Bool.parser().map(.case(Value<ConstParam>.bool))
                "null".utf8.map { Value<ConstParam>.null }
                Name.butNotTrueOrFalseOrNullParser.map(Value<ConstParam>.enum)
                list.map(Value<ConstParam>.list)
                ObjectValue.parser.map(Value<ConstParam>.object)
                string.map(.case(Value<ConstParam>.string))
            }
            
            return Parse {
                Whitespace()
                if ConstParam.self is IsVariable.Type {
                    OneOf {
                        variableCase
                        constCases
                    }
                }
                else {
                    // Assert optional due to bug above.
                    constCases
                }
                Whitespace()
              }
              .eraseToAnyParser()
        }
        
        public func parse(_ input: inout Substring.UTF8View) throws -> Value<ConstParam> {
            try self.value.parse(&input)
        }
    }
    
    static var parser: ValueParser {
        return ValueParser()
    }
    
    public var rawValue: String {
        switch self {
        case .variable(_, _):
            return Kind.variable.rawValue
        case .int(_):
            return Kind.intValue.rawValue
        case .float(_):
            return Kind.floatValue.rawValue
        case .string(_):
            return Kind.stringValue.rawValue
        case .bool(_):
            return Kind.booleanValue.rawValue
        case .null:
            return Kind.nullValue.rawValue
        case .enum(_):
            return Kind.enumValue.rawValue
        case .list(_):
            return Kind.listValue.rawValue
        case .object(_):
            return Kind.objectValue.rawValue
        }
    }
}

/// https://spec.graphql.org/October2021/#Variable
///  Variable:
///    $`Name`
public struct Variable: Hashable {
    public let name: Name
    
    struct VariableParser: Parser {
        let parser = Parse {
            "$".utf8
            Name.parser
        }
        .map {
            Variable(name: $0)
        }
        
        public func parse(_ input: inout Substring.UTF8View) throws -> Variable {
            try self.parser.parse(&input)
        }
    }
    
    static var parser: VariableParser {
        return VariableParser()
    }
}

/// https://spec.graphql.org/October2021/#sec-Input-Object-Values
/// ObjectValue_Const:
///   {}
///   { ObjectField_?Const_list }
public struct ObjectValue<ConstParam: ConstGrammar>: Hashable {
    public let fields: [ObjectField<ConstParam>]
    
    struct ObjectValueParser: Parser {
        let parser = Parse {
            "{".utf8
            Many {
                Whitespace()
                ObjectField<ConstParam>.parser
                Whitespace()
            } separator: {
                ",".utf8
            } terminator: {
                "}".utf8
            }
        }.map {
            ObjectValue(fields: $0)
        }
        
        public func parse(_ input: inout Substring.UTF8View) throws -> ObjectValue<ConstParam> {
            try self.parser.parse(&input)
        }
    }
    
    static var parser: ObjectValueParser {
        return ObjectValueParser()
    }
}

/// ObjectField_Const:
///   Name : Value_?Const
public struct ObjectField<ConstParam: ConstGrammar>: Hashable {
    public let name: Name
    public let value: Value<ConstParam>
    
    struct ObjectFieldParser: Parser {
        let parser = Parse {
            Whitespace()
            Name.parser
            Whitespace()
            ":".utf8
            Lazy { Value<ConstParam>.parser }
        }
        .map {
            ObjectField(name: $0.0, value: $0.1)
        }
        
        public func parse(_ input: inout Substring.UTF8View) throws -> ObjectField {
            try parser.parse(&input)
        }
    }
    
    static var parser: ObjectFieldParser {
        return ObjectFieldParser()
    }
}

/// https://spec.graphql.org/October2021/#VariableDefinitions
/// VariableDefinitions:
///   `(` VariableDefinition_list `)`
public struct VariableDefinitions: Hashable {
    public let variableDefinitions: [VariableDefinition]
    
    static var parser: some Parser<Substring.UTF8View, VariableDefinitions> {
        Parse {
            "(".utf8
            Many {
                Whitespace()
                VariableDefinition.parser
                Whitespace()
            } separator: {
                // TODO: Notable that `,` is not specified as a delimeter in the grammer
                // but is in all the examples. This is a mistake in the spec that needs to be fixed.
                ",".utf8
            }
            ")".utf8
        }
        .map { VariableDefinitions(variableDefinitions: $0) }
    }
}

/// https://spec.graphql.org/October2021/#VariableDefinition
/// VariableDefinition
///   Variable `:` Type DefaultValue_opt Directives_Const_opt
/// DefaultValue:
///   = Value_Const
public struct VariableDefinition: Hashable {
    public let variable: Variable
    public let type: `Type`
    public let defaultValue: Value<IsConst>?
    public let directives: [Directive<IsConst>]?
    
    static var parser: some Parser<Substring.UTF8View, VariableDefinition> {
        Parse {
            Variable.parser
            Whitespace()
            ":".utf8
            Whitespace()
            `Type`.parser
            Optionally {
                Whitespace()
                "=".utf8
                Whitespace()
                Value<IsConst>.parser
            }
            Optionally {
                Whitespace()
                Directive<IsConst>.listParser
            }
        }
        .map {
            VariableDefinition(variable: $0.0, type: $0.1, defaultValue: $0.2, directives: $0.3)
        }
    }
}

/// https://spec.graphql.org/October2021/#Type
/// Type:
///   NamedType
///   ListType
///   NonNullType
/// ListType:
///   `[` Type `]`
/// NonNullType:
///   NamedType `!`
///   ListType `!`
public indirect enum `Type`: Hashable {
    public enum Kind: String {
        case namedType = "NamedType"
        case listType = "ListType"
        case nonNullType = "NonNullType"
    }
    
    case namedType(NamedType)
    case listType(`Type`)
    case nonNullType(`Type`) // Cannot be another NonNullType.
    
    static var parser: some Parser<Substring.UTF8View, `Type`> {
        OneOf {
            Self.nonNullTypeParser
            Self.namedTypeParser
            Self.listTypeParser
        }
    }
    
    static var namedTypeParser: some Parser<Substring.UTF8View, `Type`> {
        NamedType.parser.map { Self.namedType($0) }
    }
    
    static var listTypeParser: some Parser<Substring.UTF8View, `Type`> {
        Parse {
            "[".utf8
            Whitespace()
            // Circular.
            Lazy { AnyParser(Self.parser) }
            Whitespace()
            "]".utf8
        }.map { Self.listType($0) }
    }
    
    static var nonNullTypeParser: some Parser<Substring.UTF8View, `Type`> {
        Parse {
            OneOf {
                Self.namedTypeParser
                Self.listTypeParser
            }
            Whitespace()
            "!".utf8
        }.map { Self.nonNullType($0) }
    }
}

/// https://spec.graphql.org/October2021/#NamedType
/// NamedType:
///   Name
public struct NamedType: Hashable {
    public let name: Name
    
    static var parser: some Parser<Substring.UTF8View, NamedType> {
        Parse {
            Name.parser
        }
        .map { NamedType(name: $0) }
    }
}

/// https://spec.graphql.org/October2021/#sec-Language.Directives
/// "Directive order is significant", "different semantic meaning"
/// Directives_Const:
///   Directive_?Const_list
///
/// Directive_Const:
///   @ Name Arguments_?Const-opt
public struct Directive<ConstParam: ConstGrammar>: Hashable {
    public let name: Name
    public let arguments: [Argument<ConstParam>]?
    
    static var prefixChar: String.UTF8View {
        "@".utf8
    }
    
    static var parser: some Parser<Substring.UTF8View, Directive> {
        Parse {
            self.prefixChar
            Name.parser
            Optionally {
                Whitespace()
                Argument<ConstParam>.listParser
            }
        }
        .map {
            Directive(name: $0.0, arguments: $0.1)
        }
    }
    
    static var listParser: some Parser<Substring.UTF8View, [Directive]> {
        Parse {
            // Since separator is whitespace, need to first peak to make sure
            // we're starting with a directive sigil (`@`) or we'll return
            // an empty list.
            Peek { Directive<IsConst>.prefixChar }
            Many {
                Directive<ConstParam>.parser
            } separator: {
                Whitespace()
            }
        }
    }
}
