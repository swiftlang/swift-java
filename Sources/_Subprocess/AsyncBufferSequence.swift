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

internal struct AsyncBufferSequence: AsyncSequence, Sendable {
    internal typealias Failure = any Swift.Error

    internal typealias Element = SequenceOutput.Buffer

    @_nonSendable
    internal struct Iterator: AsyncIteratorProtocol {
        internal typealias Element = SequenceOutput.Buffer

        private let fileDescriptor: TrackedFileDescriptor
        private var buffer: [UInt8]
        private var currentPosition: Int
        private var finished: Bool

        internal init(fileDescriptor: TrackedFileDescriptor) {
            self.fileDescriptor = fileDescriptor
            self.buffer = []
            self.currentPosition = 0
            self.finished = false
        }

        internal mutating func next() async throws -> SequenceOutput.Buffer? {
            let data = try await self.fileDescriptor.wrapped.readChunk(
                upToLength: readBufferSize
            )
            if data == nil {
                // We finished reading. Close the file descriptor now
                try self.fileDescriptor.safelyClose()
                return nil
            }
            return data
        }
    }

    private let fileDescriptor: TrackedFileDescriptor

    init(fileDescriptor: TrackedFileDescriptor) {
        self.fileDescriptor = fileDescriptor
    }

    internal func makeAsyncIterator() -> Iterator {
        return Iterator(fileDescriptor: self.fileDescriptor)
    }
}

// MARK: - Page Size
import _SubprocessCShims

#if canImport(Darwin)
import Darwin
internal import MachO.dyld

private let _pageSize: Int = {
    Int(_subprocess_vm_size())
}()
#elseif canImport(WinSDK)
import WinSDK
private let _pageSize: Int = {
    var sysInfo: SYSTEM_INFO = SYSTEM_INFO()
    GetSystemInfo(&sysInfo)
    return Int(sysInfo.dwPageSize)
}()
#elseif os(WASI)
// WebAssembly defines a fixed page size
private let _pageSize: Int = 65_536
#elseif canImport(Android)
@preconcurrency import Android
private let _pageSize: Int = Int(getpagesize())
#elseif canImport(Glibc)
@preconcurrency import Glibc
private let _pageSize: Int = Int(getpagesize())
#elseif canImport(Musl)
@preconcurrency import Musl
private let _pageSize: Int = Int(getpagesize())
#elseif canImport(C)
private let _pageSize: Int = Int(getpagesize())
#endif  // canImport(Darwin)

@inline(__always)
internal var readBufferSize: Int {
    return _pageSize
}
