# BloksParser

A Swift parser library for parsing Instagram/Threads `bloks_payload` fields.

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Faporat%2FBloksParser%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/aporat/BloksParser)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Faporat%2FBloksParser%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/aporat/BloksParser)
![GitHub Actions Workflow Status](https://github.com/aporat/BloksParser/actions/workflows/ci.yml/badge.svg)
[![codecov](https://codecov.io/github/aporat/BloksParser/graph/badge.svg?token=OHF9AE0KMC)](https://codecov.io/github/aporat/BloksParser)

## Overview

Instagram and Threads use a custom serialization format called "bloks" in their API responses. This library parses that format into structured Swift types.

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/BloksParser.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Usage

### Basic Parsing

```swift
import BloksParser

let parser = BloksParser()
let payload = """
(bk.action.map.Make,
    (bk.action.array.Make, "login_type", "login_source"),
    (bk.action.array.Make, "Password", "Login")
)
"""

do {
    let result = try parser.parse(payload)
    print(result)
    // Output: (bk.action.map.Make, (bk.action.array.Make, "login_type", "login_source"), ...)
} catch {
    print("Parse error: \(error)")
}
```

### Using the Functional API

```swift
import BloksParser

let parse = createBloksParser()

let result = try parse("(bk.action.test, \"hello\", 42)")
```

### Converting to JSON

```swift
let result = try parser.parse(payload)

// Convert to Any (arrays and dictionaries)
let jsonObject = result.toJSON()

// Convert to JSON string
let jsonString = try result.toJSONString(prettyPrinted: true)
print(jsonString)
// Output:
// [
//   "bk.action.map.Make",
//   ["bk.action.array.Make", "login_type", "login_source"],
//   ["bk.action.array.Make", "Password", "Login"]
// ]
```

### Using Custom Processors

You can define custom processors to transform specific blok types:

```swift
let processors: [String: BlokProcessor] = [
    "bk.action.array.Make": { _, args, _ in
        .blok(name: "array", args: args, isLocal: false)
    },
    "bk.action.i32.Const": { _, args, _ in
        if let first = args.first, case .number(let value) = first {
            return .number(value)
        }
        return args.first ?? .null
    },
    "bk.action.bool.Const": { _, args, _ in
        if let first = args.first, case .bool(let value) = first {
            return .bool(value)
        }
        return .bool(false)
    },
    "bk.action.map.Make": { _, args, _ in
        .blok(name: "map", args: args, isLocal: false)
    }
]

let parser = BloksParser(processors: processors)
let result = try parser.parse(payload)
```

### Using Basic Processors

The library includes basic processors for common blok types:

```swift
let parser = BloksParser.withBasicProcessors()

// Or using the functional API:
let parse = createBloksParserWithBasics()

let payload = "(bk.action.array.Make, (bk.action.i32.Const, 42), \"nice\", (bk.action.bool.Const, true))"
let result = try parser.parse(payload)
// Result will have processed values: array containing 42, "nice", true
```

### Handling Unknown Blok Types

Use the `@` processor key to handle blok types that don't have a specific processor:

```swift
let processors: [String: BlokProcessor] = [
    "@": { name, args, isLocal in
        print("Unknown blok: \(isLocal ? "#" : "")\(name)")
        return .blok(name: name, args: args, isLocal: isLocal)
    }
]

let parser = BloksParser(processors: processors)
```

## BloksValue Type

The parser returns `BloksValue`, an enum with the following cases:

```swift
public enum BloksValue {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case blok(name: String, args: [BloksValue], isLocal: Bool)
}
```

### Convenience Properties

```swift
let result = try parser.parse("(bk.test, 42)")

// Get the blok name
result.blokName  // "bk.test"

// Get the arguments
result.blokArgs  // [.number(42)]

// Check if it's a local blok (starts with #)
result.isLocalBlok  // false
```

## Bloks Grammar

The bloks format supports:

- **Bloks**: `(ClassName, arg1, arg2, ...)` or `(#local-tag, arg1, ...)`
- **Strings**: `"hello"` with escape sequences (`\n`, `\t`, `\uXXXX`, etc.)
- **Numbers**: Integers, decimals, and scientific notation (`42`, `3.14`, `1.5e10`)
- **Booleans**: `true` and `false`
- **Null**: `null`

### Example Payloads

```
// Simple blok
(bk.action.test)

// Blok with arguments
(bk.action.array.Make, "a", "b", "c")

// Nested bloks
(bk.action.map.Make,
    (bk.action.array.Make, "key1", "key2"),
    (bk.action.array.Make, "value1", "value2")
)

// Local blok (starts with #)
(#local-tag-123, 42, "data")

// Mixed types
(bk.action.test, 42, 3.14, true, false, null, "string")
```

## Error Handling

The parser throws `BloksParserError` for invalid input:

```swift
public enum BloksParserError: Error {
    case unexpectedEndOfInput
    case unexpectedCharacter(Character, position: Int)
    case invalidNumber(String, position: Int)
    case invalidEscapeSequence(String, position: Int)
    case unterminatedString(position: Int)
    case expectedCharacter(Character, got: Character?, position: Int)
    case invalidBlokName(position: Int)
    case internalError(String)
}
```

## Thread Safety

`BloksParser` is marked as `@unchecked Sendable` and `BloksValue` is `Sendable`. Each call to `parse()` uses independent state, making the parser safe to use across threads.

## License

MIT License
