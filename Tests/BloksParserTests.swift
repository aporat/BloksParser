import Foundation
import Testing
@testable import BloksParser

struct BloksParserTests {
    
    // MARK: - Basic Parsing Tests
    
    @Test func parseSimpleBlok() throws {
        let parser = BloksParser()
        let result = try parser.parse("(bk.action.test)")
        
        #expect(result.blokName == "bk.action.test")
        #expect(result.blokArgs?.count == 0)
        #expect(result.isLocalBlok == false)
    }
    
    @Test func parseBlokWithStringArg() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(bk.action.test, "hello")"#)
        
        #expect(result.blokName == "bk.action.test")
        #expect(result.blokArgs?.count == 1)
        
        guard case .string(let value) = result.blokArgs?[0] else {
            Issue.record("Expected string argument")
            return
        }
        #expect(value == "hello")
    }
    
    @Test func parseBlokWithMultipleArgs() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(bk.action.test, "hello", 42, true, null)"#)
        
        #expect(result.blokName == "bk.action.test")
        #expect(result.blokArgs?.count == 4)
        
        guard let args = result.blokArgs else {
            Issue.record("Expected args")
            return
        }
        
        guard case .string(let strValue) = args[0] else {
            Issue.record("Expected string")
            return
        }
        #expect(strValue == "hello")
        
        guard case .number(let numValue) = args[1] else {
            Issue.record("Expected number")
            return
        }
        #expect(numValue == 42.0)
        
        guard case .bool(let boolValue) = args[2] else {
            Issue.record("Expected bool")
            return
        }
        #expect(boolValue == true)
        
        #expect(args[3] == .null)
    }
    
    @Test func parseNestedBloks() throws {
        let parser = BloksParser()
        let payload = """
        (bk.action.map.Make,
            (bk.action.array.Make, "login_type", "login_source"),
            (bk.action.array.Make, "Password", "Login")
        )
        """
        
        let result = try parser.parse(payload)
        
        #expect(result.blokName == "bk.action.map.Make")
        #expect(result.blokArgs?.count == 2)
        
        guard let args = result.blokArgs else {
            Issue.record("Expected args")
            return
        }
        
        // First nested blok
        #expect(args[0].blokName == "bk.action.array.Make")
        #expect(args[0].blokArgs?.count == 2)
        
        // Second nested blok
        #expect(args[1].blokName == "bk.action.array.Make")
        #expect(args[1].blokArgs?.count == 2)
    }
    
    @Test func parseLocalBlok() throws {
        let parser = BloksParser()
        let result = try parser.parse("(#local-tag-123)")
        
        #expect(result.blokName == "local-tag-123")
        #expect(result.isLocalBlok == true)
    }
    
    @Test func parseLocalBlokWithColons() throws {
        let parser = BloksParser()
        let result = try parser.parse("(#some:local:tag, 42)")
        
        #expect(result.blokName == "some:local:tag")
        #expect(result.isLocalBlok == true)
        #expect(result.blokArgs?.count == 1)
    }
    
    // MARK: - Number Parsing Tests
    
    @Test func parseInteger() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, 42069)")
        
        guard case .number(let value) = result.blokArgs?[0] else {
            Issue.record("Expected number")
            return
        }
        #expect(value == 42069.0)
    }
    
    @Test func parseNegativeNumber() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, -123)")
        
        guard case .number(let value) = result.blokArgs?[0] else {
            Issue.record("Expected number")
            return
        }
        #expect(value == -123.0)
    }
    
    @Test func parseDecimalNumber() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, 3.14159)")
        
        guard case .number(let value) = result.blokArgs?[0] else {
            Issue.record("Expected number")
            return
        }
        #expect(abs(value - 3.14159) < 0.00001)
    }
    
    @Test func parseScientificNotation() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, 1.5e10)")
        
        guard case .number(let value) = result.blokArgs?[0] else {
            Issue.record("Expected number")
            return
        }
        #expect(abs(value - 1.5e10) < 1.0)
    }
    
    @Test func parseNegativeExponent() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, 1.5e-5)")
        
        guard case .number(let value) = result.blokArgs?[0] else {
            Issue.record("Expected number")
            return
        }
        #expect(abs(value - 1.5e-5) < 0.0000001)
    }
    
    // MARK: - String Parsing Tests
    
    @Test func parseStringWithEscapes() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(test, "hello\nworld")"#)
        
        guard case .string(let value) = result.blokArgs?[0] else {
            Issue.record("Expected string")
            return
        }
        #expect(value == "hello\nworld")
    }
    
    @Test func parseStringWithUnicode() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(test, "hello\u0020world")"#)
        
        guard case .string(let value) = result.blokArgs?[0] else {
            Issue.record("Expected string")
            return
        }
        #expect(value == "hello world")
    }
    
    @Test func parseStringWithEscapedQuotes() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(test, "say \"hello\"")"#)
        
        guard case .string(let value) = result.blokArgs?[0] else {
            Issue.record("Expected string")
            return
        }
        #expect(value == #"say "hello""#)
    }
    
    @Test func parseStringWithBackslash() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(test, "path\\to\\file")"#)
        
        guard case .string(let value) = result.blokArgs?[0] else {
            Issue.record("Expected string")
            return
        }
        #expect(value == #"path\to\file"#)
    }
    
    @Test func parseStringWithAllEscapes() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(test, "\b\f\r\t\n")"#)
        
        guard case .string(let value) = result.blokArgs?[0] else {
            Issue.record("Expected string")
            return
        }
        #expect(value == "\u{08}\u{0C}\r\t\n")
    }
    
    // MARK: - Boolean and Null Tests
    
    @Test func parseTrue() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, true)")
        
        #expect(result.blokArgs?[0] == .bool(true))
    }
    
    @Test func parseFalse() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, false)")
        
        #expect(result.blokArgs?[0] == .bool(false))
    }
    
    @Test func parseNull() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, null)")
        
        #expect(result.blokArgs?[0] == .null)
    }
    
    // MARK: - Whitespace Handling Tests
    
    @Test func parseWithMinimalWhitespace() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(bk.action.array.Make,"a","b","c")"#)
        
        #expect(result.blokName == "bk.action.array.Make")
        #expect(result.blokArgs?.count == 3)
    }
    
    @Test func parseWithExtraWhitespace() throws {
        let parser = BloksParser()
        let result = try parser.parse("""
        
          (  bk.action.test  ,  
              "hello"  ,  
              42  
          )  
        
        """)
        
        #expect(result.blokName == "bk.action.test")
        #expect(result.blokArgs?.count == 2)
    }
    
    // MARK: - Custom Processor Tests
    
    @Test func customProcessor() throws {
        let processors: [String: BlokProcessor] = [
            "bk.action.array.Make": { _, args, _ in
                .blok(name: "array", args: args, isLocal: false)
            },
            "bk.action.i32.Const": { _, args, _ in
                if let first = args.first, case .number(let value) = first {
                    return .number(value)
                }
                return args.first ?? .null
            }
        ]
        
        let parser = BloksParser(processors: processors)
        let result = try parser.parse("(bk.action.array.Make, (bk.action.i32.Const, 42), (bk.action.i32.Const, 69))")
        
        #expect(result.blokName == "array")
        #expect(result.blokArgs?.count == 2)
        #expect(result.blokArgs?[0] == .number(42))
        #expect(result.blokArgs?[1] == .number(69))
    }
    
    @Test func fallbackProcessor() throws {
        nonisolated(unsafe) var unknownBloks: [String] = []
        
        let processors: [String: BlokProcessor] = [
            "@": { name, args, isLocal in
                unknownBloks.append(name)
                return .blok(name: name, args: args, isLocal: isLocal)
            }
        ]
        
        let parser = BloksParser(processors: processors)
        _ = try parser.parse("(bk.unknown.type, 42)")
        
        #expect(unknownBloks == ["bk.unknown.type"])
    }
    
    @Test func basicProcessors() throws {
        let parser = BloksParser.withBasicProcessors()
        let payload = #"(bk.action.array.Make, (bk.action.i32.Const, 42), "hello", (bk.action.bool.Const, true))"#
        
        let result = try parser.parse(payload)
        
        #expect(result.blokName == "array")
        #expect(result.blokArgs?.count == 3)
        #expect(result.blokArgs?[0] == .number(42))
        #expect(result.blokArgs?[1] == .string("hello"))
        #expect(result.blokArgs?[2] == .bool(true))
    }
    
    // MARK: - JSON Conversion Tests
    
    @Test func toJSON() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(bk.action.test, "hello", 42, true, null)"#)
        
        let json = result.toJSON() as! [Any]
        
        #expect(json[0] as? String == "bk.action.test")
        #expect(json[1] as? String == "hello")
        #expect(json[2] as? Double == 42.0)
        #expect(json[3] as? Bool == true)
        #expect(json[4] is NSNull)
    }
    
    @Test func toJSONString() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(bk.action.test, "hello")"#)
        
        let jsonString = try result.toJSONString()
        #expect(jsonString.contains("bk.action.test"))
        #expect(jsonString.contains("hello"))
    }
    
    // MARK: - Convenience Function Tests
    
    @Test func testCreateBloksParser() throws {
        let parse = createBloksParser()
        let result = try parse("(test, 42)")
        
        #expect(result.blokName == "test")
    }
    
    @Test func testCreateBloksParserWithBasics() throws {
        let parse = createBloksParserWithBasics()
        let result = try parse("(bk.action.i32.Const, 42)")
        
        #expect(result == .number(42))
    }
    
    // MARK: - Complex Payload Tests
    
    @Test func complexPayload() throws {
        let parser = BloksParser.withBasicProcessors()
        let payload = """
        (bk.action.array.Make,
            (bk.action.i32.Const, 42069),
            "nice",
            (bk.action.bool.Const, true),
            (bk.action.map.Make,
                (bk.action.array.Make, "a", "b", "c"),
                (bk.action.array.Make,
                    (bk.action.i32.Const, 1),
                    (bk.action.i32.Const, 2),
                    (bk.action.i32.Const, 3)
                )
            )
        )
        """
        
        let result = try parser.parse(payload)
        
        #expect(result.blokName == "array")
        #expect(result.blokArgs?.count == 4)
        #expect(result.blokArgs?[0] == .number(42069))
        #expect(result.blokArgs?[1] == .string("nice"))
        #expect(result.blokArgs?[2] == .bool(true))
        #expect(result.blokArgs?[3].blokName == "map")
    }
    
    // MARK: - Error Handling Tests
    
    @Test func unterminatedString() {
        let parser = BloksParser()
        
        #expect(throws: BloksParserError.self) {
            try parser.parse(#"(test, "hello)"#)
        }
    }
    
    @Test func missingClosingParen() {
        let parser = BloksParser()
        
        #expect(throws: BloksParserError.self) {
            try parser.parse("(test, 42")
        }
    }
    
    @Test func unexpectedCharacter() {
        let parser = BloksParser()
        
        #expect(throws: BloksParserError.self) {
            try parser.parse("(test, @invalid)")
        }
    }
    
    @Test func emptyInput() {
        let parser = BloksParser()
        
        #expect(throws: BloksParserError.self) {
            try parser.parse("")
        }
    }
    
    @Test func trailingContent() {
        let parser = BloksParser()
        
        #expect(throws: BloksParserError.self) {
            try parser.parse("(test)extra")
        }
    }
    
    // MARK: - Description Tests
    
    @Test func bloksValueDescription() {
        #expect(BloksValue.null.description == "null")
        #expect(BloksValue.bool(true).description == "true")
        #expect(BloksValue.bool(false).description == "false")
        #expect(BloksValue.number(42).description == "42")
        #expect(BloksValue.number(3.14).description == "3.14")
        #expect(BloksValue.string("hello").description == "\"hello\"")
    }
    
    // MARK: - Real-World Example Tests
    
    @Test func instagramLoginPayload() throws {
        let parser = BloksParser()
        let payload = """
        (bk.action.map.Make,
            (bk.action.array.Make, "login_type", "login_source"),
            (bk.action.array.Make, "Password", "Login")
        )
        """
        
        let result = try parser.parse(payload)
        let json = try result.toJSONString(prettyPrinted: true)
        
        #expect(json.contains("bk.action.map.Make"))
        #expect(json.contains("login_type"))
        #expect(json.contains("Password"))
    }
}
