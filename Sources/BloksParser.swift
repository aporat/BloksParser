import Foundation

/// Represents a parsed bloks value
public enum BloksValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case blok(name: String, args: [BloksValue], isLocal: Bool)
    
    /// Convenience accessor for blok name
    public var blokName: String? {
        if case .blok(let name, _, _) = self {
            return name
        }
        return nil
    }
    
    /// Convenience accessor for blok arguments
    public var blokArgs: [BloksValue]? {
        if case .blok(_, let args, _) = self {
            return args
        }
        return nil
    }
    
    /// Check if this is a local blok (prefixed with #)
    public var isLocalBlok: Bool {
        if case .blok(_, _, let isLocal) = self {
            return isLocal
        }
        return false
    }
}

extension BloksValue {
    
    /// Recursively searches the tree for the first `bk.action.map.Make` whose keys
    /// array contains the given key, and returns it as a `[String: BloksValue]`.
    /// Returns `nil` if no matching map is found.
    public func findMap(containingKey targetKey: String) -> [String: BloksValue]? {
        guard case .blok(let name, let args, _) = self else { return nil }
        
        // If this node is a map.Make, try to decode it and check for the key.
        if name == "bk.action.map.Make", args.count == 2,
           let keysArgs = args[0].blokArgs,
           let valuesArgs = args[1].blokArgs,
           keysArgs.count == valuesArgs.count {
            
            var dict: [String: BloksValue] = [:]
            for (k, v) in zip(keysArgs, valuesArgs) {
                if case .string(let keyStr) = k { dict[keyStr] = v }
            }
            if dict[targetKey] != nil { return dict }
        }
        
        // Otherwise recurse into all children.
        for arg in args {
            if let found = arg.findMap(containingKey: targetKey) { return found }
        }
        return nil
    }
}

// MARK: - CustomStringConvertible

extension BloksValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .null:
            return "null"
        case .bool(let value):
            return value ? "true" : "false"
        case .number(let value):
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", value)
            }
            return String(value)
        case .string(let value):
            return "\"\(value)\""
        case .blok(let name, let args, let isLocal):
            let prefix = isLocal ? "#" : ""
            if args.isEmpty {
                return "(\(prefix)\(name))"
            }
            let argsStr = args.map { $0.description }.joined(separator: ", ")
            return "(\(prefix)\(name), \(argsStr))"
        }
    }
}

// MARK: - JSON Conversion

extension BloksValue {
    /// Convert to a JSON-compatible structure (arrays and dictionaries)
    public func toJSON() -> Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .number(let value):
            return value
        case .string(let value):
            return value
        case .blok(let name, let args, _):
            var result: [Any] = [name]
            result.append(contentsOf: args.map { $0.toJSON() })
            return result
        }
    }
    
    /// Convert to JSON string
    public func toJSONString(prettyPrinted: Bool = false) throws -> String {
        let jsonObject = toJSON()
        let options: JSONSerialization.WritingOptions = prettyPrinted ? [.prettyPrinted, .sortedKeys] : []
        let data = try JSONSerialization.data(withJSONObject: jsonObject, options: options)
        guard let string = String(data: data, encoding: .utf8) else {
            throw BloksParserError.internalError("Failed to convert JSON data to string")
        }
        return string
    }
}

// MARK: - Parser Errors

public enum BloksParserError: Error, LocalizedError {
    case unexpectedEndOfInput
    case unexpectedCharacter(Character, position: Int)
    case invalidNumber(String, position: Int)
    case invalidEscapeSequence(String, position: Int)
    case unterminatedString(position: Int)
    case expectedCharacter(Character, got: Character?, position: Int)
    case invalidBlokName(position: Int)
    case internalError(String)
    
    public var errorDescription: String? {
        switch self {
        case .unexpectedEndOfInput:
            return "Unexpected end of input"
        case .unexpectedCharacter(let char, let pos):
            return "Unexpected character '\(char)' at position \(pos)"
        case .invalidNumber(let str, let pos):
            return "Invalid number '\(str)' at position \(pos)"
        case .invalidEscapeSequence(let seq, let pos):
            return "Invalid escape sequence '\(seq)' at position \(pos)"
        case .unterminatedString(let pos):
            return "Unterminated string starting at position \(pos)"
        case .expectedCharacter(let expected, let got, let pos):
            if let got = got {
                return "Expected '\(expected)' but got '\(got)' at position \(pos)"
            }
            return "Expected '\(expected)' but reached end of input at position \(pos)"
        case .invalidBlokName(let pos):
            return "Invalid blok name at position \(pos)"
        case .internalError(let msg):
            return "Internal error: \(msg)"
        }
    }
}

// MARK: - Bloks Processor

/// A processor function that transforms a blok into a custom value
public typealias BlokProcessor = @Sendable (_ name: String, _ args: [BloksValue], _ isLocal: Bool) -> BloksValue

/// Default processor that returns the blok as-is
public let defaultProcessor: BlokProcessor = { name, args, isLocal in
    .blok(name: name, args: args, isLocal: isLocal)
}

// MARK: - Basic Processors

/// Basic processors for common blok types
public struct BasicProcessors {
    
    /// Process array creation
    public static let arrayMake: BlokProcessor = { _, args, _ in
        // Return as a blok with "array" name for easy identification
        .blok(name: "array", args: args, isLocal: false)
    }
    
    /// Process integer constants
    public static let i32Const: BlokProcessor = { _, args, _ in
        if let first = args.first, case .number(let value) = first {
            return .number(value)
        }
        return args.first ?? .null
    }
    
    /// Process boolean constants
    public static let boolConst: BlokProcessor = { _, args, _ in
        if let first = args.first {
            switch first {
            case .bool(let value):
                return .bool(value)
            case .number(let value):
                return .bool(value != 0)
            case .string(let value):
                return .bool(!value.isEmpty && value != "false" && value != "0")
            default:
                return .bool(true)
            }
        }
        return .bool(false)
    }
    
    /// Process map creation
    public static let mapMake: BlokProcessor = { _, args, _ in
        // Maps expect two array args: keys and values
        // We'll represent this as a special blok
        .blok(name: "map", args: args, isLocal: false)
    }
    
    /// All basic processors
    public static var all: [String: BlokProcessor] {
        [
            "bk.action.array.Make": arrayMake,
            "bk.action.i32.Const": i32Const,
            "bk.action.i64.Const": i32Const,
            "bk.action.f64.Const": i32Const,
            "bk.action.bool.Const": boolConst,
            "bk.action.map.Make": mapMake,
        ]
    }
}

// MARK: - Bloks Parser

/// Parser for Instagram/Threads bloks payloads
public final class BloksParser: Sendable {
    private let processors: [String: BlokProcessor]
    private let fallbackProcessor: BlokProcessor

    /// Create a new parser with optional processors
    /// - Parameters:
    ///   - processors: Dictionary mapping blok names to processor functions
    ///   - fallbackProcessor: Processor to use for unregistered blok types
    public init(
        processors: [String: BlokProcessor] = [:],
        fallbackProcessor: @escaping BlokProcessor = defaultProcessor
    ) {
        self.processors = processors
        self.fallbackProcessor = fallbackProcessor
    }
    
    /// Create a parser with basic processors enabled
    public static func withBasicProcessors() -> BloksParser {
        BloksParser(processors: BasicProcessors.all)
    }
    
    // MARK: - Public API

    /// Parse a bloks payload string
    /// - Parameter payload: The bloks payload string to parse
    /// - Returns: The parsed BloksValue
    public func parse(_ payload: String) throws -> BloksValue {
        var state = ParseState(input: payload)

        state.skipWhitespace()
        let result = try parseValue(&state)
        state.skipWhitespace()

        // Ensure we've consumed all input
        if state.index < state.input.endIndex {
            throw BloksParserError.unexpectedCharacter(state.input[state.index], position: state.currentPosition)
        }

        return result
    }

    // MARK: - Parse State

    private struct ParseState {
        let input: String
        var index: String.Index

        init(input: String) {
            self.input = input
            self.index = input.startIndex
        }

        var currentPosition: Int {
            input.distance(from: input.startIndex, to: index)
        }

        var currentChar: Character? {
            index < input.endIndex ? input[index] : nil
        }

        mutating func advance() {
            if index < input.endIndex {
                index = input.index(after: index)
            }
        }

        mutating func skipWhitespace() {
            while let char = currentChar, char.isWhitespace {
                advance()
            }
        }

        mutating func expect(_ char: Character) throws {
            guard let current = currentChar else {
                throw BloksParserError.expectedCharacter(char, got: nil, position: currentPosition)
            }
            guard current == char else {
                throw BloksParserError.expectedCharacter(char, got: current, position: currentPosition)
            }
            advance()
        }
    }

    // MARK: - Private Parsing Methods

    private func parseValue(_ state: inout ParseState) throws -> BloksValue {
        state.skipWhitespace()

        guard let char = state.currentChar else {
            throw BloksParserError.unexpectedEndOfInput
        }

        switch char {
        case "(":
            return try parseBlok(&state)
        case "\"":
            return try parseString(&state)
        case "t", "f":
            return try parseBoolean(&state)
        case "n":
            return try parseNull(&state)
        case "-", "+", "0"..."9":
            return try parseNumber(&state)
        default:
            throw BloksParserError.unexpectedCharacter(char, position: state.currentPosition)
        }
    }

    private func parseBlok(_ state: inout ParseState) throws -> BloksValue {
        let startPos = state.currentPosition
        try state.expect("(")
        state.skipWhitespace()

        // Check for local blok (starts with #)
        let isLocal: Bool
        if state.currentChar == "#" {
            isLocal = true
            state.advance()
        } else {
            isLocal = false
        }

        // Parse the blok name
        let name = parseBlokName(&state, isLocal: isLocal)
        guard !name.isEmpty else {
            throw BloksParserError.invalidBlokName(position: startPos)
        }

        state.skipWhitespace()

        // Parse arguments
        var args: [BloksValue] = []

        while state.currentChar == "," {
            state.advance() // consume comma
            state.skipWhitespace()

            // Handle trailing comma
            if state.currentChar == ")" {
                break
            }

            let arg = try parseValue(&state)
            args.append(arg)
            state.skipWhitespace()
        }

        try state.expect(")")

        // Apply processor if available
        if let processor = processors[name] {
            return processor(name, args, isLocal)
        }

        // Check for fallback processor (using "@" key convention from original)
        if let fallback = processors["@"] {
            return fallback(name, args, isLocal)
        }

        return fallbackProcessor(name, args, isLocal)
    }

    private func parseBlokName(_ state: inout ParseState, isLocal: Bool) -> String {
        var name = ""

        if isLocal {
            // Local blok names can contain alphanumeric, hyphens, and colons
            while let char = state.currentChar {
                if char.isLetter || char.isNumber || char == "_" || char == "-" || char == ":" {
                    name.append(char)
                    state.advance()
                } else {
                    break
                }
            }
        } else {
            // Regular blok names are dot-separated identifiers
            while let char = state.currentChar {
                if char.isLetter || char.isNumber || char == "_" || char == "." {
                    name.append(char)
                    state.advance()
                } else {
                    break
                }
            }
        }

        return name
    }

    private func parseString(_ state: inout ParseState) throws -> BloksValue {
        let startPos = state.currentPosition
        try state.expect("\"")

        var result = ""

        while let char = state.currentChar {
            if char == "\"" {
                state.advance()
                return .string(result)
            }

            if char == "\\" {
                state.advance()
                guard let escaped = state.currentChar else {
                    throw BloksParserError.unterminatedString(position: startPos)
                }

                switch escaped {
                case "\"":
                    result.append("\"")
                case "\\":
                    result.append("\\")
                case "b":
                    result.append("\u{08}")
                case "f":
                    result.append("\u{0C}")
                case "r":
                    result.append("\r")
                case "t":
                    result.append("\t")
                case "n":
                    result.append("\n")
                case "u":
                    // Parse unicode escape \uXXXX
                    state.advance()
                    var hex = ""
                    for _ in 0..<4 {
                        guard let h = state.currentChar, h.isHexDigit else {
                            throw BloksParserError.invalidEscapeSequence("\\u\(hex)", position: state.currentPosition)
                        }
                        hex.append(h)
                        state.advance()
                    }
                    guard let codePoint = UInt32(hex, radix: 16),
                          let scalar = Unicode.Scalar(codePoint) else {
                        throw BloksParserError.invalidEscapeSequence("\\u\(hex)", position: state.currentPosition)
                    }
                    result.append(Character(scalar))
                    continue // Skip the advance() at the end since we already advanced
                default:
                    // For other escapes, just include the character
                    result.append(escaped)
                }
                state.advance()
            } else {
                result.append(char)
                state.advance()
            }
        }

        throw BloksParserError.unterminatedString(position: startPos)
    }

    private func parseNumber(_ state: inout ParseState) throws -> BloksValue {
        let startPos = state.currentPosition
        var numStr = ""

        // Optional sign
        if state.currentChar == "+" || state.currentChar == "-" {
            numStr.append(state.currentChar!)
            state.advance()
        }

        // Integer part
        while let char = state.currentChar, char.isNumber {
            numStr.append(char)
            state.advance()
        }

        // Decimal part
        if state.currentChar == "." {
            numStr.append(".")
            state.advance()
            while let char = state.currentChar, char.isNumber {
                numStr.append(char)
                state.advance()
            }
        }

        // Exponent part
        if state.currentChar == "e" || state.currentChar == "E" {
            numStr.append(state.currentChar!)
            state.advance()

            if state.currentChar == "+" || state.currentChar == "-" {
                numStr.append(state.currentChar!)
                state.advance()
            }

            while let char = state.currentChar, char.isNumber {
                numStr.append(char)
                state.advance()
            }
        }

        guard let value = Double(numStr) else {
            throw BloksParserError.invalidNumber(numStr, position: startPos)
        }

        return .number(value)
    }

    private func parseBoolean(_ state: inout ParseState) throws -> BloksValue {
        let startPos = state.currentPosition

        if state.input[state.index...].hasPrefix("true") {
            for _ in 0..<4 { state.advance() }
            return .bool(true)
        }

        if state.input[state.index...].hasPrefix("false") {
            for _ in 0..<5 { state.advance() }
            return .bool(false)
        }

        throw BloksParserError.unexpectedCharacter(state.currentChar ?? " ", position: startPos)
    }

    private func parseNull(_ state: inout ParseState) throws -> BloksValue {
        let startPos = state.currentPosition

        if state.input[state.index...].hasPrefix("null") {
            for _ in 0..<4 { state.advance() }
            return .null
        }

        throw BloksParserError.unexpectedCharacter(state.currentChar ?? " ", position: startPos)
    }
}

// MARK: - Convenience Functions

/// Create a bloks parser with custom processors
/// - Parameters:
///   - processors: Dictionary mapping blok names to processor functions
/// - Returns: A parser function that takes a payload string and returns the parsed value
public func createBloksParser(
    processors: [String: BlokProcessor] = [:]
) -> (String) throws -> BloksValue {
    let parser = BloksParser(processors: processors)
    return { payload in
        try parser.parse(payload)
    }
}

/// Create a bloks parser with basic processors enabled
public func createBloksParserWithBasics() -> (String) throws -> BloksValue {
    let parser = BloksParser.withBasicProcessors()
    return { payload in
        try parser.parse(payload)
    }
}

// MARK: - Character Extension

private extension Character {
    var isHexDigit: Bool {
        isNumber || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}
