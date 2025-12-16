import Foundation
import SwiftSyntax

struct SwiftDocumentation: Equatable {
  struct Parameter: Equatable {
    var name: String
    var description: String
  }

  var summary: String?
  var discussion: String?
  var parameters: [Parameter] = []
  var returns: String?
}

enum SwiftDocumentationParser {
  private enum State {
    case summary
    case discussion
    case parameter(Int)
    case returns
  }

  // Capture Groups: 1=Tag, 2=Arg(Optional), 3=Description
  private static let tagRegex = try! NSRegularExpression(pattern: "^-\\s*(\\w+)(?:\\s+([^:]+))?\\s*:\\s*(.*)$")

  static func parse(_ syntax: some SyntaxProtocol) -> SwiftDocumentation? {
    // We must have at least one docline and newline, for this to be valid
    guard syntax.leadingTrivia.count >= 2 else { return nil }

    var comments = [String]()
    var pieces = syntax.leadingTrivia.pieces

    // We always expect a newline follows a docline comment
    while case .newlines(1) = pieces.popLast(), case .docLineComment(let text) = pieces.popLast() {
      comments.append(text)
    }

    guard !comments.isEmpty else { return nil }

    return parse(comments.reversed())
  }

  private static func parse(_ doclines: [String]) -> SwiftDocumentation? {
    var doc = SwiftDocumentation()
    var state: State = .summary

    let lines = doclines.map { line -> String in
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      return trimmed.hasPrefix("///") ? String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces) : trimmed
    }

    // If no lines or all empty, we don't have any documentation.
    if lines.isEmpty || lines.allSatisfy(\.isEmpty) {
      return nil
    }

    for line in lines {
      if line.starts(with: "-"), let (tag, arg, content) = Self.parseTagHeader(line) {
        switch tag.lowercased() {
        case "parameter":
          guard let arg else { continue }
          doc.parameters.append(
            SwiftDocumentation.Parameter(
              name: arg,
              description: content
            )
          )
          state = .parameter(doc.parameters.count > 0 ? doc.parameters.count : 0)

        case "parameters":
          state = .parameter(0)

        case "returns":
          doc.returns = content
          state = .returns

        default:
          // Parameter names are marked like
          // - myString: description
          if case .parameter = state {
            state = .parameter(doc.parameters.count > 0 ? doc.parameters.count : 0)

            doc.parameters.append(
              SwiftDocumentation.Parameter(
                name: tag,
                description: content
              )
            )
          } else {
            state = .discussion
            append(&doc.discussion, line)
          }
        }
      } else if line.isEmpty {
        // Any blank lines will move us to discussion
        state = .discussion
        if let discussion = doc.discussion, !discussion.isEmpty {
          if !discussion.hasSuffix("\n\n") {
            doc.discussion?.append("\n\n")
          }
        }
      } else {
        appendLineToState(state, line: line, doc: &doc)
      }
    }

    // Remove any trailing newlines in discussion
    while doc.discussion?.last == "\n" {
      doc.discussion?.removeLast()
    }

    return doc
  }

  /// This is a test
  private static func appendLineToState(_ state: State, line: String, doc: inout SwiftDocumentation) {
    switch state {
    case .summary: append(&doc.summary, line)
    case .discussion: append(&doc.discussion, line)
    case .returns: append(&doc.returns, line)
    case .parameter(let index):
      if index < doc.parameters.count {
        append(&doc.parameters[index].description, line)
      }
    }
  }

  private static func append(_ existing: inout String, _ new: String) {
    let separator = existing.last == "\n" ? "" : " "
    existing += separator + new
  }

  private static func append(_ existing: inout String?, _ new: String) {
    if existing == nil { existing = new }
    else {
      let separator = existing?.last == "\n" ? "" : " "
      existing! += separator + new
    }
  }

  private static func parseTagHeader(_ line: String) -> (type: String, arg: String?, description: String)? {
    let range = NSRange(location: 0, length: line.utf16.count)
    guard let match = Self.tagRegex.firstMatch(in: line, options: [], range: range) else { return nil }

    // Group 1: Tag Name
    guard let typeRange = Range(match.range(at: 1), in: line) else { return nil }
    let type = String(line[typeRange])

    // Group 2: Argument (Optional)
    var arg: String? = nil
    let argRangeNs = match.range(at: 2)
    if argRangeNs.location != NSNotFound, let argRange = Range(argRangeNs, in: line) {
      arg = String(line[argRange])
    }

    // Group 3: Description (Always present, potentially empty)
    guard let descRange = Range(match.range(at: 3), in: line) else { return nil }
    let description = String(line[descRange])

    return (type, arg, description)
  }
}
