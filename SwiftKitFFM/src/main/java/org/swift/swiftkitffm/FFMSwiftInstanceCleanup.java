package org.swift.swiftkitffm;

import org.swift.swiftkitcore.SwiftInstanceCleanup;

import java.lang.foreign.MemorySegment;

public class FFMSwiftInstanceCleanup implements SwiftInstanceCleanup {
    private final MemorySegment selfPointer;
    private final SwiftAnyType selfType;
    private final Runnable markAsDestroyed;

    public FFMSwiftInstanceCleanup(MemorySegment selfPointer, SwiftAnyType selfType, Runnable markAsDestroyed) {
        this.selfPointer = selfPointer;
        this.selfType = selfType;
        this.markAsDestroyed = markAsDestroyed;
    }

    @Override
    public void run() {
        markAsDestroyed.run();

        // Allow null pointers just for AutoArena tests.
        if (selfType != null && selfPointer != null) {
            System.out.println("[debug] Destroy swift value [" + selfType.getSwiftName() + "]: " + selfPointer);
            SwiftValueWitnessTable.destroy(selfType, selfPointer);
        }
    }
}
