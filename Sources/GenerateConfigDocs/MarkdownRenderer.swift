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

/// Renders the parsed configuration model to the same Markdown shape the
/// previous Python generator produced, so the two can be diffed byte-for-byte
/// during the port and the DocC output stays unchanged.
struct MarkdownRenderer {
  var enums: [String: EnumInfo]
  var structs: [String: StructInfo]
  var fields: [ConfigField]
  var effectiveFallbacks: [String: String]

  func render() -> String {
    var seen: [String: [ConfigField]] = [:]
    var sectionOrder: [String] = []
    for field in fields {
      if seen[field.section] == nil { sectionOrder.append(field.section) }
      seen[field.section, default: []].append(field)
    }

    var out: [String] = []
    for section in sectionOrder {
      out.append("### \(section)")
      out.append("")
      for field in seen[section] ?? [] {
        out.append(renderField(field))
        out.append("")
      }
    }
    // Trim trailing whitespace-only lines, keep a single trailing newline.
    var joined = out.joined(separator: "\n")
    while joined.hasSuffix("\n") || joined.hasSuffix(" ") {
      joined.removeLast()
    }
    return joined + "\n"
  }

  private func renderField(_ field: ConfigField) -> String {
    let typeClean = field.type.trimmingCharacters(in: .whitespaces).trimmingSuffix("?")
    let isBareEnum = isBareIdentifier(typeClean) && enums[typeClean] != nil
    let enumInfo = isBareEnum ? enums[typeClean] : nil

    var lines: [String] = []
    lines.append("#### \(field.name)")
    lines.append("")

    lines.append("- **Type:** `\(field.type)`")

    var defaultDisplay = literalDisplay(field.defaultLiteral)
    if defaultDisplay == nil, let fallback = effectiveFallbacks[field.name] {
      if fallback == ".default", let ei = enumInfo, let defaultCase = ei.defaultCase {
        defaultDisplay = "`\(resolveDefaultDisplay(ei, defaultCase))`"
      } else if fallback.hasPrefix(".") {
        defaultDisplay = "`\(fallback.dropFirst())`"
      } else {
        defaultDisplay = "`\(fallback)`"
      }
    }
    if let display = defaultDisplay {
      lines.append("- **Default:** \(display)")
    }

    lines.append("")

    if !field.docLines.isEmpty {
      lines.append(contentsOf: field.docLines)
    } else if let ei = enumInfo, !ei.firstParagraph.isEmpty {
      lines.append(ei.firstParagraph)
    } else {
      lines.append(
        "_Undocumented - please add a doc comment on this property in `Configuration.swift`._"
      )
    }

    if let ei = enumInfo, !ei.hasAssociatedValues {
      let docs = ei.caseDocs
      if !docs.isEmpty {
        lines.append("")
        lines.append("**Values:**")
        lines.append("")
        for (display, doc) in docs {
          if doc.isEmpty {
            lines.append("- `\(display)`")
          } else {
            lines.append("- `\(display)` - \(doc)")
          }
        }
      }
    }

    if let elementType = resolveContainerElementType(field.type), elementType != typeClean {
      if structs[elementType] != nil
        || (enums[elementType]?.hasAssociatedValues == true)
      {
        lines.append("")
        lines.append(contentsOf: renderTypeSchemaLines(elementType))
      }
    }

    lines.append("")
    lines.append("---")
    return lines.joined(separator: "\n")
  }

  private func renderTypeSchemaLines(_ name: String) -> [String] {
    var lines: [String] = ["**`\(name)`:**", ""]
    if let s = structs[name] {
      if !s.docLines.isEmpty {
        lines.append(contentsOf: s.docLines)
        lines.append("")
      }
      for prop in s.properties {
        let doc = prop.docLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if doc.isEmpty {
          lines.append("- `\(prop.name)`: `\(prop.type)`")
        } else {
          lines.append("- `\(prop.name)`: `\(prop.type)` - \(doc)")
        }
      }
    } else if let e = enums[name] {
      if !e.docLines.isEmpty {
        lines.append(contentsOf: e.docLines)
        lines.append("")
      }
      if e.hasAssociatedValues {
        var caseLines: [String] = []
        for c in e.cases {
          let doc = c.docLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
          if doc.isEmpty { continue }
          let label: String
          if let sig = c.associatedSignature {
            label = "\(c.name)(\(sig))"
          } else {
            label = c.name
          }
          caseLines.append("- `\(label)` - \(doc)")
        }
        if caseLines.isEmpty && e.docLines.isEmpty {
          for c in e.cases {
            let label: String
            if let sig = c.associatedSignature {
              label = "\(c.name)(\(sig))"
            } else {
              label = c.name
            }
            caseLines.append("- `\(label)`")
          }
        }
        lines.append(contentsOf: caseLines)
      } else {
        for (display, doc) in e.caseDocs {
          if doc.isEmpty {
            lines.append("- `\(display)`")
          } else {
            lines.append("- `\(display)` - \(doc)")
          }
        }
      }
    }
    return lines
  }

  private func resolveDefaultDisplay(_ enumInfo: EnumInfo, _ caseName: String) -> String {
    for c in enumInfo.cases where c.name == caseName {
      return c.display ?? caseName
    }
    return caseName
  }

  private func literalDisplay(_ literal: String?) -> String? {
    guard let raw = literal else { return nil }
    if raw == "nil" { return nil }
    if raw == "[:]" { return "empty dictionary (`[:]`)" }
    if raw == "[]" { return "empty array (`[]`)" }
    return "`\(raw)`"
  }
}

extension String {
  fileprivate func trimmingSuffix(_ s: Character) -> String {
    var r = self
    while r.hasSuffix(String(s)) { r.removeLast() }
    return r.trimmingCharacters(in: .whitespaces)
  }
}
