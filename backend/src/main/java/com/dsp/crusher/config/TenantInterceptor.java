package com.dsp.crusher.config;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.hibernate.Session;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class TenantInterceptor implements HandlerInterceptor {

    @PersistenceContext
    private EntityManager em;

    @Override
    public boolean preHandle(HttpServletRequest request,
                             HttpServletResponse response,
                             Object handler) {
        Long tenantId = TenantContext.get();
        if (tenantId != null) {
            // Set PostgreSQL session variable for RLS policies
            em.unwrap(Session.class)
              .doWork(conn -> {
                  try (var stmt = conn.createStatement()) {
                      stmt.execute("SET app.tenant_id = " + tenantId);
                  }
              });
        }
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request,
                                HttpServletResponse response,
                                Object handler, Exception ex) {
        // Reset to prevent any stale session state
        em.unwrap(Session.class)
          .doWork(conn -> {
              try (var stmt = conn.createStatement()) {
                  stmt.execute("RESET app.tenant_id");
              }
          });
    }
}
