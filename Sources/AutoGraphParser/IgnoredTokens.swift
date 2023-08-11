import Foundation
import Parsing

/// A parser that consumes ignored tokens from the beginning of input.
///
/// https://spec.graphql.org/October2021/#sec-Language.Source-Text.Ignored-Tokens
/// Ignored::
///   UnicodeBOM
///   WhiteSpace
///   LineTerminator
///   Comment
///   Comma
/// Comment::
///   # CommentChar_list_opt [lookahead notinset CommentChar]
/// CommentChar::
///   SourceCharacter _but not_ LineTerminator
public enum IgnoredTokensStatic {
    public static let whitespaceAndNewlines = CharacterSet.whitespacesAndNewlines
    public static let newlines = CharacterSet.newlines
    public static let comma: UInt8 = 44
    public static let hashSign: UInt8 = 35
}

public struct IgnoredTokens<Input: Collection>: Parser
where
    Input.SubSequence == Input,
    Input.Element == UTF8.CodeUnit
{
    @inlinable
    public init() { }
    
    @inlinable
    public func parse(_ input: inout Input) throws {
        // Regex may be nicer.
        var iterator = input.makeIterator()
        var continueUntilNewline = false
    parseloop: while let next = iterator.next() {
            if continueUntilNewline {
                // Check if comment is terminated.
                if IgnoredTokensStatic.newlines.contains(Unicode.Scalar(next)) {
                    continueUntilNewline = false
                }
                // Eat newlines too because they're whitespace.
                input.removeFirst()
                continue
            }
            if IgnoredTokensStatic.whitespaceAndNewlines.contains(Unicode.Scalar(next)) {
                input.removeFirst()
                continue
            }
            switch next {
            case IgnoredTokensStatic.comma: input.removeFirst()
            case IgnoredTokensStatic.hashSign:
                input.removeFirst()
                continueUntilNewline = true
            default:
                break parseloop
            }
        }
    }
}
