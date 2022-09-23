import Parsing

// TODO: Better error conventions. Would be best if they could be used by the Parser lib as well.
public enum AutoGraphParserError: Error {
    case expectedInput(String)
    case failed(String)
}

public struct AutoGraphParser {
    public private(set) var text = "Hello, World!"

    public init() {
    }
}
