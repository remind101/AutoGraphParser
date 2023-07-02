import Foundation
import Parsing

// TODO: Better error conventions. Would be best if they could be used by the Parser lib as well.
public enum AutoGraphParserError: Error {
    case expectedInput(String)
    case failed(String)
}

extension __Schema {
    static func loadFrom(jsonSchemaPath: String) throws -> __Schema {
        struct Payload: Codable {
            struct Data: Codable {
                let __schema: __Schema
            }
            let data: Data
        }
        let url = URL(fileURLWithPath: jsonSchemaPath)
        
        // Xcode runs sometimes get "interrupted system call" failures on the first open of a file.
        // https://stackoverflow.com/questions/61426336/interrupted-system-call-when-reading-test-data-in-xctestcase
        let schemaData = try (try? Data(contentsOf: url)) ?? (Data(contentsOf: url))
        return try JSONDecoder().decode(Payload.self, from: schemaData).data.__schema
    }
}
