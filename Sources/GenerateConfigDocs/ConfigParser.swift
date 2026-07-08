//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import SwiftParser
import SwiftSyntax

// ==== -----------------------------------------------------------------------
// MARK: Parsed model

/// A single case on an enum we care about.
struct EnumCaseInfo {
  var name: String
  /// For raw-value / bare cases: the display string (raw value if present, else the case name).
  var display: String?
  /// For associated-value cases: the parameter clause verbatim (without parens).
  var associatedSignature: String?
  /// Doc-comment paragraph lines (already stripped of `///` prefix).
  var docLines: [String]
}

struct EnumInfo {
  var name: String
  var docLines: [String]
  var cases: [EnumCaseInfo]
  /// The name of the `.<case>` value returned by `public static var \`default\``, if any.
  var defaultCase: String?

  var hasAssociatedValues: Bool {
    cases.contains { $0.associatedSignature != nil }
  }

  /// First paragraph of doc-lines, joined with spaces (blank line ends the paragraph).
  var firstParagraph: String {
    var out: [String] = []
    for l in docLines {
      if l.trimmingCharacters(in: .whitespaces).isEmpty { break }
      out.append(l)
    }
    return out.joined(separator: " ").trimmingCharacters(in: .whitespaces)
  }

  /// Plain / raw-value cases with their first-paragraph docs (associated-value cases skipped).
  var caseDocs: [(display: String, doc: String)] {
    cases.compactMap { c in
      guard c.associatedSignature == nil, let display = c.display else { return nil }
      var first: [String] = []
      for l in c.docLines {
        if l.trimmingCharacters(in: .whitespaces).isEmpty { break }
        first.append(l)
      }
      return (display, first.joined(separator: " ").trimmingCharacters(in: .whitespaces))
    }
  }
}

struct StructPropertyInfo {
  var name: String
  var type: String
  var docLines: [String]
}

struct StructInfo {
  var name: String
  var docLines: [String]
  var properties: [StructPropertyInfo]
}

/// One field on the `Configuration` struct.
struct ConfigField {
  var name: String
  var type: String
  /// The literal RHS of `= <expr>` on the stored-property line, if any (e.g. `nil`, `"[:]"`, `false`).
  var defaultLiteral: String?
  var docLines: [String]
  var section: String
}

// ==== -----------------------------------------------------------------------
// MARK: Trivia helpers

/// Doc-comment paragraph lines pulled off of leading trivia.
///
/// Ignores section markers which start with `// ====`.
func docLines(from trivia: Trivia) -> [String] {
  var out: [String] = []
  for piece in trivia.pieces {
    switch piece {
    case .docLineComment(let raw):
      var text = raw
      if text.hasPrefix("///") { text.removeFirst(3) }
      if text.hasPrefix(" ") { text.removeFirst() }
      out.append(text)

    case .lineComment(let raw):
      // Skip section-divider comments; they're structural, not documentation.
      if sectionName(fromLineComment: raw) != nil { continue }
      var text = raw
      if text.hasPrefix("//") { text.removeFirst(2) }
      if text.hasPrefix(" ") { text.removeFirst() }
      out.append(text)

    case .docBlockComment(let raw):
      // `/** ... */`. Strip the delimiters and split into lines.
      var body = raw
      if body.hasPrefix("/**") { body.removeFirst(3) }
      if body.hasSuffix("*/") { body.removeLast(2) }
      for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
        var t = String(line).trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("*") { t.removeFirst() }
        if t.hasPrefix(" ") { t.removeFirst() }
        out.append(t)
      }

    case .newlines(let n):
      // A blank line (2+ newlines) between comment runs resets the buffer,
      // matching the Python parser's `pending_doc = []` on empty lines.
      if n >= 2 { out.removeAll() }

    case .blockComment:
      // Non-doc block comments (e.g. copyright headers) reset the buffer.
      out.removeAll()

    case _:
      continue

    @unknown default:
      continue
    }
  }
  return out
}

/// The `// ==== <name> ---` divider convention used inside `Configuration`.
/// Returns the section name if the trivia piece is a divider line comment.
func sectionName(fromLineComment raw: String) -> String? {
  // Line-comment form: "// ==== Foo Bar -----"
  var body = raw
  if body.hasPrefix("//") { body.removeFirst(2) }
  body = body.trimmingCharacters(in: .whitespaces)
  guard body.hasPrefix("====") else { return nil }
  body.removeFirst(4)
  // Trim trailing `---...`.
  while body.hasSuffix("-") { body.removeLast() }
  return body.trimmingCharacters(in: .whitespaces).isEmpty
    ? nil
    : body.trimmingCharacters(in: .whitespaces)
}

// ==== -----------------------------------------------------------------------
// MARK: Type shape helpers

/// The inner named type for `T?`, `[T]`, `[K: T]`, or bare `T`; else nil.
func resolveContainerElementType(_ typeRaw: String) -> String? {
  var core = typeRaw.trimmingCharacters(in: .whitespaces)
  while core.hasSuffix("?") { core.removeLast() }
  core = core.trimmingCharacters(in: .whitespaces)

  // [T]
  if core.hasPrefix("["), core.hasSuffix("]"), !core.contains(":") {
    let inner = String(core.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
    return isBareIdentifier(inner) ? inner : nil
  }

  // [K: V]
  if core.hasPrefix("["), core.hasSuffix("]"), let colon = core.firstIndex(of: ":") {
    var value = String(core[core.index(after: colon)..<core.index(before: core.endIndex)])
      .trimmingCharacters(in: .whitespaces)
    while value.hasSuffix("?") { value.removeLast() }
    value = value.trimmingCharacters(in: .whitespaces)
    return isBareIdentifier(value) ? value : nil
  }

  return isBareIdentifier(core) ? core : nil
}

func isBareIdentifier(_ s: String) -> Bool {
  guard !s.isEmpty else { return false }
  return s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
}

// ==== -----------------------------------------------------------------------
// MARK: The parser

struct ConfigParser {
  var enums: [String: EnumInfo] = [:]
  var structs: [String: StructInfo] = [:]

  static func parse(rootDirs: [URL]) throws -> ConfigParser {
    var parser = ConfigParser()
    let fm = FileManager.default
    var files: [URL] = []
    for dir in rootDirs {
      guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { continue }
      for case let url as URL in enumerator {
        if url.pathExtension == "swift" {
          files.append(url)
        }
      }
    }
    files.sort { $0.path < $1.path }
    for file in files {
      let src = try String(contentsOf: file, encoding: .utf8)
      let tree = Parser.parse(source: src)
      parser.ingest(tree)
    }
    return parser
  }

  mutating func ingest(_ tree: SourceFileSyntax) {
    let visitor = TopLevelVisitor(viewMode: .sourceAccurate)
    visitor.walk(tree)
    for (name, info) in visitor.enums {
      enums[name] = info
    }
    for (name, info) in visitor.structs {
      structs[name] = info
    }
    // Apply any `public static var \`default\`: T { .caseName }` assignments now that
    // enums/extensions from this file have been recorded (they may target enums
    // declared in a different file we've already ingested, or in this one).
    for (owner, caseName) in visitor.defaults {
      if var info = enums[owner] {
        info.defaultCase = caseName
        enums[owner] = info
      }
    }
  }
}

// ==== -----------------------------------------------------------------------
// MARK: SwiftSyntax visitor

/// Walks a `SourceFileSyntax` collecting public enum / struct declarations and
/// any `public static var \`default\`` bindings on those types (whether declared
/// inline or in an `extension EnumName { ... }`).
private final class TopLevelVisitor: SyntaxVisitor {
  var enums: [String: EnumInfo] = [:]
  var structs: [String: StructInfo] = [:]
  /// (owner type name, case name) pairs from `public static var \`default\`: T { .case }`.
  var defaults: [(owner: String, caseName: String)] = []

  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
    guard node.modifiers.contains(where: { $0.name.tokenKind == .keyword(.public) }) else {
      return .skipChildren
    }
    let name = node.name.text
    var info = EnumInfo(
      name: name,
      docLines: docLines(from: node.leadingTrivia),
      cases: [],
      defaultCase: nil
    )
    collectEnumMembers(node.memberBlock, into: &info, owner: name)
    enums[name] = info
    return .skipChildren
  }

  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    guard node.modifiers.contains(where: { $0.name.tokenKind == .keyword(.public) }) else {
      return .skipChildren
    }
    let name = node.name.text
    var info = StructInfo(
      name: name,
      docLines: docLines(from: node.leadingTrivia),
      properties: []
    )
    collectStructMembers(node.memberBlock, into: &info)
    structs[name] = info
    return .skipChildren
  }

  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    // Only interested in extensions that add `public static var \`default\``.
    let owner = node.extendedType.trimmedDescription
    for member in node.memberBlock.members {
      if let vd = member.decl.as(VariableDeclSyntax.self),
        let caseName = defaultCaseName(from: vd)
      {
        defaults.append((owner: owner, caseName: caseName))
      }
    }
    return .skipChildren
  }

  private func collectEnumMembers(
    _ block: MemberBlockSyntax,
    into info: inout EnumInfo,
    owner: String
  ) {
    for member in block.members {
      if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
        let docs = docLines(from: caseDecl.leadingTrivia)
        // One `case` decl can list multiple elements (`case a, b`); doc lines
        // apply to all of them.
        for element in caseDecl.elements {
          let caseName = element.name.text.trimmingBackticks()
          if let params = element.parameterClause {
            // Associated-value case.
            let sig = params.parameters.map { $0.trimmedDescription }.joined(separator: ", ")
            info.cases.append(
              EnumCaseInfo(
                name: caseName,
                display: nil,
                associatedSignature: sig,
                docLines: docs
              )
            )
          } else {
            var display = caseName
            if let raw = element.rawValue {
              display = raw.value.trimmedDescription
            }
            info.cases.append(
              EnumCaseInfo(
                name: caseName,
                display: display,
                associatedSignature: nil,
                docLines: docs
              )
            )
          }
        }
      } else if let vd = member.decl.as(VariableDeclSyntax.self),
        let caseName = defaultCaseName(from: vd)
      {
        info.defaultCase = caseName
      }
    }
    _ = owner // silence unused-owner lint in some SwiftSyntax builds
  }

  private func collectStructMembers(
    _ block: MemberBlockSyntax,
    into info: inout StructInfo
  ) {
    for member in block.members {
      guard let vd = member.decl.as(VariableDeclSyntax.self) else { continue }
      // Only `public var name: Type` stored properties (no accessor block).
      guard vd.modifiers.contains(where: { $0.name.tokenKind == .keyword(.public) }) else {
        continue
      }
      guard vd.bindingSpecifier.tokenKind == .keyword(.var) else { continue }
      guard let binding = vd.bindings.first, vd.bindings.count == 1 else { continue }
      guard binding.accessorBlock == nil else { continue }
      guard let ident = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
      guard let typeAnn = binding.typeAnnotation else { continue }
      let name = ident.identifier.text.trimmingBackticks()
      let type = typeAnn.type.trimmedDescription
      info.properties.append(
        StructPropertyInfo(
          name: name,
          type: type,
          docLines: docLines(from: vd.leadingTrivia)
        )
      )
    }
  }

  /// If `vd` is `public static var \`default\`: T { .caseName }` (or `{ return .caseName }`,
  /// or `{ .caseName }` with the trailing whitespace), return `caseName`; else nil.
  private func defaultCaseName(from vd: VariableDeclSyntax) -> String? {
    guard vd.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) else {
      return nil
    }
    guard vd.bindingSpecifier.tokenKind == .keyword(.var) else { return nil }
    guard let binding = vd.bindings.first else { return nil }
    guard let ident = binding.pattern.as(IdentifierPatternSyntax.self) else { return nil }
    guard ident.identifier.text.trimmingBackticks() == "default" else { return nil }
    guard let accessor = binding.accessorBlock else { return nil }

    // Body forms:
    //   `{ .caseName }`             -> AccessorBlockSyntax.accessors == .getter(CodeBlockItemListSyntax)
    //   `{ get { .caseName } }`     -> .accessors(AccessorDeclListSyntax)
    var body: CodeBlockItemListSyntax?
    switch accessor.accessors {
    case .getter(let items):
      body = items
    case .accessors(let list):
      for acc in list where acc.accessorSpecifier.tokenKind == .keyword(.get) {
        body = acc.body?.statements
      }
    }
    guard let statements = body, let first = statements.first else { return nil }
    // Strip an optional leading `return`.
    let expr: ExprSyntax
    if let ret = first.item.as(ReturnStmtSyntax.self), let e = ret.expression {
      expr = e
    } else if let e = first.item.as(ExprSyntax.self) {
      expr = e
    } else {
      return nil
    }
    // Expect `.caseName` (a MemberAccessExprSyntax with no base).
    guard let member = expr.as(MemberAccessExprSyntax.self), member.base == nil else {
      return nil
    }
    return member.declName.baseName.text.trimmingBackticks()
  }
}

/// Walks the `Configuration` struct's members in source order to produce the
/// ordered list of fields (with section headings from `// ==== Name -----`
/// dividers) and the `effective<Foo>` -> fallback map.
struct ConfigurationBody {
  var fields: [ConfigField] = []
  var effectiveFallbacks: [String: String] = [:]

  static func parse(source: String) throws -> ConfigurationBody {
    let tree = Parser.parse(source: source)
    let finder = ConfigStructFinder(viewMode: .sourceAccurate)
    finder.walk(tree)
    guard let decl = finder.decl else {
      throw ConfigDocsError(
        "Could not find 'public struct Configuration' in the config source"
      )
    }
    var body = ConfigurationBody()
    var currentSection = "General"
    var pendingDoc: [String] = []

    for member in decl.memberBlock.members {
      // Any `// ==== Name ----` line comment in the leading trivia of a member
      // resets the current section.
      for piece in member.leadingTrivia.pieces {
        if case .lineComment(let raw) = piece, let name = sectionName(fromLineComment: raw) {
          currentSection = name
          pendingDoc = []
        }
      }

      // Collect doc-lines from the member's leading trivia.
      let docs = docLines(from: member.leadingTrivia)
      if !docs.isEmpty {
        pendingDoc = docs
      }

      guard let vd = member.decl.as(VariableDeclSyntax.self) else {
        // Functions and other members reset the pending doc buffer to mirror
        // the Python parser (which drops docs on non-property members).
        pendingDoc = []
        continue
      }
      guard vd.modifiers.contains(where: { $0.name.tokenKind == .keyword(.public) }) else {
        pendingDoc = []
        continue
      }
      guard vd.bindingSpecifier.tokenKind == .keyword(.var) else {
        pendingDoc = []
        continue
      }
      guard let binding = vd.bindings.first, vd.bindings.count == 1 else {
        pendingDoc = []
        continue
      }
      guard let ident = binding.pattern.as(IdentifierPatternSyntax.self) else {
        pendingDoc = []
        continue
      }
      guard let typeAnn = binding.typeAnnotation else {
        pendingDoc = []
        continue
      }
      let name = ident.identifier.text.trimmingBackticks()
      let type = typeAnn.type.trimmedDescription

      if let accessor = binding.accessorBlock {
        // Computed property. Detect `effective<Foo>` and extract the `?? <fallback>` RHS.
        if name.hasPrefix("effective"),
          let fallback = nilCoalescingFallback(in: accessor)
        {
          let suffix = String(name.dropFirst("effective".count))
          guard let firstChar = suffix.first else {
            pendingDoc = []
            continue
          }
          let underlying = String(firstChar).lowercased() + suffix.dropFirst()
          body.effectiveFallbacks[underlying] = fallback
        }
        pendingDoc = []
        continue
      }

      // Stored property. Record the field.
      let defaultLit = binding.initializer.map { init_ in
        init_.value.trimmedDescription.trimmingCharacters(in: .whitespaces)
      }
      body.fields.append(
        ConfigField(
          name: name,
          type: type,
          defaultLiteral: defaultLit,
          docLines: pendingDoc,
          section: currentSection
        )
      )
      pendingDoc = []
    }
    return body
  }
}

private final class ConfigStructFinder: SyntaxVisitor {
  var decl: StructDeclSyntax?
  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    if node.name.text == "Configuration" {
      decl = node
      return .skipChildren
    }
    return .visitChildren
  }
}

/// Given the accessor block of `effective<Foo>: T { <stmts> }`, if the body is
/// a single `?? <fallback>` expression (optionally with a `return`), return the
/// textual RHS (e.g. `.default`, `false`, `.public`). Otherwise nil.
private func nilCoalescingFallback(in accessor: AccessorBlockSyntax) -> String? {
  let stmts: CodeBlockItemListSyntax?
  switch accessor.accessors {
  case .getter(let items):
    stmts = items
  case .accessors(let list):
    stmts =
      list.first(where: { $0.accessorSpecifier.tokenKind == .keyword(.get) })?
      .body?.statements
  }
  guard let statements = stmts, let first = statements.first else { return nil }

  var expr: ExprSyntax?
  if let ret = first.item.as(ReturnStmtSyntax.self) {
    expr = ret.expression
  } else if let e = first.item.as(ExprSyntax.self) {
    expr = e
  }
  guard let expression = expr else { return nil }

  // `a ?? b` parses as SequenceExpr(a, ??, b) *before* folding, or as
  // InfixOperatorExpr(a, ??, b) after folding.
  if let seq = expression.as(SequenceExprSyntax.self) {
    let elements = Array(seq.elements)
    for i in stride(from: 0, to: elements.count - 2, by: 2) {
      if let op = elements[i + 1].as(BinaryOperatorExprSyntax.self),
        op.operator.text == "??"
      {
        return elements[i + 2].trimmedDescription
      }
    }
  }
  if let infix = expression.as(InfixOperatorExprSyntax.self),
    let op = infix.operator.as(BinaryOperatorExprSyntax.self),
    op.operator.text == "??"
  {
    return infix.rightOperand.trimmedDescription
  }
  return nil
}

// ==== -----------------------------------------------------------------------
// MARK: Errors

struct ConfigDocsError: Error, CustomStringConvertible {
  let message: String
  init(_ message: String) { self.message = message }
  var description: String { message }
}

// ==== -----------------------------------------------------------------------
// MARK: Small string helpers

extension String {
  fileprivate func trimmingBackticks() -> String {
    var s = self
    if s.hasPrefix("`") { s.removeFirst() }
    if s.hasSuffix("`") { s.removeLast() }
    return s
  }
}

extension Substring {
  fileprivate func trimmingBackticks() -> String {
    String(self).trimmingBackticks()
  }
}
