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

#if SubprocessFoundation

#if canImport(Darwin)
// On Darwin always prefer system Foundation
import Foundation
#else
// On other platforms prefer FoundationEssentials
import FoundationEssentials
#endif

#endif  // SubprocessFoundation

// MARK: - Input

/// `InputProtocol` defines the `write(with:)` method that a type
/// must implement to serve as the input source for a subprocess.
public protocol InputProtocol: Sendable, ~Copyable {
    /// Asynchronously write the input to the subprocess using the
    /// write file descriptor
    func write(with writer: StandardInputWriter) async throws
}

/// A concrete `Input` type for subprocesses that indicates
/// the absence of input to the subprocess. On Unix-like systems,
/// `NoInput` redirects the standard input of the subprocess
/// to `/dev/null`, while on Windows, it does not bind any
/// file handle to the subprocess standard input handle.
public struct NoInput: InputProtocol {
    internal func createPipe() throws -> CreatedPipe {
        #if os(Windows)
        // On Windows, instead of binding to dev null,
        // we don't set the input handle in the `STARTUPINFOW`
        // to signal no input
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

    public func write(with writer: StandardInputWriter) async throws {
        // noop
    }

    internal init() {}
}

/// A concrete `Input` type for subprocesses that
/// reads input from a specified `FileDescriptor`.
/// Developers have the option to instruct the `Subprocess` to
/// automatically close the provided `FileDescriptor`
/// after the subprocess is spawned.
public struct FileDescriptorInput: InputProtocol {
    private let fileDescriptor: FileDescriptor
    private let closeAfterSpawningProcess: Bool

    internal func createPipe() throws -> CreatedPipe {
        return CreatedPipe(
            readFileDescriptor: .init(
                self.fileDescriptor,
                closeWhenDone: self.closeAfterSpawningProcess
            ),
            writeFileDescriptor: nil
        )
    }

    public func write(with writer: StandardInputWriter) async throws {
        // noop
    }

    internal init(
        fileDescriptor: FileDescriptor,
        closeAfterSpawningProcess: Bool
    ) {
        self.fileDescriptor = fileDescriptor
        self.closeAfterSpawningProcess = closeAfterSpawningProcess
    }
}

/// A concrete `Input` type for subprocesses that reads input
/// from a given type conforming to `StringProtocol`.
/// Developers can specify the string encoding to use when
/// encoding the string to data, which defaults to UTF-8.
public struct StringInput<
    InputString: StringProtocol & Sendable,
    Encoding: Unicode.Encoding
>: InputProtocol {
    private let string: InputString

    public func write(with writer: StandardInputWriter) async throws {
        guard let array = self.string.byteArray(using: Encoding.self) else {
            return
        }
        _ = try await writer.write(array)
    }

    internal init(string: InputString, encoding: Encoding.Type) {
        self.string = string
    }
}

/// A concrete `Input` type for subprocesses that reads input
/// from a given `UInt8` Array.
public struct ArrayInput: InputProtocol {
    private let array: [UInt8]

    public func write(with writer: StandardInputWriter) async throws {
        _ = try await writer.write(self.array)
    }

    internal init(array: [UInt8]) {
        self.array = array
    }
}

/// A concrete `Input` type for subprocess that indicates that
/// the Subprocess should read its input from `StandardInputWriter`.
public struct CustomWriteInput: InputProtocol {
    public func write(with writer: StandardInputWriter) async throws {
        // noop
    }

    internal init() {}
}

extension InputProtocol where Self == NoInput {
    /// Create a Subprocess input that specfies there is no input
    public static var none: Self { .init() }
}

extension InputProtocol where Self == FileDescriptorInput {
    /// Create a Subprocess input from a `FileDescriptor` and
    /// specify whether the `FileDescriptor` should be closed
    /// after the process is spawned.
    public static func fileDescriptor(
        _ fd: FileDescriptor,
        closeAfterSpawningProcess: Bool
    ) -> Self {
        return .init(
            fileDescriptor: fd,
            closeAfterSpawningProcess: closeAfterSpawningProcess
        )
    }
}

extension InputProtocol {
    /// Create a Subprocess input from a `Array` of `UInt8`.
    public static func array(
        _ array: [UInt8]
    ) -> Self where Self == ArrayInput {
        return ArrayInput(array: array)
    }

    /// Create a Subprocess input from a type that conforms to `StringProtocol`
    public static func string<
        InputString: StringProtocol & Sendable
    >(
        _ string: InputString
    ) -> Self where Self == StringInput<InputString, UTF8> {
        return .init(string: string, encoding: UTF8.self)
    }

    /// Create a Subprocess input from a type that conforms to `StringProtocol`
    public static func string<
        InputString: StringProtocol & Sendable,
        Encoding: Unicode.Encoding
    >(
        _ string: InputString,
        using encoding: Encoding.Type
    ) -> Self where Self == StringInput<InputString, Encoding> {
        return .init(string: string, encoding: encoding)
    }
}

extension InputProtocol {
    internal func createPipe() throws -> CreatedPipe {
        if let noInput = self as? NoInput {
            return try noInput.createPipe()
        } else if let fdInput = self as? FileDescriptorInput {
            return try fdInput.createPipe()
        }
        // Base implementation
        return try CreatedPipe(closeWhenDone: true)
    }
}

// MARK: - StandardInputWriter

/// A writer that writes to the standard input of the subprocess.
public final actor StandardInputWriter: Sendable {

    internal let fileDescriptor: TrackedFileDescriptor

    init(fileDescriptor: TrackedFileDescriptor) {
        self.fileDescriptor = fileDescriptor
    }

    /// Write an array of UInt8 to the standard input of the subprocess.
    /// - Parameter array: The sequence of bytes to write.
    /// - Returns number of bytes written.
    public func write(
        _ array: [UInt8]
    ) async throws -> Int {
        return try await self.fileDescriptor.wrapped.write(array)
    }

    /// Write a StringProtocol to the standard input of the subprocess.
    /// - Parameters:
    ///   - string: The string to write.
    ///   - encoding: The encoding to use when converting string to bytes
    /// - Returns number of bytes written.
    public func write<Encoding: Unicode.Encoding>(
        _ string: some StringProtocol,
        using encoding: Encoding.Type = UTF8.self
    ) async throws -> Int {
        if let array = string.byteArray(using: encoding) {
            return try await self.write(array)
        }
        return 0
    }

    /// Signal all writes are finished
    public func finish() async throws {
        try self.fileDescriptor.safelyClose()
    }
}

extension StringProtocol {
    #if SubprocessFoundation
    private func convertEncoding<Encoding: Unicode.Encoding>(
        _ encoding: Encoding.Type
    ) -> String.Encoding? {
        switch encoding {
        case is UTF8.Type:
            return .utf8
        case is UTF16.Type:
            return .utf16
        case is UTF32.Type:
            return .utf32
        default:
            return nil
        }
    }
    #endif
    package func byteArray<Encoding: Unicode.Encoding>(using encoding: Encoding.Type) -> [UInt8]? {
        if Encoding.self == Unicode.ASCII.self {
            let isASCII = self.utf8.allSatisfy {
                return Character(Unicode.Scalar($0)).isASCII
            }

            guard isASCII else {
                return nil
            }
            return Array(self.utf8)
        }
        if Encoding.self == UTF8.self {
            return Array(self.utf8)
        }
        if Encoding.self == UTF16.self {
            return Array(self.utf16).flatMap { input in
                var uint16: UInt16 = input
                return withUnsafeBytes(of: &uint16) { ptr in
                    Array(ptr)
                }
            }
        }
        #if SubprocessFoundation
        if let stringEncoding = self.convertEncoding(encoding),
            let encoded = self.data(using: stringEncoding)
        {
            return Array(encoded)
        }
        return nil
        #else
        return nil
        #endif
    }
}

extension String {
    package init<T: FixedWidthInteger, Encoding: Unicode.Encoding>(
        decodingBytes bytes: [T],
        as encoding: Encoding.Type
    ) {
        self = bytes.withUnsafeBytes { raw in
            String(
                decoding: raw.bindMemory(to: Encoding.CodeUnit.self).lazy.map { $0 },
                as: encoding
            )
        }
    }
}
