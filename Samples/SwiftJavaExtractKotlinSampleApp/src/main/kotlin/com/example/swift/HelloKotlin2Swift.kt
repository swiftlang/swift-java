package com.example.swift

/**
 * Downcall to Swift:
 * {@snippet lang=swift :
 * public var cap: Int
 * }
 */
fun main() {
    println("Hello from Kotlin to Swift!")
}

class HelloKotlin2Swift private constructor() {
    override fun toString(): String {
        TODO("Not implemented")
    }
}
