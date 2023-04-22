import Foundation

public enum IntrospectionError: LocalizedError {
    case general(message: String)
    case typeConstructionError(kind: __TypeKind)
    
    public var errorDescription: String {
        switch self {
        case .general(message: let message):
            return message
        case .typeConstructionError(let kind):
            return "Kind of __Type is not \(kind)"
        }
    }
}

/**
 * Schema Introspection Schema
 * `https://spec.graphql.org/October2021/#sec-Schema-Introspection.Schema-Introspection-Schema`
 */

/**
`https://spec.graphql.org/October2021/#sec-The-__Schema-Type`

type __Schema {
  description: String
  types: [__Type!]!
  queryType: __Type!
  mutationType: __Type
  subscriptionType: __Type
  directives: [__Directive!]!
}
*/
public struct __Schema: Codable {
    /// The spec states that `queryType`, `mutationType`, `subscriptionType`
    /// are of type `__Type[!]`, which has requied field `kind: __TypeKind!`
    /// yet in practice `.json` introspection schemas do not seem to include
    /// the `kind` fields for those types, so we use this type instead.
    public struct RootType: Codable {
        public let name: String
    }
    public let description: String?
    public let types: [__Type]
    public let queryType: RootType
    public let mutationType: RootType?
    public let subscriptionType: RootType?
    public let directives: [__Directive]
}

/**
 enum __TypeKind {
   SCALAR
   OBJECT
   INTERFACE
   UNION
   ENUM
   INPUT_OBJECT
   LIST
   NON_NULL
 }
 */
public enum __TypeKind: String, Hashable, Codable {
    case scalar = "SCALAR"
    case object = "OBJECT"
    case interface = "INTERFACE"
    case union = "UNION"
    case `enum` = "ENUM"
    case inputObject = "INPUT_OBJECT"
    case list = "LIST"
    case nonNull = "NON_NULL"
}

// TODO: If Swift adds GADTs we could easily parameterize which case to use
// in `OfType` based on generic information.

/// Fills the `ofType` parameters in `__Type`.
/// Represents only the subset of information needed for that field.
/// I.e. though it's definition is `ofType: __Type`, this structure is all the
/// data that is used in practice.
public indirect enum OfType: Hashable, Codable {
    public struct __TypeReference: Hashable, Codable {
        enum CodingKeys: CodingKey {
            case kind, name, description
        }
        public let kind: __TypeKind
        public let name: String?           // Name of the type, nil for NON_NULL and LIST.
        public let description: String?
        
        init(kind: __TypeKind, name: String? = nil, description: String? = nil) {
            self.kind = kind; self.name = name; self.description = description
        }
    }
    
    case scalar(__TypeReference)                    // ScalarType.
    case object(__TypeReference)                    // ObjectType.
    case interface(__TypeReference)                 // InterfaceType.
    case union(__TypeReference)                     // UnionType.
    case `enum`(__TypeReference)                    // EnumType.
    case inputObject(__TypeReference)               // InputObjectType.
    case list(__TypeReference, ofType: OfType)      // ListType.
    case nonNull(__TypeReference, ofType: OfType)   // NonNullType. Will never reference another NonNullType.
    
    public init(from decoder: Decoder) throws {
        struct SubOfType: Codable {
            let ofType: OfType
        }
        let typeRef = try decoder.singleValueContainer().decode(__TypeReference.self)
        switch typeRef.kind {
        case .scalar: self = .scalar(typeRef)
        case .object: self = .object(typeRef)
        case .interface: self = .interface(typeRef)
        case .union: self = .union(typeRef)
        case .enum: self = .enum(typeRef)
        case .inputObject: self = .inputObject(typeRef)
        case .list:
            let subOfType = try decoder.singleValueContainer().decode(SubOfType.self)
            self = .list(typeRef, ofType: subOfType.ofType)
        case .nonNull:
            let subOfType = try decoder.singleValueContainer().decode(SubOfType.self)
            self = .nonNull(typeRef, ofType: subOfType.ofType)
        }
    }
}

/// `__Type` in Schema introspection schema.
public struct __Type: Hashable, Codable {
    public let kind: __TypeKind
    public let name: String?       // Name of the type, nil for NON_NULL and LIST.
    public let description: String?
    
    /// # must be non-null for OBJECT and INTERFACE, otherwise null.
    /// fields(includeDeprecated: Boolean = false): [__Field!]
    public let fields: [__Field]?
    
    /// # must be non-null for OBJECT and INTERFACE, otherwise null.
    /// interfaces: [__Type!]
    public let interfaces: [OfType]?
    
    /// # must be non-null for INTERFACE and UNION, otherwise null.
    /// possibleTypes: [__Type!]
    public let possibleTypes: [OfType]?
    
    /// # must be non-null for ENUM, otherwise null.
    /// enumValues(includeDeprecated: Boolean = false): [__EnumValue!]
    public let enumValues: [__EnumValue]?
    
    /// # must be non-null for INPUT_OBJECT, otherwise null.
    /// inputFields: [__InputValue!]
    public let inputFields: [__InputValue]?
    
    /// # must be non-null for NON_NULL and LIST, otherwise null.
    /// ofType: __Type
    public let ofType: OfType?
    
    /// # may be non-null for custom SCALAR, otherwise null.
    public let specifiedByURL: String?
    
    public init(
        kind: __TypeKind,
        name: String? = nil,
        description: String? = nil,
        fields: [__Field]? = nil,
        interfaces: [OfType]? = nil,
        possibleTypes: [OfType]? = nil,
        enumValues: [__EnumValue]? = nil,
        inputFields: [__InputValue]? = nil,
        ofType: OfType? = nil,
        specifiedByURL: String? = nil) {
        self.kind = kind
        self.name = name
        self.description = description
        self.fields = fields
        self.interfaces = interfaces
        self.possibleTypes = possibleTypes
        self.enumValues = enumValues
        self.inputFields = inputFields
        self.ofType = ofType
        self.specifiedByURL = specifiedByURL
    }
}

/// `https://spec.graphql.org/October2021/#sec-The-__Field-Type`
///
/// - `name` must return a String
/// - `description` may return a String or null
/// - `args` returns a List of __InputValue representing the arguments this field accepts.
/// - `type` must return a __Type that represents the type of value returned by this field.
/// - `isDeprecated` returns true if this field should no longer be used, otherwise false.
/// - `deprecationReason` optionally provides a reason why this field is deprecated.
public struct __Field: Hashable, Codable {
    public let name: String
    public let description: String?
    public let args: [__InputValue]
    public let type: OfType
    public let isDeprecated: Bool
    public let deprecationReason: String?
}

/// `https://spec.graphql.org/October2021/#sec-The-__InputValue-Type`
///
/// - `name` must return a String
/// - `description` may return a String or null
/// - `type` must return a __Type that represents the type this input value expects.
/// - `defaultValue` may return a String encoding (using the GraphQL language) of the default value used by this input value in the condition a value is not provided at runtime. If this input value has no default value, returns null.
public struct __InputValue: Hashable, Codable {
    public let name: String
    public let description: String?
    public let type: OfType
    
    /// "`defaultValue` may return a String encoding (using the GraphQL language) of the default value used by this input
    /// value in the condition a value is not provided at runtime. If this input value has no default value, returns null."
    /// I.e. This is a String that matches the type in GQL.
    ///
    /// E.g. if it's the Enum case METRIC, the string value is `"METRIC"`.
    ///
    /// E.g. if it's the String value "No longer supported", the string value `"\"No longer supported\""`.
    ///
    /// It is not strictly JSON.
    public let defaultValue: String?
}

/// `https://spec.graphql.org/October2021/#sec-The-__EnumValue-Type`
///
/// - `name` must return a String
/// - `description` may return a String or null
/// - `isDeprecated` returns `true` if this enum value should no longer be used, otherwise `false`.
/// - `deprecationReason` optionally provides a reason why this enum value is deprecated.
public struct __EnumValue: Hashable, Codable {
    public let name: String
    public let description: String?
    public let isDeprecated: Bool
    public let deprecationReason: String?
}

public enum __DirectiveLocation: String, Hashable, Codable {
    case query = "QUERY"                            // 'Location adjacent to a query operation.'
    case mutation = "MUTATION"                      // 'Location adjacent to a mutation operation.'
    case subscription = "SUBSCRIPTION"              // 'Location adjacent to a subscription operation.'
    case field = "FIELD"                            // 'Location adjacent to a field.'
    case fragmentDefinition = "FRAGMENT_DEFINITION" // 'Location adjacent to a fragment definition.'
    case fragmentSpread = "FRAGMENT_SPREAD"         // 'Location adjacent to a fragment spread.'
    case inlineFragment = "INLINE_FRAGMENT"         // 'Location adjacent to an inline fragment.'
    case variableDefinition = "VARIABLE_DEFINITION" // 'Location adjacent to an variable definition.'
    case schema = "SCHEMA"                          // 'Location adjacent to a schema definition.'
    case scalar = "SCALAR"                          // 'Location adjacent to a scalar definition.'
    case object = "OBJECT"                          // 'Location adjacent to an object type definition.'
    case fieldDefinition = "FIELD_DEFINITION"       // 'Location adjacent to a field definition.'
    case argumentDefinition = "ARGUMENT_DEFINITION" // 'Location adjacent to an argument definition.'
    case interface = "INTERFACE"                    // 'Location adjacent to an interface definition.'
    case union = "UNION"                            // 'Location adjacent to a union definition.'
    case `enum` = "ENUM"                            // 'Location adjacent to an enum definition.'
    case enumValue = "ENUM_VALUE"                   // 'Location adjacent to an enum value definition.'
    case inputObject = "INPUT_OBJECT"               // 'Location adjacent to an input object type definition.'
    case inputFieldDefinition = "INPUT_FIELD_DEFINITION"    // 'Location adjacent to an input object field definition.'
}

/// `https://spec.graphql.org/October2021/#sec-The-__Directive-Type`
///
/// - `name` must return a `String`
/// - `description` may return a `String` or null
/// - `locations` returns a List of `__DirectiveLocation` representing the valid locations this directive may be placed.
/// - `args` returns a List of `__InputValue` representing the arguments this directive accepts.
/// - `isRepeatable` must return a `Boolean` that indicates if the directive may be used repeatedly at a single location.
public struct __Directive: Hashable, Codable {
    public let name: String
    public let description: String?
    public let locations: [__DirectiveLocation]
    public let args: [__InputValue]
    // TODO: Include a test with isRepeatable.
    /// The spec states that this field must exist, but in practice it may
    /// not.
    public let isRepeatable: Bool?
}

// MARK: - Types which refine `__Type`.

public protocol __TypeConstructable {
    init(type: __Type) throws
}

/// `https://spec.graphql.org/October2021/#sec-The-__Type-Type.Scalar`
///
/// Also represents Custom scalars which may provide `specifiedByURL` as a scalar specification `URL`.
///
/// NOTE: Explicitly NOT `Hashable`, use `name` for hashing.
///
/// - `kind` must return `__TypeKind.SCALAR`.
/// - `name` must return a `String`.
/// - `description` may return a `String` or `null`.
/// - `specifiedByURL` may return a `String` (in the form of a URL) for custom scalars, otherwise must be `null`.
/// - All other fields must return `null`.
public struct ScalarType: __TypeConstructable {
    public enum NameType: RawRepresentable, Hashable {
        public typealias RawValue = String
        
        public enum BuiltIn: String {
            case int = "Int"
            case float = "Float"
            case string = "String"
            case bool = "Boolean"
            case id = "ID"
        }
        
        case int
        case float
        case string
        case bool
        case id
        case custom(String)
        
        public init?(rawValue: String) {
            guard let builtIn = BuiltIn(rawValue: rawValue) else {
                self = .custom(rawValue)
                return
            }
            switch builtIn {
            case .int: self = .int
            case .float: self = .float
            case .string: self = .string
            case .bool: self = .bool
            case .id: self = .id
            }
        }
        
        public var rawValue: String {
            switch self {
            case .int: return BuiltIn.int.rawValue
            case .float: return BuiltIn.float.rawValue
            case .string: return BuiltIn.string.rawValue
            case .bool: return BuiltIn.bool.rawValue
            case .id: return BuiltIn.id.rawValue
            case .custom(let custom): return custom
            }
        }
    }
    
    public let kind = __TypeKind.scalar
    public let name: NameType
    public let description: String?
    public let specifiedByURL: String?
    
    public init(name: NameType, description: String?, specifiedByURL: String?) {
        self.name = name; self.description = description; self.specifiedByURL = specifiedByURL
    }
    
    public init(type: __Type) throws {
        guard type.kind == .scalar else {
            throw IntrospectionError.typeConstructionError(kind: .scalar)
        }
        
        guard let name = type.name, let typeName = NameType(rawValue: name) else {
            assert(false, "Should be impossible to reach here.")
            let name = type.name ?? "nil"
            throw IntrospectionError.general(message: "`ScalarType.name` can only be constructed with `NameType` types - attempted to construct with \(name)")
        }
        
        self.name = typeName
        self.description = type.description
        self.specifiedByURL = type.specifiedByURL
    }
}

/// `https://spec.graphql.org/October2021/#sec-The-__Type-Type.Object`
///
/// - `kind` must return `__TypeKind.OBJECT`.
/// - `name` must return a `String`.
/// - `description` may return a `String` or `null`.
/// - `fields` must return the set of fields that can be selected for this type.
///   - Accepts the argument `includeDeprecated` which defaults to `false`. If `true`, deprecated fields are also returned.
/// - `interfaces` must return the set of interfaces that an object implements (if none, interfaces must return the empty set).
/// - All other fields must return `null`.
public struct ObjectType: __TypeConstructable {
    public let kind = __TypeKind.object
    public let name: String
    public let description: String?
    public let fields: [__Field]
    public let interfaces: [OfType]
    
    public init(name: String, description: String?, fields: [__Field], interfaces: [OfType]) {
        self.name = name; self.description = description; self.fields = fields; self.interfaces = interfaces
    }
    
    public init(type: __Type) throws {
        guard type.kind == .object else {
            throw IntrospectionError.typeConstructionError(kind: .object)
        }
        
        self.name = type.name!; self.description = type.description; self.fields = type.fields!; self.interfaces = type.interfaces!
    }
}

/// `https://spec.graphql.org/October2021/#sec-The-__Type-Type.Union`
///
/// - `kind` must return `__TypeKind.UNION`.
/// - `name` must return a `String`.
/// - `description` may return a `String` or `null`.
/// - `possibleTypes` returns the list of types that can be represented within this union. They must be object types.
/// - All other fields must return `null`.
public struct UnionType: __TypeConstructable {
    public let kind = __TypeKind.union
    public let name: String
    public let description: String?
    public let possibleTypes: [OfType] // Must be an ObjectType.
    
    public init(name: String, description: String?, possibleTypes: [OfType]) {
        self.name = name; self.description = description; self.possibleTypes = possibleTypes
    }
    
    public init(type: __Type) throws {
        guard type.kind == .union else {
            throw IntrospectionError.typeConstructionError(kind: .union)
        }
        
        self.name = type.name!; self.description = type.description; self.possibleTypes = type.possibleTypes ?? []
    }
}

/// https://spec.graphql.org/October2021/#sec-The-__Type-Type.Interface
///
/// - `kind` must return `__TypeKind.INTERFACE`.
/// - `name` must return a `String`.
/// - `description` may return a `String` or `null`.
/// - `fields` must return the set of fields required by this interface.
///   - Accepts the argument `includeDeprecated` which defaults to `false`. If `true`, deprecated fields are also returned.
/// - `interfaces` must return the set of interfaces that an object implements (if none, interfaces must return the empty set).
/// - `possibleTypes` returns the list of types that implement this interface. They must be object types.
/// - `All other fields must return `null`.
public struct InterfaceType: __TypeConstructable {
    public let kind = __TypeKind.interface
    public let name: String
    public let description: String?
    public let interfaces: [OfType]
    public let fields: [__Field]
    public let possibleTypes: [OfType] // Must be an ObjectType.
    
    public init(name: String, description: String?, interfaces: [OfType], fields: [__Field], possibleTypes: [OfType]) {
        self.name = name; self.description = description; self.interfaces = interfaces; self.fields = fields; self.possibleTypes = possibleTypes
    }
    
    public init(type: __Type) throws {
        guard type.kind == .interface else {
            throw IntrospectionError.typeConstructionError(kind: .interface)
        }
        
        self.name = type.name!; self.description = type.description; self.interfaces = type.interfaces ?? []; self.fields = type.fields!; self.possibleTypes = type.possibleTypes ?? []
    }
}

/// `https://spec.graphql.org/October2021/#sec-The-__Type-Type.Enum`
///
/// - `kind` must return `__TypeKind.ENUM`.
/// - `name` must return a `String`.
/// - `description` may return a `String` or `null`.
/// - `enumValues` must return the set of enum values as a list of `__EnumValue`. There must be at least one and they must have unique names.
///   - Accepts the argument `includeDeprecated` which defaults to `false`. If `true`, deprecated enum values are also returned.
/// - All other fields must return `null`.
public struct EnumType: __TypeConstructable {
    public let kind = __TypeKind.enum
    public let name: String
    public let description: String?
    public let enumValues: [__EnumValue]
    
    public init(name: String, description: String?, enumValues: [__EnumValue]) {
        self.name = name; self.description = description; self.enumValues = enumValues
    }
    
    public init(type: __Type) throws {
        guard type.kind == .enum else {
            throw IntrospectionError.typeConstructionError(kind: .enum)
        }
        
        self.name = type.name!; self.description = type.description; self.enumValues = type.enumValues!
    }
}

/// `https://spec.graphql.org/October2021/#sec-The-__Type-Type.Input-Object`
///
/// - `kind` must return `__TypeKind.INPUT_OBJECT`.
/// - `name` must return a `String`.
/// - `description` may return a `String` or `null`.
/// - `inputFields` must return the set of input fields as a list of `__InputValue`.
/// - `All other fields must return null.
public struct InputObjectType: __TypeConstructable {
    public let kind = __TypeKind.inputObject
    public let name: String
    public let description: String?
    public let inputFields: [__InputValue]
    
    public init(name: String, description: String?, inputFields: [__InputValue]) {
        self.name = name; self.description = description; self.inputFields = inputFields
    }
    
    public init(type: __Type) throws {
        guard type.kind == .inputObject else {
            throw IntrospectionError.typeConstructionError(kind: .inputObject)
        }
        
        self.name = type.name!; self.description = type.description; self.inputFields = type.inputFields!
    }
}

/// `https://spec.graphql.org/October2021/#sec-The-__Type-Type.List`
///
/// - `kind` must return `__TypeKind.LIST`.
/// - `ofType` must return a type of any kind.
/// - All other fields must return `null`.
public struct ListType: __TypeConstructable {
    public let kind = __TypeKind.list
    public let ofType: OfType
    
    public init(ofType: OfType) {
        self.ofType = ofType
    }
    
    public init(type: __Type) throws {
        guard type.kind == .list else {
            throw IntrospectionError.typeConstructionError(kind: .list)
        }
        
        self.ofType = type.ofType!
    }
}

/// https://spec.graphql.org/October2021/#sec-The-__Type-Type.Non-Null
///
/// - `kind` must return `__TypeKind.NON_NULL`.
/// - `ofType` must return a type of any kind except Non-Null.
/// - All other fields must return `null`.
public struct NonNullType: __TypeConstructable {
    public let kind = __TypeKind.nonNull
    public let ofType: OfType
    
    public init(ofType: OfType) {
        self.ofType = ofType
    }
    
    public init(type: __Type) throws {
        guard type.kind == .nonNull else {
            throw IntrospectionError.typeConstructionError(kind: .nonNull)
        }
        
        self.ofType = type.ofType!
    }
}
