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

#if SubprocessFoundation && SubprocessSpan

#if canImport(Darwin)
// On Darwin always prefer system Foundation
import Foundation
#else
// On other platforms prefer FoundationEssentials
import FoundationEssentials
#endif  // canImport(Darwin)

internal import Dispatch


extension Data {
    init(_ s: borrowing RawSpan) {
        self = s.withUnsafeBytes { Data($0) }
    }

    public var bytes: RawSpan {
        // FIXME: For demo purpose only
        let ptr = self.withUnsafeBytes { ptr in
            return ptr
        }
        let span = RawSpan(_unsafeBytes: ptr)
        return _overrideLifetime(of: span, to: self)
    }
}


extension DataProtocol {
    var bytes: RawSpan {
        _read {
            if self.regions.isEmpty {
                let empty = UnsafeRawBufferPointer(start: nil, count: 0)
                let span = RawSpan(_unsafeBytes: empty)
                yield _overrideLifetime(of: span, to: self)
            } else if self.regions.count == 1 {
                // Easy case: there is only one region in the data
                let ptr = self.regions.first!.withUnsafeBytes { ptr in
                    return ptr
                }
                let span = RawSpan(_unsafeBytes: ptr)
                yield _overrideLifetime(of: span, to: self)
            } else {
                // This data contains discontiguous chunks. We have to
                // copy and make a contiguous chunk
                var contiguous: ContiguousArray<UInt8>?
                for region in self.regions {
                    if contiguous != nil {
                        contiguous?.append(contentsOf: region)
                    } else {
                        contiguous = .init(region)
                    }
                }
                let ptr = contiguous!.withUnsafeBytes { ptr in
                    return ptr
                }
                let span = RawSpan(_unsafeBytes: ptr)
                yield _overrideLifetime(of: span, to: self)
            }
        }
    }
}

#endif  // SubprocessFoundation
