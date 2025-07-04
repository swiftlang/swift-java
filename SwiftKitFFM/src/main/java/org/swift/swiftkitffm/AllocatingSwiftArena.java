package org.swift.swiftkitffm;

import org.swift.swiftkitcore.ClosableSwiftArena;
import org.swift.swiftkitcore.ConfinedSwiftMemorySession;
import org.swift.swiftkitcore.SwiftArena;

import java.lang.foreign.MemorySegment;
import java.util.concurrent.ThreadFactory;

public interface AllocatingSwiftArena extends SwiftArena {
    MemorySegment allocate(long byteSize, long byteAlignment);

    static ClosableAllocatingSwiftArena ofConfined() {
        return new FFMConfinedSwiftMemorySession(Thread.currentThread());
    }

    static AllocatingSwiftArena ofAuto() {
        ThreadFactory cleanerThreadFactory = r -> new Thread(r, "AutoSwiftArenaCleanerThread");
        return new AllocatingAutoSwiftMemorySession(cleanerThreadFactory);
    }
}
