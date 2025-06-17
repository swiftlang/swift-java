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
#endif  // canImport(Darwin)

#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

internal import Dispatch

/// A concrete `Input` type for subprocesses that reads input
/// from a given `Data`.
public struct DataInput: InputProtocol {
    private let data: Data

    public func write(with writer: StandardInputWriter) async throws {
        _ = try await writer.write(self.data)
    }

    internal init(data: Data) {
        self.data = data
    }
}

/// A concrete `Input` type for subprocesses that accepts input
/// from a specified sequence of `Data`.
public struct DataSequenceInput<
    InputSequence: Sequence & Sendable
>: InputProtocol where InputSequence.Element == Data {
    private let sequence: InputSequence

    public func write(with writer: StandardInputWriter) async throws {
        var buffer = Data()
        for chunk in self.sequence {
            buffer.append(chunk)
        }
        _ = try await writer.write(buffer)
    }

    internal init(underlying: InputSequence) {
        self.sequence = underlying
    }
}

/// A concrete `Input` type for subprocesses that reads input
/// from a given async sequence of `Data`.
public struct DataAsyncSequenceInput<
    InputSequence: AsyncSequence & Sendable
>: InputProtocol where InputSequence.Element == Data {
    private let sequence: InputSequence

    private func writeChunk(_ chunk: Data, with writer: StandardInputWriter) async throws {
        _ = try await writer.write(chunk)
    }

    public func write(with writer: StandardInputWriter) async throws {
        for try await chunk in self.sequence {
            try await self.writeChunk(chunk, with: writer)
        }
    }

    internal init(underlying: InputSequence) {
        self.sequence = underlying
    }
}

extension InputProtocol {
    /// Create a Subprocess input from a `Data`
    public static func data(_ data: Data) -> Self where Self == DataInput {
        return DataInput(data: data)
    }

    /// Create a Subprocess input from a `Sequence` of `Data`.
    public static func sequence<InputSequence: Sequence & Sendable>(
        _ sequence: InputSequence
    ) -> Self where Self == DataSequenceInput<InputSequence> {
        return .init(underlying: sequence)
    }

    /// Create a Subprocess input from a `AsyncSequence` of `Data`.
    public static func sequence<InputSequence: AsyncSequence & Sendable>(
        _ asyncSequence: InputSequence
    ) -> Self where Self == DataAsyncSequenceInput<InputSequence> {
        return .init(underlying: asyncSequence)
    }
}

extension StandardInputWriter {
    /// Write a `Data` to the standard input of the subprocess.
    /// - Parameter data: The sequence of bytes to write.
    /// - Returns number of bytes written.
    public func write(
        _ data: Data
    ) async throws -> Int {
        return try await self.fileDescriptor.wrapped.write(data)
    }

    /// Write a AsyncSequence of Data to the standard input of the subprocess.
    /// - Parameter sequence: The sequence of bytes to write.
    /// - Returns number of bytes written.
    public func write<AsyncSendableSequence: AsyncSequence & Sendable>(
        _ asyncSequence: AsyncSendableSequence
    ) async throws -> Int where AsyncSendableSequence.Element == Data {
        var buffer = Data()
        for try await data in asyncSequence {
            buffer.append(data)
        }
        return try await self.write(buffer)
    }
}

extension FileDescriptor {
    #if os(Windows)
    internal func write(
        _ data: Data
    ) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            // TODO: Figure out a better way to asynchornously write
            DispatchQueue.global(qos: .userInitiated).async {
                data.withUnsafeBytes {
                    self.write($0) { writtenLength, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: writtenLength)
                        }
                    }
                }
            }
        }
    }
    #else
    internal func write(
        _ data: Data
    ) async throws -> Int {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, any Error>) in
            let dispatchData = data.withUnsafeBytes {
                return DispatchData(
                    bytesNoCopy: $0,
                    deallocator: .custom(
                        nil,
                        {
                            // noop
                        }
                    )
                )
            }
            self.write(dispatchData) { writtenLength, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: writtenLength)
                }
            }
        }
    }
    #endif
}

#endif  // SubprocessFoundation
