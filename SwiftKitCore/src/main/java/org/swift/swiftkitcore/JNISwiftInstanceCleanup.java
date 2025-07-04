package org.swift.swiftkitcore;

import java.lang.reflect.Method;

class JNISwiftInstanceCleanup implements SwiftInstanceCleanup {
    private final Class<? extends SwiftInstance> clazz;
    private final long selfPointer;
    private final Runnable markAsDestroyed;

    public JNISwiftInstanceCleanup(Class<? extends SwiftInstance> clazz, long selfPointer, Runnable markAsDestroyed) {
        this.clazz = clazz;
        this.selfPointer = selfPointer;
        this.markAsDestroyed = markAsDestroyed;
    }

    @Override
    public void run() {
        markAsDestroyed.run();

        try {
            // Use reflection to look for the static destroy method on the wrapper.
            Method method = clazz.getDeclaredMethod("destroy", long.class);
            method.invoke(null, selfPointer);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
