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

@preconcurrency internal import Dispatch

extension SequenceOutput {
    /// A immutable collection of bytes
    public struct Buffer: Sendable {
        #if os(Windows)
        private var data: [UInt8]

        internal init(data: [UInt8]) {
            self.data = data
        }
        #else
        private var data: DispatchData

        internal init(data: DispatchData) {
            self.data = data
        }
        #endif
    }
}

// MARK: - Properties
extension SequenceOutput.Buffer {
    /// Number of bytes stored in the buffer
    public var count: Int {
        return self.data.count
    }

    /// A Boolean value indicating whether the collection is empty.
    public var isEmpty: Bool {
        return self.data.isEmpty
    }
}

// MARK: - Accessors
extension SequenceOutput.Buffer {
    #if !SubprocessSpan
    /// Access the raw bytes stored in this buffer
    /// - Parameter body: A closure with an `UnsafeRawBufferPointer` parameter that
    ///   points to the contiguous storage for the type. If no such storage exists,
    ///   the method creates it. If body has a return value, this method also returns
    ///   that value. The argument is valid only for the duration of the
    ///   closure’s SequenceOutput.
    /// - Returns: The return value, if any, of the body closure parameter.
    public func withUnsafeBytes<ResultType>(
        _ body: (UnsafeRawBufferPointer) throws -> ResultType
    ) rethrows -> ResultType {
        return try self._withUnsafeBytes(body)
    }
    #endif  // !SubprocessSpan

    internal func _withUnsafeBytes<ResultType>(
        _ body: (UnsafeRawBufferPointer) throws -> ResultType
    ) rethrows -> ResultType {
        #if os(Windows)
        return try self.data.withUnsafeBytes(body)
        #else
        // Although DispatchData was designed to be uncontiguous, in practice
        // we found that almost all DispatchData are contiguous. Therefore
        // we can access this body in O(1) most of the time.
        return try self.data.withUnsafeBytes { ptr in
            let bytes = UnsafeRawBufferPointer(start: ptr, count: self.data.count)
            return try body(bytes)
        }
        #endif
    }

    private enum SpanBacking {
        case pointer(UnsafeBufferPointer<UInt8>)
        case array([UInt8])
    }
}

// MARK: - Hashable, Equatable
extension SequenceOutput.Buffer: Equatable, Hashable {
    #if os(Windows)
    // Compiler generated conformances
    #else
    public static func == (lhs: SequenceOutput.Buffer, rhs: SequenceOutput.Buffer) -> Bool {
        return lhs.data.elementsEqual(rhs.data)
    }

    public func hash(into hasher: inout Hasher) {
        self.data.withUnsafeBytes { ptr in
            let bytes = UnsafeRawBufferPointer(
                start: ptr,
                count: self.data.count
            )
            hasher.combine(bytes: bytes)
        }
    }
    #endif
}
