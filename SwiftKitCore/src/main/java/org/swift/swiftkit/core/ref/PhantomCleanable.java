package org.swift.swiftkit.core.ref;

import java.lang.ref.PhantomReference;

/**
 * PhantomCleanableRef
 *
 * @author Mads Odgaard (202206257)
 */
public class PhantomCleanable extends PhantomReference<Object> {
    private final Runnable cleanupAction;
    private final Cleaner cleaner;

    public PhantomCleanable(Object referent, Cleaner cleaner, Runnable cleanupAction) {
        super(referent, cleaner.referenceQueue);
        this.cleanupAction = cleanupAction;
        this.cleaner = cleaner;
        cleaner.list.add(this);
    }

    public void cleanup() {
        if (cleaner.list.remove(this)) {
            cleanupAction.run();
        }
    }
}
