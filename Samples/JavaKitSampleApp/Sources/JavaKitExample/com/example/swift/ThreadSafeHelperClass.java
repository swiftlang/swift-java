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

package com.example.swift;

import java.util.Optional;
import java.util.OptionalLong;
import java.util.OptionalInt;
import java.util.OptionalDouble;

@ThreadSafe
public class ThreadSafeHelperClass {
    public ThreadSafeHelperClass() { }

    public Optional<String> text = Optional.of("cool string");

    public final OptionalDouble val = OptionalDouble.of(2);

    public String getValue(Optional<String> name) {
        return name.orElse("");
    }


    public String getOrElse(Optional<String> name) {
        return name.orElse("or else value");
    }

    public Optional<String> getNil() {
        return Optional.empty();
    }

    // @NonNull
    // public Optional<String> getNil() {
    //     return Optional.empty();
    // }

    public Optional<String> getText() {
        return text;
    }

    public OptionalLong from(OptionalInt value) {
        return OptionalLong.of(value.getAsInt());
    }
}
