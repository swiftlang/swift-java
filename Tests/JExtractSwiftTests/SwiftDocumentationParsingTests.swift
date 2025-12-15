//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import JExtractSwiftLib
import Testing

struct SwiftDocumentationParsingTests {
  @Test
  func simple() throws {
    assert(
      parsing:
        """
        /// Simple summary
        """,
      as: SwiftDocumentation(summary: "Simple summary")
    )
  }

  @Test
  func full_individualParameters() throws {
    assert(
      parsing:
        """
        /// Simple summary
        /// 
        /// Some information about this function
        /// that will span multiple lines
        /// 
        /// - Parameter arg0: Description about arg0
        /// - Parameter arg1: Description about arg1
        /// 
        /// - Returns: return value
        """,
      as: SwiftDocumentation(
        summary: "Simple summary",
        discussion: "Some information about this function that will span multiple lines",
        parameters: [
          .init(
            name: "arg0",
            description: "Description about arg0"
          ),
          .init(
            name: "arg1",
            description: "Description about arg1"
          )
        ],
        returns: "return value"
      )
    )
  }

  @Test
  func full_groupedParameters() throws {
    assert(
      parsing:
        """
        /// Simple summary
        /// 
        /// Some information about this function
        /// that will span multiple lines
        /// 
        /// - Parameters:
        ///   - arg0: Description about arg0
        ///   - arg1: Description about arg1
        /// 
        /// - Returns: return value
        """,
      as: SwiftDocumentation(
        summary: "Simple summary",
        discussion: "Some information about this function that will span multiple lines",
        parameters: [
          .init(
            name: "arg0",
            description: "Description about arg0"
          ),
          .init(
            name: "arg1",
            description: "Description about arg1"
          )
        ],
        returns: "return value"
      )
    )
  }

  @Test
  func complex_groupedParameters() throws {
    assert(
      parsing:
        """
        /// Simple summary, that we have broken
        /// across multiple lines
        /// 
        /// Some information about this function
        /// that will span multiple lines
        ///
        /// Some more disucssion...
        /// 
        /// - Parameters:
        ///   - arg0: Description about arg0
        ///           that spans multiple lines
        ///   - arg1: Description about arg1
        ///           that spans multiple lines
        ///           and even more?
        ///
        /// And more...
        /// 
        /// - Returns: return value
        ///            across multiple lines
        """,
      as: SwiftDocumentation(
        summary: "Simple summary, that we have broken across multiple lines",
        discussion:
          """
          Some information about this function that will span multiple lines
          
          Some more disucssion...
          
          And more...
          """,
        parameters: [
          .init(
            name: "arg0",
            description: "Description about arg0 that spans multiple lines"
          ),
          .init(
            name: "arg1",
            description: "Description about arg1 that spans multiple lines and even more?"
          )
        ],
        returns: "return value across multiple lines"
      )
    )
  }

  @Test
  func randomly_placed() throws {
    assert(
      parsing:
        """
        /// - Parameter arg0: this is arg0
        /// - Returns: return value
        /// - Parameter arg1: this is arg1
        ///
        /// Discussion? 
        """,
      as: SwiftDocumentation(
        summary: nil,
        discussion: "Discussion?",
        parameters: [
          .init(
            name: "arg0",
            description: "this is arg0"
          ),
          .init(
            name: "arg1",
            description: "this is arg1"
          )
        ],
        returns: "return value"
      )
    )
  }

  private func assert(
    parsing input: String,
    as expectedOutput: SwiftDocumentation,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let result = SwiftDocumentationParser.parse(input)
    #expect(
      result == expectedOutput,
      sourceLocation: sourceLocation
    )
  }
}
