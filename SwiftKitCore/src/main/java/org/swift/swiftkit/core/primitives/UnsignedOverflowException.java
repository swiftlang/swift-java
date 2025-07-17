package org.swift.swiftkit.core.primitives;

public class UnsignedOverflowException extends RuntimeException {
    public UnsignedOverflowException(String value, Class<?> clazz) {
        super(String.format("Value '%s' cannot be represented as %s as it would overflow!", value, clazz.getName()));
    }
}
