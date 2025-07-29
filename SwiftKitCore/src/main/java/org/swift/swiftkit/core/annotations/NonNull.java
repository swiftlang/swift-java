package org.swift.swiftkit.core.annotations;


import java.lang.annotation.Documented;
import java.lang.annotation.Retention;
import java.lang.annotation.Target;

import static java.lang.annotation.ElementType.TYPE_USE;
import static java.lang.annotation.RetentionPolicy.RUNTIME;

// TODO: Consider depending on jspecify instead
@Documented
@Target(TYPE_USE)
@Retention(RUNTIME)
public @interface NonNull {}