package com.example.swift;

import org.swift.swiftkit.SwiftKit;

public class JExtractPluginSampleMain {
    public static void main(String[] args) {
        System.out.println();
        System.out.println("java.library.path = " + SwiftKit.getJavaLibraryPath());
        System.out.println("jextract.trace.downcalls = " + SwiftKit.getJextractTraceDowncalls());

        var o = new MyCoolSwiftClass(12);
        o.exposedToJava();
    }
}
