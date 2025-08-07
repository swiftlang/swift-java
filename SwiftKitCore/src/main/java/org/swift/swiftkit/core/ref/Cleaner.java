package org.swift.swiftkit.core.ref;

import java.lang.ref.ReferenceQueue;
import java.util.Collections;
import java.util.LinkedList;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.ThreadFactory;

public class Cleaner implements Runnable {
    final ReferenceQueue<Object> referenceQueue;
    final List<PhantomCleanable> list;

    private Cleaner() {
        this.referenceQueue = new ReferenceQueue<>();
        this.list = Collections.synchronizedList(new LinkedList<>());
    }

    public static Cleaner create(ThreadFactory threadFactory) {
        Cleaner cleaner = new Cleaner();
        cleaner.start(threadFactory);
        return cleaner;
    }

    void start(ThreadFactory threadFactory) {
        // This makes sure the linked list is not empty when the thread starts,
        // and the thread will run at least until the cleaner itself can be GCed.
        new PhantomCleanable(this, this, () -> {});

        Thread thread = threadFactory.newThread(this);
        thread.setDaemon(true);
        thread.start();
    }

    public void register(Object resourceHolder, Runnable cleaningAction) {
        Objects.requireNonNull(resourceHolder, "resourceHolder");
        Objects.requireNonNull(cleaningAction, "cleaningAction");
        new PhantomCleanable(resourceHolder, this, cleaningAction);
    }

    @Override
    public void run() {
        while (!list.isEmpty()) {
            try {
                PhantomCleanable removed = (PhantomCleanable) referenceQueue.remove(60 * 1000L);
                removed.cleanup();
            } catch (Throwable e) {
                // ignore exceptions from the cleanup action
                // (including interruption of cleanup thread)
            }
        }
    }
}
