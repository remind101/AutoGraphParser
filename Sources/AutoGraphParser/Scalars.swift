import Parsing

/// Shallow rip off of the libraries IntParser https://github.com/pointfreeco/swift-parsing/blob/edb72e8022cc6fc7064eedace4d37e0df18a08f5/Sources/Parsing/ParserPrinters/Int.swift#L77
/// but modified to work with GraphQL:
/// 1. GraphQL doesn't treat ascii as Ints.
/// 2. This bug causes issues https://github.com/pointfreeco/swift-parsing/issues/252 .
public struct IntParser<Input: Collection, Output: FixedWidthInteger>: Parser
where
    Input.SubSequence == Input,
    Input.Element == UTF8.CodeUnit
{
    /// The radix, or base, to use for converting text to an integer value.
    public let radix: Int
    
    @inlinable
    public init(radix: Int = 10) {
        precondition((2...36).contains(radix), "Radix not in range 2...36")
        self.radix = radix
    }
    
    @inlinable
    public func parse(_ input: inout Input) throws -> Output {
        @inline(__always)
        func digit(for n: UTF8.CodeUnit) -> Output? {
            let output: Output
            switch n {
            case .init(ascii: "0") ... .init(ascii: "9"):
                output = Output(n - .init(ascii: "0"))
            default:
                return nil
            }
            return output < self.radix ? output : nil
        }
        var length = 0
        var iterator = input.makeIterator()
        guard let first = iterator.next() else {
            throw AutoGraphParserError.expectedInput("integer at: \(input)")
        }
        let isPositive: Bool
        let parsedSign: Bool
        var overflow = false
        var output: Output
        switch (Output.isSigned, first) {
        case (true, .init(ascii: "-")):
            parsedSign = true
            isPositive = false
            output = 0
        case (true, .init(ascii: "+")):
            parsedSign = true
            isPositive = true
            output = 0
        case let (_, n):
            guard let n = digit(for: n) else {
                throw AutoGraphParserError.expectedInput("integer at: \(input)")
            }
            parsedSign = false
            isPositive = true
            output = n
        }
        let original = input
        input.removeFirst()
        length += 1
        let radix = Output(self.radix)
        while let next = iterator.next() {
            if let n = digit(for: next) {
                input.removeFirst()
                (output, overflow) = output.multipliedReportingOverflow(by: radix)
                func overflowError() -> AutoGraphParserError {
                    AutoGraphParserError.failed(
                        """
                        summary: "failed to process \"\(Output.self)\"",
                        label: "overflowed \(Output.max)",
                        from: \(original),
                        to: \(input)
                        """
                    )
                }
                guard !overflow else { throw overflowError() }
                (output, overflow) =
                    isPositive
                    ? output.addingReportingOverflow(n)
                    : output.subtractingReportingOverflow(n)
                guard !overflow else { throw overflowError() }
                length += 1
            }
            // Here's the special sauce I added. If there's a float indicator then throw so
            // a Double parser has a chance to treat it as such instead.
            else if next == UInt8(ascii: ".") {
                throw AutoGraphParserError.expectedInput("number at: \(input) is actually a Double")
            }
            else {
                break
            }
        }
        
        guard length > (parsedSign ? 1 : 0)
        else {
            throw AutoGraphParserError.expectedInput("integer at: \(input)")
        }
        return output
    }
}

extension IntParser: ParserPrinter where Input: PrependableCollection {
    @inlinable
    public func print(_ output: Output, into input: inout Input) {
        input.prepend(contentsOf: String(output, radix: self.radix).utf8)
    }
}
