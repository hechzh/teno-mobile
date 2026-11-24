package android.os;

import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

/** JVM-only stand-in. The test thread explicitly dispatches each network callback. */
public final class Handler {
    private final LinkedBlockingQueue<Runnable> callbacks = new LinkedBlockingQueue<>();

    public boolean post(Runnable task) { return callbacks.offer(task); }

    public void dispatch() throws InterruptedException {
        Runnable task = callbacks.poll(5, TimeUnit.SECONDS);
        if (task == null) throw new AssertionError("Expected recorder callback");
        task.run();
    }
}
