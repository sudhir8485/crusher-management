package com.dsp.crusher.config;

public class TenantContext {

    private static final ThreadLocal<Long> current = new ThreadLocal<>();

    public static void set(Long tenantId) {
        current.set(tenantId);
    }

    public static Long get() {
        return current.get();
    }

    public static void clear() {
        current.remove();
    }
}
