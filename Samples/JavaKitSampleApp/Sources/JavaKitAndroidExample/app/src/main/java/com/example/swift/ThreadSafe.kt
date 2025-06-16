package com.example.swift

import kotlin.annotation.AnnotationRetention
import kotlin.annotation.AnnotationTarget

@Retention(AnnotationRetention.RUNTIME)
@Target(AnnotationTarget.CLASS, AnnotationTarget.FUNCTION, AnnotationTarget.PROPERTY)
annotation class ThreadSafe