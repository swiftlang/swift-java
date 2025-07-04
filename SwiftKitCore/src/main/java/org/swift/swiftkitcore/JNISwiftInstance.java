package org.swift.swiftkitcore;

import java.util.concurrent.atomic.AtomicBoolean;

public class JNISwiftInstance extends SwiftInstance {
    /**
     * The designated constructor of any imported Swift types.
     *
     * @param pointer a pointer to the memory containing the value
     * @param arena   the arena this object belongs to. When the arena goes out of scope, this value is destroyed.
     */
    protected JNISwiftInstance(long pointer, SwiftArena arena) {
        super(pointer, arena);
    }

    @Override
    public SwiftInstanceCleanup makeCleanupAction() {
        final AtomicBoolean statusDestroyedFlag = $statusDestroyedFlag();
        Runnable markAsDestroyed = new Runnable() {
            @Override
            public void run() {
                statusDestroyedFlag.set(true);
            }
        };

        return new JNISwiftInstanceCleanup(this.getClass(), this.pointer(), markAsDestroyed);
    }
}
