package org.swift.swiftkit.compose

interface SwiftObservable {
    fun retainObserver()
    fun releaseObserver()
}