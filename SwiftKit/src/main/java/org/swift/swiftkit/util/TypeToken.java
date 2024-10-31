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

package org.swift.swiftkit.util;

import java.lang.reflect.ParameterizedType;
import java.lang.reflect.Type;

/**
 * Type token to obtain the underlying {@link Type} of a generic type {@code T}.
 * @param <T>
 */
public abstract class TypeToken<T> {
    private Type type;

    protected TypeToken(){
        Type superClass = getClass().getGenericSuperclass();
        this.type = ((ParameterizedType) superClass).getActualTypeArguments()[0];
    }

    public Type getType() {
        return type;
    }
}
