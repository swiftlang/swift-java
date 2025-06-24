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

#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif
internal import Dispatch

// MARK: - Output

/// `OutputProtocol` specifies the set of methods that a type
/// must implement to serve as the output target for a subprocess.
/// Instead of developing custom implementations of `OutputProtocol`,
/// it is recommended to utilize the default implementations provided
/// by the `Subprocess` library to specify the output handling requirements.
public protocol OutputProtocol: Sendable, ~Copyable {
    associatedtype OutputType: Sendable

    /// Convert the output from buffer to expected output type
    func output(from buffer: some Sequence<UInt8>) throws -> OutputType

    /// The max amount of data to collect for this output.
    var maxSize: Int { get }
}

extension OutputProtocol {
    /// The max amount of data to collect for this output.
    public var maxSize: Int { 128 * 1024 }
}

/// A concrete `Output` type for subprocesses that indicates that
/// the `Subprocess` should not collect or redirect output
/// from the child process. On Unix-like systems, `DiscardedOutput`
/// redirects the standard output of the subprocess to `/dev/null`,
/// while on Windows, it does not bind any file handle to the
/// subprocess standard output handle.
public struct DiscardedOutput: OutputProtocol {
    public typealias OutputType = Void

    internal func createPipe() throws -> CreatedPipe {
        #if os(Windows)
        // On Windows, instead of binding to dev null,
        // we don't set the input handle in the `STARTUPINFOW`
        // to signal no output
        return CreatedPipe(
            readFileDescriptor: nil,
            writeFileDescriptor: nil
        )
        #else
        let devnull: FileDescriptor = try .openDevNull(withAcessMode: .readOnly)
        return CreatedPipe(
            readFileDescriptor: .init(devnull, closeWhenDone: true),
            writeFileDescriptor: nil
        )
        #endif
    }

    internal init() {}
}

/// A concrete `Output` type for subprocesses that
/// writes output to a specified `FileDescriptor`.
/// Developers have the option to instruct the `Subprocess` to
/// automatically close the provided `FileDescriptor`
/// after the subprocess is spawned.
public struct FileDescriptorOutput: OutputProtocol {
    public typealias OutputType = Void

    private let closeAfterSpawningProcess: Bool
    private let fileDescriptor: FileDescriptor

    internal func createPipe() throws -> CreatedPipe {
        return CreatedPipe(
            readFileDescriptor: nil,
            writeFileDescriptor: .init(
                self.fileDescriptor,
                closeWhenDone: self.closeAfterSpawningProcess
            )
        )
    }

    internal init(
        fileDescriptor: FileDescriptor,
        closeAfterSpawningProcess: Bool
    ) {
        self.fileDescriptor = fileDescriptor
        self.closeAfterSpawningProcess = closeAfterSpawningProcess
    }
}

/// A concrete `Output` type for subprocesses that collects output
/// from the subprocess as `String` with the given encoding.
/// This option must be used with he `run()` method that
/// returns a `CollectedResult`.
public struct StringOutput<Encoding: Unicode.Encoding>: OutputProtocol {
    public typealias OutputType = String?
    public let maxSize: Int
    private let encoding: Encoding.Type

    public func output(from buffer: some Sequence<UInt8>) throws -> String? {
        // FIXME: Span to String
        let array = Array(buffer)
        return String(decodingBytes: array, as: Encoding.self)
    }

    internal init(limit: Int, encoding: Encoding.Type) {
        self.maxSize = limit
        self.encoding = encoding
    }
}

/// A concrete `Output` type for subprocesses that collects output
/// from the subprocess as `[UInt8]`. This option must be used with
/// the `run()` method that returns a `CollectedResult`
public struct BytesOutput: OutputProtocol {
    public typealias OutputType = [UInt8]
    public let maxSize: Int

    internal func captureOutput(from fileDescriptor: TrackedFileDescriptor?) async throws -> [UInt8] {
        return try await withCheckedThrowingContinuation { continuation in
            guard let fileDescriptor = fileDescriptor else {
                // Show not happen due to type system constraints
                fatalError("Trying to capture output without file descriptor")
            }
            fileDescriptor.wrapped.readUntilEOF(upToLength: self.maxSize) { result in
                switch result {
                case .success(let data):
                    // FIXME: remove workaround for
                    // rdar://143992296
                    // https://github.com/swiftlang/swift-subprocess/issues/3
                    #if os(Windows)
                    continuation.resume(returning: data)
                    #else
                    continuation.resume(returning: data.array())
                    #endif
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func output(from buffer: some Sequence<UInt8>) throws -> [UInt8] {
        fatalError("Not implemented")
    }

    internal init(limit: Int) {
        self.maxSize = limit
    }
}

/// A concrete `Output` type for subprocesses that redirects
/// the child output to the `.standardOutput` (a sequence) or `.standardError`
/// property of `Execution`. This output type is
/// only applicable to the `run()` family that takes a custom closure.
public struct SequenceOutput: OutputProtocol {
    public typealias OutputType = Void

    internal init() {}
}

extension OutputProtocol where Self == DiscardedOutput {
    /// Create a Subprocess output that discards the output
    public static var discarded: Self { .init() }
}

extension OutputProtocol where Self == FileDescriptorOutput {
    /// Create a Subprocess output that writes output to a `FileDescriptor`
    /// and optionally close the `FileDescriptor` once process spawned.
    public static func fileDescriptor(
        _ fd: FileDescriptor,
        closeAfterSpawningProcess: Bool
    ) -> Self {
        return .init(fileDescriptor: fd, closeAfterSpawningProcess: closeAfterSpawningProcess)
    }
}

extension OutputProtocol where Self == StringOutput<UTF8> {
    /// Create a `Subprocess` output that collects output as
    /// UTF8 String with 128kb limit.
    public static var string: Self {
        .init(limit: 128 * 1024, encoding: UTF8.self)
    }
}

extension OutputProtocol {
    /// Create a `Subprocess` output that collects output as
    /// `String` using the given encoding up to limit it bytes.
    public static func string<Encoding: Unicode.Encoding>(
        limit: Int,
        encoding: Encoding.Type
    ) -> Self where Self == StringOutput<Encoding> {
        return .init(limit: limit, encoding: encoding)
    }
}

extension OutputProtocol where Self == BytesOutput {
    /// Create a `Subprocess` output that collects output as
    /// `Buffer` with 128kb limit.
    public static var bytes: Self { .init(limit: 128 * 1024) }

    /// Create a `Subprocess` output that collects output as
    /// `Buffer` up to limit it bytes.
    public static func bytes(limit: Int) -> Self {
        return .init(limit: limit)
    }
}

extension OutputProtocol where Self == SequenceOutput {
    /// Create a `Subprocess` output that redirects the output
    /// to the `.standardOutput` (or `.standardError`) property
    /// of `Execution` as `AsyncSequence<Data>`.
    public static var sequence: Self { .init() }
}

// MARK: - Default Implementations
extension OutputProtocol {
    @_disfavoredOverload
    internal func createPipe() throws -> CreatedPipe {
        if let discard = self as? DiscardedOutput {
            return try discard.createPipe()
        } else if let fdOutput = self as? FileDescriptorOutput {
            return try fdOutput.createPipe()
        }
        // Base pipe based implementation for everything else
        return try CreatedPipe(closeWhenDone: true)
    }

    /// Capture the output from the subprocess up to maxSize
    @_disfavoredOverload
    internal func captureOutput(
        from fileDescriptor: TrackedFileDescriptor?
    ) async throws -> OutputType {
        if let bytesOutput = self as? BytesOutput {
            return try await bytesOutput.captureOutput(from: fileDescriptor) as! Self.OutputType
        }
        return try await withCheckedThrowingContinuation { continuation in
            if OutputType.self == Void.self {
                continuation.resume(returning: () as! OutputType)
                return
            }
            guard let fileDescriptor = fileDescriptor else {
                // Show not happen due to type system constraints
                fatalError("Trying to capture output without file descriptor")
            }

            fileDescriptor.wrapped.readUntilEOF(upToLength: self.maxSize) { result in
                do {
                    switch result {
                    case .success(let data):
                        // FIXME: remove workaround for
                        // rdar://143992296
                        // https://github.com/swiftlang/swift-subprocess/issues/3
                        let output = try self.output(from: data)
                        continuation.resume(returning: output)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension OutputProtocol where OutputType == Void {
    internal func captureOutput(from fileDescriptor: TrackedFileDescriptor?) async throws {}

    public func output(from buffer: some Sequence<UInt8>) throws {
        // noop
    }
}

extension DispatchData {
    internal func array() -> [UInt8] {
        var result: [UInt8]?
        self.enumerateBytes { buffer, byteIndex, stop in
            let currentChunk = Array(UnsafeRawBufferPointer(buffer))
            if result == nil {
                result = currentChunk
            } else {
                result?.append(contentsOf: currentChunk)
            }
        }
        return result ?? []
    }
}
