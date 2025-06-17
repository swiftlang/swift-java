//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if SubprocessFoundation

#if canImport(Darwin)
// On Darwin always prefer system Foundation
import Foundation
#else
// On other platforms prefer FoundationEssentials
import FoundationEssentials
#endif

/// A concrete `Output` type for subprocesses that collects output
/// from the subprocess as `Data`. This option must be used with
/// the `run()` method that returns a `CollectedResult`
public struct DataOutput: OutputProtocol {
    public typealias OutputType = Data
    public let maxSize: Int

    public func output(from buffer: some Sequence<UInt8>) throws -> Data {
        return Data(buffer)
    }

    internal init(limit: Int) {
        self.maxSize = limit
    }
}

extension OutputProtocol where Self == DataOutput {
    /// Create a `Subprocess` output that collects output as `Data`
    /// up to 128kb.
    public static var data: Self {
        return .data(limit: 128 * 1024)
    }

    /// Create a `Subprocess` output that collects output as `Data`
    /// with given max number of bytes to collect.
    public static func data(limit: Int) -> Self {
        return .init(limit: limit)
    }
}


#endif  // SubprocessFoundation
