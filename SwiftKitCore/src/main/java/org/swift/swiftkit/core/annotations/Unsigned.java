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

package org.swift.swiftkit.core.annotations;

import jdk.jfr.Description;
import jdk.jfr.Label;

import java.lang.annotation.Documented;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

import static java.lang.annotation.ElementType.*;

/**
 * Value is of an unsigned numeric type.
 * <p/>
 * This annotation is used to annotate java integer primitives when their
 * corresponding Swift type was actually unsigned, e.g. an {@code @Unsigned long}
 * in a method signature corresponds to a Swift {@code UInt64} type, and therefore
 * negative values reported by the signed {@code long} should instead be interpreted positive values,
 * larger than {@code Long.MAX_VALUE} that are just not representable using a signed {@code long}.
 */
@Documented
@Label("Unsigned integer type")
@Description("Value should be interpreted as unsigned data type")
@Target({TYPE_USE, PARAMETER, FIELD})
@Retention(RetentionPolicy.RUNTIME)
public @interface Unsigned {
}
