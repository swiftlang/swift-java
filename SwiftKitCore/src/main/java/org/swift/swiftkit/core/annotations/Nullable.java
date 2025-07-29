package org.swift.swiftkit.core.annotations;


import static java.lang.annotation.ElementType.TYPE_USE;
import static java.lang.annotation.RetentionPolicy.RUNTIME;

import java.lang.annotation.Documented;
import java.lang.annotation.Retention;
import java.lang.annotation.Target;

// TODO: Consider depending on jspecify instead
@Documented
@Target(TYPE_USE)
@Retention(RUNTIME)
public @interface Nullable {}