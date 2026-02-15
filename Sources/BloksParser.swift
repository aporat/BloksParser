import Foundation

/// Represents a parsed bloks value
public enum BloksValue: Equatable, Sendable {
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
public final class BloksParser: @unchecked Sendable {
    private var input: String
    private var index: String.Index
    private var processors: [String: BlokProcessor]
    private var fallbackProcessor: BlokProcessor
    
    /// Create a new parser with optional processors
    /// - Parameters:
    ///   - processors: Dictionary mapping blok names to processor functions
    ///   - fallbackProcessor: Processor to use for unregistered blok types
    public init(
        processors: [String: BlokProcessor] = [:],
        fallbackProcessor: @escaping BlokProcessor = defaultProcessor
    ) {
        self.input = ""
        self.index = "".startIndex
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
        self.input = payload
        self.index = payload.startIndex
        
        skipWhitespace()
        let result = try parseValue()
        skipWhitespace()
        
        // Ensure we've consumed all input
        if index < input.endIndex {
            throw BloksParserError.unexpectedCharacter(input[index], position: currentPosition)
        }
        
        return result
    }
    
    // MARK: - Private Parsing Methods
    
    private var currentPosition: Int {
        input.distance(from: input.startIndex, to: index)
    }
    
    private var currentChar: Character? {
        index < input.endIndex ? input[index] : nil
    }
    
    private func advance() {
        if index < input.endIndex {
            index = input.index(after: index)
        }
    }
    
    private func peek(offset: Int = 0) -> Character? {
        var i = index
        for _ in 0..<offset {
            guard i < input.endIndex else { return nil }
            i = input.index(after: i)
        }
        return i < input.endIndex ? input[i] : nil
    }
    
    private func skipWhitespace() {
        while let char = currentChar, char.isWhitespace {
            advance()
        }
    }
    
    private func expect(_ char: Character) throws {
        guard let current = currentChar else {
            throw BloksParserError.expectedCharacter(char, got: nil, position: currentPosition)
        }
        guard current == char else {
            throw BloksParserError.expectedCharacter(char, got: current, position: currentPosition)
        }
        advance()
    }
    
    private func parseValue() throws -> BloksValue {
        skipWhitespace()
        
        guard let char = currentChar else {
            throw BloksParserError.unexpectedEndOfInput
        }
        
        switch char {
        case "(":
            return try parseBlok()
        case "\"":
            return try parseString()
        case "t", "f":
            return try parseBoolean()
        case "n":
            return try parseNull()
        case "-", "+", "0"..."9":
            return try parseNumber()
        default:
            throw BloksParserError.unexpectedCharacter(char, position: currentPosition)
        }
    }
    
    private func parseBlok() throws -> BloksValue {
        let startPos = currentPosition
        try expect("(")
        skipWhitespace()
        
        // Check for local blok (starts with #)
        let isLocal: Bool
        if currentChar == "#" {
            isLocal = true
            advance()
        } else {
            isLocal = false
        }
        
        // Parse the blok name
        let name = try parseBlokName(isLocal: isLocal)
        guard !name.isEmpty else {
            throw BloksParserError.invalidBlokName(position: startPos)
        }
        
        skipWhitespace()
        
        // Parse arguments
        var args: [BloksValue] = []
        
        while currentChar == "," {
            advance() // consume comma
            skipWhitespace()
            
            // Handle trailing comma
            if currentChar == ")" {
                break
            }
            
            let arg = try parseValue()
            args.append(arg)
            skipWhitespace()
        }
        
        try expect(")")
        
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
    
    private func parseBlokName(isLocal: Bool) throws -> String {
        var name = ""
        
        if isLocal {
            // Local blok names can contain alphanumeric, hyphens, and colons
            while let char = currentChar {
                if char.isLetter || char.isNumber || char == "_" || char == "-" || char == ":" {
                    name.append(char)
                    advance()
                } else {
                    break
                }
            }
        } else {
            // Regular blok names are dot-separated identifiers
            while let char = currentChar {
                if char.isLetter || char.isNumber || char == "_" || char == "." {
                    name.append(char)
                    advance()
                } else {
                    break
                }
            }
        }
        
        return name
    }
    
    private func parseString() throws -> BloksValue {
        let startPos = currentPosition
        try expect("\"")
        
        var result = ""
        
        while let char = currentChar {
            if char == "\"" {
                advance()
                return .string(result)
            }
            
            if char == "\\" {
                advance()
                guard let escaped = currentChar else {
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
                    advance()
                    var hex = ""
                    for _ in 0..<4 {
                        guard let h = currentChar, h.isHexDigit else {
                            throw BloksParserError.invalidEscapeSequence("\\u\(hex)", position: currentPosition)
                        }
                        hex.append(h)
                        advance()
                    }
                    guard let codePoint = UInt32(hex, radix: 16),
                          let scalar = Unicode.Scalar(codePoint) else {
                        throw BloksParserError.invalidEscapeSequence("\\u\(hex)", position: currentPosition)
                    }
                    result.append(Character(scalar))
                    continue // Skip the advance() at the end since we already advanced
                default:
                    // For other escapes, just include the character
                    result.append(escaped)
                }
                advance()
            } else {
                result.append(char)
                advance()
            }
        }
        
        throw BloksParserError.unterminatedString(position: startPos)
    }
    
    private func parseNumber() throws -> BloksValue {
        let startPos = currentPosition
        var numStr = ""
        
        // Optional sign
        if currentChar == "+" || currentChar == "-" {
            numStr.append(currentChar!)
            advance()
        }
        
        // Integer part
        while let char = currentChar, char.isNumber {
            numStr.append(char)
            advance()
        }
        
        // Decimal part
        if currentChar == "." {
            numStr.append(".")
            advance()
            while let char = currentChar, char.isNumber {
                numStr.append(char)
                advance()
            }
        }
        
        // Exponent part
        if currentChar == "e" || currentChar == "E" {
            numStr.append(currentChar!)
            advance()
            
            if currentChar == "+" || currentChar == "-" {
                numStr.append(currentChar!)
                advance()
            }
            
            while let char = currentChar, char.isNumber {
                numStr.append(char)
                advance()
            }
        }
        
        guard let value = Double(numStr) else {
            throw BloksParserError.invalidNumber(numStr, position: startPos)
        }
        
        return .number(value)
    }
    
    private func parseBoolean() throws -> BloksValue {
        let startPos = currentPosition
        
        if input[index...].hasPrefix("true") {
            for _ in 0..<4 { advance() }
            return .bool(true)
        }
        
        if input[index...].hasPrefix("false") {
            for _ in 0..<5 { advance() }
            return .bool(false)
        }
        
        throw BloksParserError.unexpectedCharacter(currentChar ?? " ", position: startPos)
    }
    
    private func parseNull() throws -> BloksValue {
        let startPos = currentPosition
        
        if input[index...].hasPrefix("null") {
            for _ in 0..<4 { advance() }
            return .null
        }
        
        throw BloksParserError.unexpectedCharacter(currentChar ?? " ", position: startPos)
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
