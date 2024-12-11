//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import SystemPackage
import Dispatch

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

extension Subprocess {
    public struct AsyncDataSequence: AsyncSequence, Sendable, _AsyncSequence {
        public typealias Error = any Swift.Error

        public typealias Element = Data

        @_nonSendable
        public struct Iterator: AsyncIteratorProtocol {
            public typealias Element = Data

            private let fileDescriptor: FileDescriptor
            private var buffer: [UInt8]
            private var currentPosition: Int
            private var finished: Bool

            internal init(fileDescriptor: FileDescriptor) {
                self.fileDescriptor = fileDescriptor
                self.buffer = []
                self.currentPosition = 0
                self.finished = false
            }

            public mutating func next() async throws -> Data? {
                let data = try await self.fileDescriptor.readChunk(
                    upToLength: Subprocess.readBufferSize
                )
                if data == nil {
                    // We finished reading. Close the file descriptor now
                    try self.fileDescriptor.close()
                    return nil
                }
                return data
            }
        }

        private let fileDescriptor: FileDescriptor

        init(fileDescriptor: FileDescriptor) {
            self.fileDescriptor = fileDescriptor
        }

        public func makeAsyncIterator() -> Iterator {
            return Iterator(fileDescriptor: self.fileDescriptor)
        }
    }
}

extension RangeReplaceableCollection {
    /// Creates a new instance of a collection containing the elements of an asynchronous sequence.
    ///
    /// - Parameter source: The asynchronous sequence of elements for the new collection.
    @inlinable
    public init<Source: AsyncSequence>(_ source: Source) async rethrows where Source.Element == Element {
        self.init()
        for try await item in source {
            append(item)
        }
    }
}

public protocol _AsyncSequence<Element, Error>: AsyncSequence {
    associatedtype Error
}
