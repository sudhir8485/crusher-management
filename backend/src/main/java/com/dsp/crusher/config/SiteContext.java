package com.dsp.crusher.config;

public class SiteContext {

    private static final ThreadLocal<Long> current = new ThreadLocal<>();

    public static void set(Long siteId) {
        current.set(siteId);
    }

    public static Long get() {
        return current.get();
    }

    public static void clear() {
        current.remove();
    }
}
