import XCTest
@testable import BloksParser

final class BloksParserTests: XCTestCase {
    
    // MARK: - Basic Parsing Tests
    
    func testParseSimpleBlok() throws {
        let parser = BloksParser()
        let result = try parser.parse("(bk.action.test)")
        
        XCTAssertEqual(result.blokName, "bk.action.test")
        XCTAssertEqual(result.blokArgs?.count, 0)
        XCTAssertFalse(result.isLocalBlok)
    }
    
    func testParseBlokWithStringArg() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(bk.action.test, "hello")"#)
        
        XCTAssertEqual(result.blokName, "bk.action.test")
        XCTAssertEqual(result.blokArgs?.count, 1)
        
        if case .string(let value) = result.blokArgs?[0] {
            XCTAssertEqual(value, "hello")
        } else {
            XCTFail("Expected string argument")
        }
    }
    
    func testParseBlokWithMultipleArgs() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(bk.action.test, "hello", 42, true, null)"#)
        
        XCTAssertEqual(result.blokName, "bk.action.test")
        XCTAssertEqual(result.blokArgs?.count, 4)
        
        guard let args = result.blokArgs else {
            XCTFail("Expected args")
            return
        }
        
        if case .string(let value) = args[0] {
            XCTAssertEqual(value, "hello")
        } else {
            XCTFail("Expected string")
        }
        
        if case .number(let value) = args[1] {
            XCTAssertEqual(value, 42.0)
        } else {
            XCTFail("Expected number")
        }
        
        if case .bool(let value) = args[2] {
            XCTAssertTrue(value)
        } else {
            XCTFail("Expected bool")
        }
        
        XCTAssertEqual(args[3], .null)
    }
    
    func testParseNestedBloks() throws {
        let parser = BloksParser()
        let payload = """
        (bk.action.map.Make,
            (bk.action.array.Make, "login_type", "login_source"),
            (bk.action.array.Make, "Password", "Login")
        )
        """
        
        let result = try parser.parse(payload)
        
        XCTAssertEqual(result.blokName, "bk.action.map.Make")
        XCTAssertEqual(result.blokArgs?.count, 2)
        
        guard let args = result.blokArgs else {
            XCTFail("Expected args")
            return
        }
        
        // First nested blok
        XCTAssertEqual(args[0].blokName, "bk.action.array.Make")
        XCTAssertEqual(args[0].blokArgs?.count, 2)
        
        // Second nested blok
        XCTAssertEqual(args[1].blokName, "bk.action.array.Make")
        XCTAssertEqual(args[1].blokArgs?.count, 2)
    }
    
    func testParseLocalBlok() throws {
        let parser = BloksParser()
        let result = try parser.parse("(#local-tag-123)")
        
        XCTAssertEqual(result.blokName, "local-tag-123")
        XCTAssertTrue(result.isLocalBlok)
    }
    
    func testParseLocalBlokWithColons() throws {
        let parser = BloksParser()
        let result = try parser.parse("(#some:local:tag, 42)")
        
        XCTAssertEqual(result.blokName, "some:local:tag")
        XCTAssertTrue(result.isLocalBlok)
        XCTAssertEqual(result.blokArgs?.count, 1)
    }
    
    // MARK: - Number Parsing Tests
    
    func testParseInteger() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, 42069)")
        
        if case .number(let value) = result.blokArgs?[0] {
            XCTAssertEqual(value, 42069.0)
        } else {
            XCTFail("Expected number")
        }
    }
    
    func testParseNegativeNumber() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, -123)")
        
        if case .number(let value) = result.blokArgs?[0] {
            XCTAssertEqual(value, -123.0)
        } else {
            XCTFail("Expected number")
        }
    }
    
    func testParseDecimalNumber() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, 3.14159)")
        
        if case .number(let value) = result.blokArgs?[0] {
            XCTAssertEqual(value, 3.14159, accuracy: 0.00001)
        } else {
            XCTFail("Expected number")
        }
    }
    
    func testParseScientificNotation() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, 1.5e10)")
        
        if case .number(let value) = result.blokArgs?[0] {
            XCTAssertEqual(value, 1.5e10, accuracy: 1.0)
        } else {
            XCTFail("Expected number")
        }
    }
    
    func testParseNegativeExponent() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, 1.5e-5)")
        
        if case .number(let value) = result.blokArgs?[0] {
            XCTAssertEqual(value, 1.5e-5, accuracy: 0.0000001)
        } else {
            XCTFail("Expected number")
        }
    }
    
    // MARK: - String Parsing Tests
    
    func testParseStringWithEscapes() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(test, "hello\nworld")"#)
        
        if case .string(let value) = result.blokArgs?[0] {
            XCTAssertEqual(value, "hello\nworld")
        } else {
            XCTFail("Expected string")
        }
    }
    
    func testParseStringWithUnicode() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(test, "hello\u0020world")"#)
        
        if case .string(let value) = result.blokArgs?[0] {
            XCTAssertEqual(value, "hello world")
        } else {
            XCTFail("Expected string")
        }
    }
    
    func testParseStringWithEscapedQuotes() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(test, "say \"hello\"")"#)
        
        if case .string(let value) = result.blokArgs?[0] {
            XCTAssertEqual(value, #"say "hello""#)
        } else {
            XCTFail("Expected string")
        }
    }
    
    func testParseStringWithBackslash() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(test, "path\\to\\file")"#)
        
        if case .string(let value) = result.blokArgs?[0] {
            XCTAssertEqual(value, #"path\to\file"#)
        } else {
            XCTFail("Expected string")
        }
    }
    
    func testParseStringWithAllEscapes() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(test, "\b\f\r\t\n")"#)
        
        if case .string(let value) = result.blokArgs?[0] {
            XCTAssertEqual(value, "\u{08}\u{0C}\r\t\n")
        } else {
            XCTFail("Expected string")
        }
    }
    
    // MARK: - Boolean and Null Tests
    
    func testParseTrue() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, true)")
        
        XCTAssertEqual(result.blokArgs?[0], .bool(true))
    }
    
    func testParseFalse() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, false)")
        
        XCTAssertEqual(result.blokArgs?[0], .bool(false))
    }
    
    func testParseNull() throws {
        let parser = BloksParser()
        let result = try parser.parse("(test, null)")
        
        XCTAssertEqual(result.blokArgs?[0], .null)
    }
    
    // MARK: - Whitespace Handling Tests
    
    func testParseWithMinimalWhitespace() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(bk.action.array.Make,"a","b","c")"#)
        
        XCTAssertEqual(result.blokName, "bk.action.array.Make")
        XCTAssertEqual(result.blokArgs?.count, 3)
    }
    
    func testParseWithExtraWhitespace() throws {
        let parser = BloksParser()
        let result = try parser.parse("""
        
          (  bk.action.test  ,  
              "hello"  ,  
              42  
          )  
        
        """)
        
        XCTAssertEqual(result.blokName, "bk.action.test")
        XCTAssertEqual(result.blokArgs?.count, 2)
    }
    
    // MARK: - Custom Processor Tests
    
    func testCustomProcessor() throws {
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
        
        XCTAssertEqual(result.blokName, "array")
        XCTAssertEqual(result.blokArgs?.count, 2)
        XCTAssertEqual(result.blokArgs?[0], .number(42))
        XCTAssertEqual(result.blokArgs?[1], .number(69))
    }
    
    func testFallbackProcessor() throws {
        nonisolated(unsafe) var unknownBloks: [String] = []
        
        let processors: [String: BlokProcessor] = [
            "@": { name, args, isLocal in
                unknownBloks.append(name)
                return .blok(name: name, args: args, isLocal: isLocal)
            }
        ]
        
        let parser = BloksParser(processors: processors)
        _ = try parser.parse("(bk.unknown.type, 42)")
        
        XCTAssertEqual(unknownBloks, ["bk.unknown.type"])
    }
    
    func testBasicProcessors() throws {
        let parser = BloksParser.withBasicProcessors()
        let payload = #"(bk.action.array.Make, (bk.action.i32.Const, 42), "hello", (bk.action.bool.Const, true))"#
        
        let result = try parser.parse(payload)
        
        XCTAssertEqual(result.blokName, "array")
        XCTAssertEqual(result.blokArgs?.count, 3)
        XCTAssertEqual(result.blokArgs?[0], .number(42))
        XCTAssertEqual(result.blokArgs?[1], .string("hello"))
        XCTAssertEqual(result.blokArgs?[2], .bool(true))
    }
    
    // MARK: - JSON Conversion Tests
    
    func testToJSON() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(bk.action.test, "hello", 42, true, null)"#)
        
        let json = result.toJSON() as! [Any]
        
        XCTAssertEqual(json[0] as? String, "bk.action.test")
        XCTAssertEqual(json[1] as? String, "hello")
        XCTAssertEqual(json[2] as? Double, 42.0)
        XCTAssertEqual(json[3] as? Bool, true)
        XCTAssertTrue(json[4] is NSNull)
    }
    
    func testToJSONString() throws {
        let parser = BloksParser()
        let result = try parser.parse(#"(bk.action.test, "hello")"#)
        
        let jsonString = try result.toJSONString()
        XCTAssertTrue(jsonString.contains("bk.action.test"))
        XCTAssertTrue(jsonString.contains("hello"))
    }
    
    // MARK: - Convenience Function Tests
    
    func testCreateBloksParser() throws {
        let parse = createBloksParser()
        let result = try parse("(test, 42)")
        
        XCTAssertEqual(result.blokName, "test")
    }
    
    func testCreateBloksParserWithBasics() throws {
        let parse = createBloksParserWithBasics()
        let result = try parse("(bk.action.i32.Const, 42)")
        
        XCTAssertEqual(result, .number(42))
    }
    
    // MARK: - Complex Payload Tests
    
    func testComplexPayload() throws {
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
        
        XCTAssertEqual(result.blokName, "array")
        XCTAssertEqual(result.blokArgs?.count, 4)
        XCTAssertEqual(result.blokArgs?[0], .number(42069))
        XCTAssertEqual(result.blokArgs?[1], .string("nice"))
        XCTAssertEqual(result.blokArgs?[2], .bool(true))
        XCTAssertEqual(result.blokArgs?[3].blokName, "map")
    }
    
    // MARK: - Error Handling Tests
    
    func testUnterminatedString() {
        let parser = BloksParser()
        
        XCTAssertThrowsError(try parser.parse(#"(test, "hello)"#)) { error in
            XCTAssertTrue(error is BloksParserError)
        }
    }
    
    func testMissingClosingParen() {
        let parser = BloksParser()
        
        XCTAssertThrowsError(try parser.parse("(test, 42")) { error in
            XCTAssertTrue(error is BloksParserError)
        }
    }
    
    func testUnexpectedCharacter() {
        let parser = BloksParser()
        
        XCTAssertThrowsError(try parser.parse("(test, @invalid)")) { error in
            XCTAssertTrue(error is BloksParserError)
        }
    }
    
    func testEmptyInput() {
        let parser = BloksParser()
        
        XCTAssertThrowsError(try parser.parse("")) { error in
            XCTAssertTrue(error is BloksParserError)
        }
    }
    
    func testTrailingContent() {
        let parser = BloksParser()
        
        XCTAssertThrowsError(try parser.parse("(test)extra")) { error in
            XCTAssertTrue(error is BloksParserError)
        }
    }
    
    // MARK: - Description Tests
    
    func testBloksValueDescription() throws {
        XCTAssertEqual(BloksValue.null.description, "null")
        XCTAssertEqual(BloksValue.bool(true).description, "true")
        XCTAssertEqual(BloksValue.bool(false).description, "false")
        XCTAssertEqual(BloksValue.number(42).description, "42")
        XCTAssertEqual(BloksValue.number(3.14).description, "3.14")
        XCTAssertEqual(BloksValue.string("hello").description, "\"hello\"")
    }
    
    // MARK: - Real-World Example Tests
    
    func testInstagramLoginPayload() throws {
        let parser = BloksParser()
        let payload = """
        (bk.action.map.Make,
            (bk.action.array.Make, "login_type", "login_source"),
            (bk.action.array.Make, "Password", "Login")
        )
        """
        
        let result = try parser.parse(payload)
        let json = try result.toJSONString(prettyPrinted: true)
        
        XCTAssertTrue(json.contains("bk.action.map.Make"))
        XCTAssertTrue(json.contains("login_type"))
        XCTAssertTrue(json.contains("Password"))
    }
}
