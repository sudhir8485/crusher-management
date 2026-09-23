package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.UserRequest;
import com.dsp.crusher.dto.UserResponse;
import com.dsp.crusher.entity.User;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepo;
    private final PasswordEncoder passwordEncoder;

    public List<UserResponse> listAll() {
        // Explicit tenant filter — users table has no FORCE RLS so we
        // cannot rely on the session variable alone for isolation.
        Long tenantId = TenantContext.get();
        return userRepo.findByTenantId(tenantId).stream()
                .map(this::toResponse).collect(Collectors.toList());
    }

    @Transactional
    public UserResponse create(UserRequest req) {
        if (req.getPassword() == null || req.getPassword().isBlank()) {
            throw new IllegalArgumentException("Password is required when creating a user");
        }
        if ("SITE_STAFF".equals(req.getRole()) && req.getSiteId() == null) {
            throw new IllegalArgumentException("Assigned site is required for Site Staff users");
        }
        String email = req.getEmail().toLowerCase().trim();
        if (userRepo.existsByEmail(email)) {
            throw new IllegalArgumentException(
                    "This email is already registered to another account. Please use a different email.");
        }
        User u = new User();
        u.setTenantId(TenantContext.get());
        u.setFullName(req.getFullName());
        u.setEmail(email);
        u.setPasswordHash(passwordEncoder.encode(req.getPassword()));
        u.setRole(req.getRole());
        u.setSiteId(req.getSiteId());
        return toResponse(userRepo.save(u));
    }

    @Transactional
    public UserResponse update(Long id, UserRequest req) {
        User u = findForCurrentTenant(id);
        if ("SITE_STAFF".equals(req.getRole()) && req.getSiteId() == null) {
            throw new IllegalArgumentException("Assigned site is required for Site Staff users");
        }
        String newEmail = req.getEmail().toLowerCase().trim();
        if (!newEmail.equals(u.getEmail()) && userRepo.existsByEmail(newEmail)) {
            throw new IllegalArgumentException(
                    "This email is already registered to another account. Please use a different email.");
        }
        u.setFullName(req.getFullName());
        u.setEmail(newEmail);
        u.setRole(req.getRole());
        u.setSiteId(req.getSiteId());
        if (req.getPassword() != null && !req.getPassword().isBlank()) {
            u.setPasswordHash(passwordEncoder.encode(req.getPassword()));
        }
        return toResponse(userRepo.save(u));
    }

    @Transactional
    public UserResponse deactivate(Long id) {
        User u = findForCurrentTenant(id);
        // Guards against locking a tenant out of its own account. If every user
        // (or the last owner) is deactivated, nobody can log in and superadmin
        // can only reset passwords — not reactivate — so the tenant is stranded.
        if (Boolean.TRUE.equals(u.getProtectedOwner())) {
            throw new IllegalStateException("This is the primary owner account and cannot be deactivated.");
        }
        if (id.equals(currentUserId())) {
            throw new IllegalStateException("You cannot deactivate your own account.");
        }
        if ("OWNER_ADMIN".equals(u.getRole())
                && userRepo.findByTenantIdAndRoleAndStatus(u.getTenantId(), "OWNER_ADMIN", "ACTIVE").size() <= 1) {
            throw new IllegalStateException("Cannot deactivate the last active owner.");
        }
        u.setStatus("INACTIVE");
        return toResponse(userRepo.save(u));
    }

    @Transactional
    public UserResponse reactivate(Long id) {
        User u = findForCurrentTenant(id);
        u.setStatus("ACTIVE");
        return toResponse(userRepo.save(u));
    }

    private Long currentUserId() {
        return Long.parseLong(SecurityContextHolder.getContext().getAuthentication().getName());
    }

    private User findForCurrentTenant(Long id) {
        Long tenantId = TenantContext.get();
        return userRepo.findByIdAndTenantId(id, tenantId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + id));
    }

    private UserResponse toResponse(User u) {
        UserResponse r = new UserResponse();
        r.setId(u.getId());
        r.setFullName(u.getFullName());
        r.setEmail(u.getEmail());
        r.setRole(u.getRole());
        r.setSiteId(u.getSiteId());
        r.setStatus(u.getStatus());
        r.setProtectedOwner(u.getProtectedOwner());
        r.setCreatedAt(u.getCreatedAt());
        return r;
    }
}
