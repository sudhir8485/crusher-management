package com.dsp.crusher.service;

import com.dsp.crusher.dto.CreateTenantRequest;
import com.dsp.crusher.dto.ResetPasswordRequest;
import com.dsp.crusher.dto.TenantListResponse;
import com.dsp.crusher.entity.Tenant;
import com.dsp.crusher.entity.User;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.TenantRepository;
import com.dsp.crusher.repository.UserRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import lombok.RequiredArgsConstructor;
import org.hibernate.Session;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AdminService {

    private final TenantRepository tenantRepo;
    private final UserRepository userRepo;
    private final PasswordEncoder passwordEncoder;

    @PersistenceContext
    private EntityManager em;

    // Sets app.tenant_id for the current transaction so FORCE RLS lets
    // the admin service read/write that tenant's users table rows.
    private void setLocalTenantId(Long tenantId) {
        em.unwrap(Session.class).doWork(conn -> {
            try (var stmt = conn.createStatement()) {
                stmt.execute("SET LOCAL app.tenant_id = " + tenantId);
            }
        });
    }

    @Transactional(readOnly = true)
    public List<TenantListResponse> listTenants() {
        return tenantRepo.findAll().stream()
                .sorted((a, b) -> b.getCreatedAt().compareTo(a.getCreatedAt()))
                .map(t -> {
                    setLocalTenantId(t.getId());
                    User owner = userRepo.findFirstByTenantIdAndRole(t.getId(), "OWNER_ADMIN").orElse(null);
                    return toResponse(t, owner);
                })
                .collect(Collectors.toList());
    }

    @Transactional
    public TenantListResponse createTenant(CreateTenantRequest req) {
        Tenant t = new Tenant();
        t.setName(req.getBusinessName().trim());
        t = tenantRepo.save(t);
        em.flush(); // ensure tenant row exists before switching tenant context

        setLocalTenantId(t.getId());
        User owner = new User();
        owner.setTenantId(t.getId());
        owner.setFullName(req.getOwnerFullName().trim());
        owner.setEmail(req.getOwnerEmail().toLowerCase().trim());
        owner.setPasswordHash(passwordEncoder.encode(req.getOwnerPassword()));
        owner.setRole("OWNER_ADMIN");
        owner = userRepo.save(owner);

        return toResponse(t, owner);
    }

    @Transactional
    public TenantListResponse deactivateTenant(Long id) {
        Tenant t = tenantRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Tenant not found: " + id));
        if ("INACTIVE".equals(t.getStatus())) {
            throw new IllegalStateException("Tenant is already inactive");
        }
        t.setStatus("INACTIVE");
        t = tenantRepo.save(t);
        setLocalTenantId(id);
        User owner = userRepo.findFirstByTenantIdAndRole(id, "OWNER_ADMIN").orElse(null);
        return toResponse(t, owner);
    }

    @Transactional
    public TenantListResponse reactivateTenant(Long id) {
        Tenant t = tenantRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Tenant not found: " + id));
        if ("ACTIVE".equals(t.getStatus())) {
            throw new IllegalStateException("Tenant is already active");
        }
        t.setStatus("ACTIVE");
        t = tenantRepo.save(t);
        setLocalTenantId(id);
        User owner = userRepo.findFirstByTenantIdAndRole(id, "OWNER_ADMIN").orElse(null);
        return toResponse(t, owner);
    }

    @Transactional
    public void resetTenantOwnerPassword(Long tenantId, ResetPasswordRequest req) {
        tenantRepo.findById(tenantId)
                .orElseThrow(() -> new ResourceNotFoundException("Tenant not found: " + tenantId));
        setLocalTenantId(tenantId);
        List<User> owners = userRepo.findByTenantIdAndRoleAndStatus(tenantId, "OWNER_ADMIN", "ACTIVE");
        if (owners.isEmpty()) {
            throw new ResourceNotFoundException("No active Owner/Admin found for tenant: " + tenantId);
        }
        String newHash = passwordEncoder.encode(req.getNewPassword());
        owners.forEach(u -> {
            u.setPasswordHash(newHash);
            userRepo.save(u);
        });
    }

    private TenantListResponse toResponse(Tenant t, User owner) {
        TenantListResponse r = new TenantListResponse();
        r.setId(t.getId());
        r.setName(t.getName());
        r.setStatus(t.getStatus());
        r.setCreatedAt(t.getCreatedAt());
        if (owner != null) {
            r.setOwnerName(owner.getFullName());
            r.setOwnerEmail(owner.getEmail());
        }
        return r;
    }
}
