package com.example.swift

import java.util.Optional
import java.util.OptionalDouble
import java.util.OptionalInt
import java.util.OptionalLong

@ThreadSafe
class ThreadSafeHelperClass {
    var text: Optional<String> = Optional.of("")

    val `val`: OptionalDouble = OptionalDouble.of(2.0)

    fun getValue(name: Optional<String>): String {
        return name.orElse("")
    }

    fun from(value: OptionalInt): OptionalLong {
        return OptionalLong.of(value.asInt.toLong())
    }
}
