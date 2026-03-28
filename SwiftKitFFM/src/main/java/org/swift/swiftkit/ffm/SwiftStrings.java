package org.swift.swiftkit.ffm;

import java.lang.foreign.*;

/**
 * Utility methods for converting between Java Strings and C strings (null-terminated UTF-8).
 */
public final class SwiftStrings {

    private SwiftStrings() {
        // Not instantiable
    }

    /**
     * Convert String to a MemorySegment filled with the C string.
     */
    public static MemorySegment toCString(String str, Arena arena) {
        return arena.allocateFrom(str);
    }

    /**
     * Read a heap-allocated C string into a Java String, then free the native memory.
     */
    public static String fromCString(MemorySegment cStr) {
        if (cStr.equals(MemorySegment.NULL)) return null;
        String result = cStr.reinterpret(Long.MAX_VALUE).getString(0);
        SwiftRuntime.cFree(cStr);
        return result;
    }
}
