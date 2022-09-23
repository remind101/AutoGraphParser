import Parsing

// TODO: Eventually re-order to match spec's documentation order.
// TODO: Make everything a ParserPrinter.

/// https://spec.graphql.org/October2021/#Alias
/// Name
///
/// Typealias to `Name` since it reduces to `Name`, if we want clearer type differentiation
/// in the future may prefer `protocol Alias` and `Name: Alias`.
typealias Alias = Name

/// https://spec.graphql.org/October2021/#Name
public struct Name: Hashable {
    public var value: String
    
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
                Prefix(0...) { $0.isNameCharacter }.map(.string)
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
        return NameParser()
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

/// https://spec.graphql.org/October2021/#sec-Language.Fields
/// Field
/// Alias-opt Name Arguments-opt Directives-opt SelectionSet-opt
struct Field {
    public let alias: Alias?
    public let name: Name
    public let arguments: [Argument<IsVariable>]?
    public let directives: [Directive<IsVariable>]?
//    public let selectionSet: SelectionSet?

//    public static func == (lhs: Field, rhs: Field) -> Bool {
//        return lhs.alias?.value == rhs.alias?.value &&
//            lhs.name == rhs.name &&
//            lhs.arguments == rhs.arguments &&
//            lhs.directives == rhs.directives &&
//            lhs.selectionSet == rhs.selectionSet
//    }

    struct FieldParser: Parser {
        let parser = Parse {
            // TODO: May need oneof here between with alias and without?
            Optionally {
                Whitespace()
                Alias.parser
            }
            Whitespace()
            Name.parser
            Optionally {
                Argument<IsVariable>.listParser
            }
            Whitespace()
            Optionally {
                Directive<IsVariable>.listParser
            }
        }
        .map {
            Field(alias: $0.0, name: $0.1, arguments: $0.2, directives: $0.3)
        }
        
        public func parse(_ input: inout Substring.UTF8View) throws -> Field {
            try self.parser.parse(&input)
        }
    }
}

/// https://spec.graphql.org/October2021/#Argument
///  Arguments_Const:
/// ( Argument_?Const_list )
///
/// Argument_Const:
/// Name: Value_?Const
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
            Whitespace()
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
/// [if not Const] Variable
/// IntValue
/// FloatValue
/// StringValue
/// BooleanValue
/// NullValue
/// EnumValue
/// ListValue_?Const
/// ObjectValue_?Const
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
    /// Name but not true or false or null
    /// TODO: Integrate rule into parser and test.
    case `enum`(Name)
    /// https://spec.graphql.org/October2021/#sec-List-Value
    ///  ListValue_Const:
    ///  []
    ///  [ Value_?Const_list ]
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
                Name.parser.map(Value<ConstParam>.enum)
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
///  $`Name`
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
///  ObjectValue_Const:
///  {}
///  { ObjectField_?Const_list }
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
/// Name : Value_?Const
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

/// https://spec.graphql.org/October2021/#sec-Language.Directives
/// "Directive order is significant", "different semantic meaning"
/// Directives_Const:
/// Directive_?Const_list
///
/// Directive_Const:
/// @ Name Arguments_?Const-opt
public struct Directive<ConstParam: ConstGrammar>: Hashable {
    public let name: Name
    public let arguments: [Argument<ConstParam>]?
    
    struct DirectiveParser: Parser {
        let parser = Parse {
            "@".utf8
            Name.parser
            Optionally {
                Argument<ConstParam>.listParser
            }
        }
        .map {
            Directive(name: $0.0, arguments: $0.1)
        }
        
        public func parse(_ input: inout Substring.UTF8View) throws -> Directive<ConstParam> {
            try self.parser.parse(&input)
        }
    }
    
    static var parser: DirectiveParser {
        return DirectiveParser()
    }
    
    struct DirectivesParser: Parser {
        let parser = Parse {
            Many {
                Directive<ConstParam>.parser
            } separator: {
                Whitespace()
            }
        }
        
        public func parse(_ input: inout Substring.UTF8View) throws -> [Directive<ConstParam>] {
            try self.parser.parse(&input)
        }
    }
    
    static var listParser: DirectivesParser {
        DirectivesParser()
    }
}
