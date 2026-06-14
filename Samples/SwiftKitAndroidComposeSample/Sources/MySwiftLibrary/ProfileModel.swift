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

import Observation

/// A child `@Observable` object, nested inside `ProfileModel`.
@Observable
public class AddressModel {
  public var street: String = "1 Infinite Loop"
  public var city: String = "Cupertino"
  public var country: String = "USA"

  public init() {}

  public var oneLine: String {
    "\(street), \(city), \(country)"
  }
}

/// Demonstrates **nested observable objects**. `ProfileModel` owns an
/// `AddressModel`. Mutating a field on the nested object (e.g. `address.city`)
/// should be observable to a UI that is tracking the nested object.
///
/// Note: the parent only directly observes its own `name` and the `address`
/// *reference*. To react to changes *inside* the nested object, the Compose
/// layer observes the child as well (see `NestedScreen`).
@Observable
public class ProfileModel {
  public var name: String = "Jane Appleseed"
  public var address: AddressModel = AddressModel()

  public init() {}

  public func moveToLondon() {
    address.street = "10 Downing Street"
    address.city = "London"
    address.country = "UK"
  }

  /// Replaces the whole nested object (reference change on the parent).
  public func replaceAddress() {
    address = AddressModel()
  }
}
