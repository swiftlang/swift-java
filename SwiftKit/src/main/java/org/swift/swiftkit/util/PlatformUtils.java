package org.swift.swiftkit.util;

public class PlatformUtils {
    public static boolean isLinux() {
        return System.getProperty("os.name").toLowerCase().contains("linux");
    }

    public static boolean isMacOS() {
        return System.getProperty("os.name").toLowerCase().contains("mac");
    }

    public static boolean isWindows() {
        return System.getProperty("os.name").toLowerCase().contains("windows");
    }
}
