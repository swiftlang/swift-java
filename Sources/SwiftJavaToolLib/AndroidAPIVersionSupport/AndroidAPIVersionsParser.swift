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
import Logging

#if canImport(FoundationXML)
import FoundationXML
#endif

/// Parses an Android `api-versions.xml` file (format version 3) into an ``AndroidAPIVersions``.

public final class AndroidAPIVersionsParser: _AndroidAPIVersionsParserBase, XMLParserDelegate {
  private var result = AndroidAPIVersions()
  private var currentClassName: String?
  private var currentClassSince: AndroidAPILevel?
  private var parseError: Error?

  private let log: Logger

  private init(log: Logger) {
    self.log = log
    super.init()
  }

  /// Parse an `api-versions.xml` file from the given URL.
  package static func parse(contentsOf url: URL, log: Logger = .noop) throws -> AndroidAPIVersions {
    let data = try Data(contentsOf: url)
    return try parse(data: data, log: log)
  }

  /// Parse `api-versions.xml` from in-memory data.
  package static func parse(data: Data, log: Logger = .noop) throws -> AndroidAPIVersions {
    let handler = AndroidAPIVersionsParser(log: log)
    let parser = XMLParser(data: data)
    parser.delegate = handler
    guard parser.parse() else {
      if let error = handler.parseError {
        throw error
      }
      throw parser.parserError ?? AndroidAPIVersionsParserError.unknownParseError
    }
    if let error = handler.parseError {
      throw error
    }
    return handler.result
  }

  /// Parse `api-versions.xml` from a string.
  package static func parse(string: String, log: Logger = .noop) throws -> AndroidAPIVersions {
    let data = Data(string.utf8)
    return try parse(data: data, log: log)
  }

  // ===== ------------------------------------------------------------------------
  // MARK: - XMLParserDelegate

  public func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName: String?,
    attributes attrs: [String: String]
  ) {
    switch elementName {
    case "api": parseAPI(attrs: attrs)
    case "class": parseClass(attrs: attrs)
    case "method": parseMethod(attrs: attrs)
    case "field": parseField(attrs: attrs)
    default: break // ignore <sdk>, <extends>, <implements>, etc.
    }
  }

  private func parseAPI(attrs: [String: String]) {
    if let versionStr = attrs["version"], versionStr != "3" {
      log.warning("api-versions.xml has version '\(versionStr)', expected '3'. Parsing may be incomplete.")
    }
  }

  private func parseClass(attrs: [String: String]) {
    guard let name = attrs["name"] else { return }
    let dotName = name.replacing("/", with: ".")
    currentClassName = dotName
    let since = AndroidAPILevel(attrs["since"])
    currentClassSince = since
    let info = AndroidAPIAvailability(
      since: since,
      removed: AndroidAPILevel(attrs["removed"]),
      deprecated: AndroidAPILevel(attrs["deprecated"])
    )
    result.classVersions[dotName] = info
  }

  private func parseMethod(attrs: [String: String]) {
    guard let className = currentClassName,
      let name = attrs["name"]
    else { return }
    let info = AndroidAPIAvailability(
      since: AndroidAPILevel(attrs["since"]) ?? currentClassSince,
      removed: AndroidAPILevel(attrs["removed"]),
      deprecated: AndroidAPILevel(attrs["deprecated"])
    )
    result.methodVersions[className, default: [:]][name] = info
  }

  private func parseField(attrs: [String: String]) {
    guard let className = currentClassName,
      let name = attrs["name"]
    else { return }
    let info = AndroidAPIAvailability(
      since: AndroidAPILevel(attrs["since"]) ?? currentClassSince,
      removed: AndroidAPILevel(attrs["removed"]),
      deprecated: AndroidAPILevel(attrs["deprecated"])
    )
    result.fieldVersions[className, default: [:]][name] = info
  }

  public func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName: String?
  ) {
    if elementName == "class" {
      currentClassName = nil
      currentClassSince = nil
    }
  }

  public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
    self.parseError = parseError
  }
}

// ===== ------------------------------------------------------------------------
// MARK: - Errors

public enum AndroidAPIVersionsParserError: Error, CustomStringConvertible {
  case unknownParseError

  public var description: String {
    switch self {
    case .unknownParseError:
      "Unknown error parsing api-versions.xml"
    }
  }
}

// ===== ------------------------------------------------------------------------
// MARK: - Platform base class

/// On Apple platforms `XMLParserDelegate` is an `@objc` protocol, so the class
/// inherits from `NSObject`.  On Linux (swift-corelibs-foundation) the protocol
/// is a plain Swift protocol and no base class is needed.
#if canImport(ObjectiveC)
public class _AndroidAPIVersionsParserBase: NSObject {}
#else
public class _AndroidAPIVersionsParserBase {}
#endif

// ===== ------------------------------------------------------------------------
// MARK: - Logger extensions

extension Logger {
  /// A logger that silently discards all log messages.
  public static var noop: Logger {
    Logger(label: "noop", factory: { _ in SwiftLogNoOpLogHandler() })
  }
}
