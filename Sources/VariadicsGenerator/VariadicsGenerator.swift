//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

// swift run VariadicsGenerator --max-arity 7 > Sources/_StringProcessing/RegexDSL/Concatenation.swift

import ArgumentParser
#if os(macOS)
import Darwin
#elseif os(Linux)
import Glibc
#elseif os(Windows)
import CRT
#endif

// (T), (T)
// (T), (T, T)
// …
// (T), (T, T, T, T, T, T, T)
// (T, T), (T)
// (T, T), (T, T)
// …
// (T, T), (T, T, T, T, T, T)
// …
struct Permutations: Sequence {
  let totalArity: Int

  struct Iterator: IteratorProtocol {
    let totalArity: Int
    var leftArity: Int = 0
    var rightArity: Int = 0

    mutating func next() -> (combinedArity: Int, nextArity: Int)? {
      guard leftArity < totalArity else {
        return nil
      }
      defer {
        if leftArity + rightArity >= totalArity {
          leftArity += 1
          rightArity = 0
        } else {
          rightArity += 1
        }
      }
      return (leftArity, rightArity)
    }
  }

  public func makeIterator() -> Iterator {
    Iterator(totalArity: totalArity)
  }
}

func output(_ content: String) {
  print(content, terminator: "")
}

func outputForEach<C: Collection>(
  _ elements: C,
  separator: String? = nil,
  lineTerminator: String? = nil,
  _ content: (C.Element) -> String
) {
  for i in elements.indices {
    output(content(elements[i]))
    let needsSep = elements.index(after: i) != elements.endIndex
    if needsSep, let sep = separator {
      output(sep)
    }
    if let lt = lineTerminator {
      let indent = needsSep ? "      " : "    "
      output("\(lt)\n\(indent)")
    }
  }
}

struct StandardErrorStream: TextOutputStream {
  func write(_ string: String) {
    fputs(string, stderr)
  }
}
var standardError = StandardErrorStream()

typealias Counter = Int64
let regexProtocolName = "RegexProtocol"
let concatenationStructTypeBaseName = "Concatenate"
let capturingGroupTypeBaseName = "CapturingGroup"
let matchAssociatedTypeName = "Match"
let captureAssociatedTypeName = "Capture"
let patternBuilderTypeName = "RegexBuilder"
let patternProtocolRequirementName = "regex"
let PatternTypeBaseName = "Regex"
let emptyProtocolName = "EmptyCaptureProtocol"
let baseMatchTypeName = "Substring"

@main
struct VariadicsGenerator: ParsableCommand {
  @Option(help: "The maximum arity of declarations to generate.")
  var maxArity: Int

  func run() throws {
    precondition(maxArity > 1)
    precondition(maxArity < Counter.bitWidth)

    output("""
      //===----------------------------------------------------------------------===//
      //
      // This source file is part of the Swift.org open source project
      //
      // Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
      // Licensed under Apache License v2.0 with Runtime Library Exception
      //
      // See https://swift.org/LICENSE.txt for license information
      //
      //===----------------------------------------------------------------------===//

      // BEGIN AUTO-GENERATED CONTENT

      import _MatchingEngine


      """)

    for arity in 2...maxArity+1 {
      emitTupleStruct(arity: arity)
    }

    print("Generating concatenation overloads...", to: &standardError)
    for (leftArity, rightArity) in Permutations(totalArity: maxArity) {
      print(
        "  Left arity: \(leftArity)  Right arity: \(rightArity)",
        to: &standardError)
      emitConcatenation(leftArity: leftArity, rightArity: rightArity)
    }

    for arity in 0..<maxArity {
      emitConcatenationWithEmpty(leftArity: arity)
    }

    output("\n\n")

    print("Generating quantifiers...", to: &standardError)
    for arity in 0..<maxArity {
      print("  Arity \(arity): ", terminator: "", to: &standardError)
      for kind in QuantifierKind.allCases {
        print("\(kind.rawValue) ", terminator: "", to: &standardError)
        emitQuantifier(kind: kind, arity: arity)
      }
      print(to: &standardError)
    }

    output("\n\n")

    output("// END AUTO-GENERATED CONTENT\n")

    print("Done!", to: &standardError)
  }

  func tupleType(arity: Int, genericParameters: () -> String) -> String {
    assert(arity >= 0)
    if arity == 0 {
      return genericParameters()
    }
    return "Tuple\(arity)<\(genericParameters())>"
  }

  func emitTupleStruct(arity: Int) {
    output("""
      @frozen @dynamicMemberLookup
      public struct Tuple\(arity)<
      """)
    outputForEach(0..<arity, separator: ", ") {
      "_\($0)"
    }
    output("> {")
    // `public typealias Tuple = (_0, ...)`
    output("\n  public typealias Tuple = (")
    outputForEach(0..<arity, separator: ", ") { "_\($0)" }
    output(")")
    // `public var tuple: Tuple`
    output("\n  public var tuple: Tuple\n")
    // `subscript(dynamicMember:)`
    output("""
        public subscript<T>(dynamicMember keyPath: WritableKeyPath<Tuple, T>) -> T {
          get { tuple[keyPath: keyPath] }
          _modify { yield &tuple[keyPath: keyPath] }
        }
      """)
    output("\n}\n")
    output("extension Tuple\(arity): \(emptyProtocolName) where ")
    outputForEach(1..<arity, separator: ", ") {
      "_\($0): \(emptyProtocolName)"
    }
    output(" {}\n")
    output("extension Tuple\(arity): MatchProtocol {\n")
    output("  public typealias Capture = ")
    if arity == 2 {
      output("_1")
    } else {
      output("Tuple\(arity-1)<")
      outputForEach(1..<arity, separator: ", ") {
        "_\($0)"
      }
      output(">")
    }
    output("\n  public init(_ tuple: Tuple) { self.tuple = tuple }")
    // `public init(_0: _0, ...) { ... }`
    output("\n  public init(")
    outputForEach(0..<arity, separator: ", ") {
      "_ _\($0): _\($0)"
    }
    output(") {\n")
    output("    self.init((")
    outputForEach(0..<arity, separator: ", ") { "_\($0)" }
    output("))\n")
    output("  }")
    output("\n}\n")
    // Equatable
    output("extension Tuple\(arity): Equatable where ")
    outputForEach(0..<arity, separator: ", ") {
      "_\($0): Equatable"
    }
    output(" {\n")
    output("  public static func == (lhs: Self, rhs: Self) -> Bool {\n")
    output("    ")
    outputForEach(0..<arity, separator: " && ") {
      "lhs.tuple.\($0) == rhs.tuple.\($0)"
    }
    output("\n  }\n")
    output("}\n")
  }

  func emitConcatenation(leftArity: Int, rightArity: Int) {
    func emitGenericParameters(withConstraints: Bool) {
      output("W0, W1")
      outputForEach(0..<leftArity+rightArity) {
        ", C\($0)"
      }
      output(", ")
      if withConstraints {
        output("R0: \(regexProtocolName), R1: \(regexProtocolName)")
      } else {
        output("R0, R1")
      }
    }

    // Emit concatenation type declaration.

    // public struct Concatenation2<W0, W1, C0, C1, R0: RegexProtocol, R1: RegexProtocol>: RegexProtocol
    // where R0.Match == Tuple2<W0, C0>, R1.Match == Tuple2<W1, C1>
    // {
    //   public typealias Match = Tuple3<Substring, C0, C1>
    //
    //   public let regex: Regex<Tuple3<Substring, C0, C1>>
    //
    //   public init(_ r0: R0, _ r1: R1) {
    //     self.regex = .init(node: r0.regex.root.appending(r1.regex.root))
    //   }
    // }
    //
    // extension RegexBuilder {
    //   static func buildBlock<W0, W1, C0, C1, Combined: RegexProtocol, Next: RegexProtocol>(
    //     combining next: Next, into combined: Combined
    //   ) -> Concatenation2<W0, W1, C0, C1, Combined, Next> {
    //     .init(combined, next)
    //   }
    // }

    //   public struct Concatenation{n}<...>: RegexProtocol {
    //     public typealias Match = ...
    //     public let regex: Regex<Match>
    //     public init(...) { ... }
    //   }

    let typeName = "\(concatenationStructTypeBaseName)_\(leftArity)_\(rightArity)"
    output("public struct \(typeName)<\n  ")
    emitGenericParameters(withConstraints: true)
    output("\n>: \(regexProtocolName)")
    output(" where ")
    output("R0.Match == ")
    if leftArity == 0 {
      output("W0")
    } else {
      output("Tuple\(leftArity+1)<W0")
      outputForEach(0..<leftArity) {
        ", C\($0)"
      }
      output(">")
    }
    output(", R1.Match == ")
    if rightArity == 0 {
      output("W1")
    } else {
      output("Tuple\(rightArity+1)<W1")
      outputForEach(leftArity..<leftArity+rightArity) {
        ", C\($0)"
      }
      output(">")
    }
    output(" {\n")
    output("  public typealias \(matchAssociatedTypeName) = ")
    if leftArity+rightArity == 0 {
      output(baseMatchTypeName)
    } else {
      output("Tuple\(leftArity+rightArity+1)<\(baseMatchTypeName), ")
      outputForEach(0..<leftArity+rightArity, separator: ", ") {
        "C\($0)"
      }
      output(">")
    }
    output("\n")
    output("  public let \(patternProtocolRequirementName): \(PatternTypeBaseName)<\(matchAssociatedTypeName)>\n")
    output("""
        init(_ r0: R0, _ r1: R1) {
          self.regex = .init(node: r0.regex.root.appending(r1.regex.root))
        }
      }

      """)

    // Emit concatenation builder.
    output("extension \(patternBuilderTypeName) {\n")
    output("""
          @_disfavoredOverload
          public static func buildBlock<
        """)
    emitGenericParameters(withConstraints: true)
    output("""
      >(
          combining next: R1, into combined: R0
        ) -> \(typeName)<
      """)
    emitGenericParameters(withConstraints: false)
    output("""
      > {
          .init(combined, next)
        }
      }

      """)
  }

  func emitConcatenationWithEmpty(leftArity: Int) {
    // T + () = T
    output("""
       extension RegexBuilder {
         public static func buildBlock<W0
       """)
    outputForEach(0..<leftArity) {
      ", C\($0)"
    }
    output("""
      , R0: \(regexProtocolName), R1: \(regexProtocolName)>(
          combining next: R1, into combined: R0
        ) -> Regex<
      """)
    if leftArity == 0 {
      output(baseMatchTypeName)
    } else {
      output("Tuple\(leftArity+1)<\(baseMatchTypeName)")
      outputForEach(0..<leftArity) {
        ", C\($0)"
      }
      output(">")
    }
    output("> where R0.\(matchAssociatedTypeName) == ")
    if leftArity == 0 {
      output("W0")
    } else {
      output("Tuple\(leftArity+1)<W0")
      outputForEach(0..<leftArity) {
        ", C\($0)"
      }
      output(">")
    }
    output("""
      , R1.\(matchAssociatedTypeName): \(emptyProtocolName) {
          .init(node: combined.regex.root.appending(next.regex.root))
        }
      }

      """)
  }

  enum QuantifierKind: String, CaseIterable {
    case zeroOrOne = "optionally"
    case zeroOrMore = "many"
    case oneOrMore = "oneOrMore"

    var typeName: String {
      switch self {
      case .zeroOrOne: return "_ZeroOrOne"
      case .zeroOrMore: return "_ZeroOrMore"
      case .oneOrMore: return "_OneOrMore"
      }
    }

    var operatorName: String {
      switch self {
      case .zeroOrOne: return ".?"
      case .zeroOrMore: return ".+"
      case .oneOrMore: return ".*"
      }
    }

    var astQuantifierAmount: String {
      switch self {
      case .zeroOrOne: return "zeroOrOne"
      case .zeroOrMore: return "zeroOrMore"
      case .oneOrMore: return "oneOrMore"
      }
    }
  }

  func emitQuantifier(kind: QuantifierKind, arity: Int) {
    assert(arity >= 0)
    func genericParameters(withConstraints: Bool) -> String {
      var result = ""
      if arity > 0 {
        result += "W"
        result += (0..<arity).map { ", C\($0)" }.joined()
        result += ", "
      }
      result += "Component"
      if withConstraints {
        result += ": \(regexProtocolName)"
      }
      return result
    }
    let captures = (0..<arity).map { "C\($0)" }.joined(separator: ", ")
    let capturesTupled = arity == 1 ? captures : "Tuple\(arity)<\(captures)>"
    let componentConstraint: String = arity == 0 ? "" :
      "where Component.Match == Tuple\(arity+1)<W, \(captures)>"
    let quantifiedCaptures: String = {
      switch kind {
      case .zeroOrOne:
        return "\(capturesTupled)?"
      case .zeroOrMore, .oneOrMore:
        return "[\(capturesTupled)]"
      }
    }()
    let matchType = arity == 0 ? baseMatchTypeName : "Tuple2<\(baseMatchTypeName), \(quantifiedCaptures)>"
    output("""
      public struct \(kind.typeName)_\(arity)<\(genericParameters(withConstraints: true))>: \(regexProtocolName) \(componentConstraint) {
        public typealias \(matchAssociatedTypeName) = \(matchType)
        public let regex: Regex<\(matchAssociatedTypeName)>
        public init(component: Component) {
          self.regex = .init(node: .quantification(.\(kind.astQuantifierAmount), .eager, component.regex.root))
        }
      }

      \(arity == 0 ? "@_disfavoredOverload" : "")
      public func \(kind.rawValue)<\(genericParameters(withConstraints: true))>(
        _ component: Component
      ) -> \(kind.typeName)_\(arity)<\(genericParameters(withConstraints: false))> {
        .init(component: component)
      }

      \(arity == 0 ? "@_disfavoredOverload" : "")
      public func \(kind.rawValue)<\(genericParameters(withConstraints: true))>(
        @RegexBuilder _ component: () -> Component
      ) -> \(kind.typeName)_\(arity)<\(genericParameters(withConstraints: false))> {
        \(kind.rawValue)(component())
      }

      \(arity == 0 ? "@_disfavoredOverload" : "")
      public postfix func \(kind.operatorName)<\(genericParameters(withConstraints: true))>(
        _ component: Component
      ) -> \(kind.typeName)_\(arity)<\(genericParameters(withConstraints: false))> {
        \(kind.rawValue)(component)
      }

      \(kind == .zeroOrOne ?
        """
        extension RegexBuilder {
          public static func buildLimitedAvailability<\(genericParameters(withConstraints: true))>(
            _ component: Component
          ) -> \(kind.typeName)_\(arity)<\(genericParameters(withConstraints: false))> {
            \(kind.rawValue)(component)
          }
        }
        """ : "")

      """)
  }
}
