package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.UserRequest;
import com.dsp.crusher.dto.UserResponse;
import com.dsp.crusher.entity.User;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.UserRepository;
import lombok.RequiredArgsConstructor;
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
        return userRepo.findAll().stream()
                .map(this::toResponse).collect(Collectors.toList());
    }

    @Transactional
    public UserResponse create(UserRequest req) {
        if (req.getPassword() == null || req.getPassword().isBlank()) {
            throw new IllegalArgumentException("Password is required when creating a user");
        }
        User u = new User();
        u.setTenantId(TenantContext.get());
        u.setFullName(req.getFullName());
        u.setEmail(req.getEmail().toLowerCase().trim());
        u.setPasswordHash(passwordEncoder.encode(req.getPassword()));
        u.setRole(req.getRole());
        u.setSiteId(req.getSiteId());
        return toResponse(userRepo.save(u));
    }

    @Transactional
    public UserResponse update(Long id, UserRequest req) {
        User u = userRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + id));
        u.setFullName(req.getFullName());
        u.setEmail(req.getEmail().toLowerCase().trim());
        u.setRole(req.getRole());
        u.setSiteId(req.getSiteId());
        if (req.getPassword() != null && !req.getPassword().isBlank()) {
            u.setPasswordHash(passwordEncoder.encode(req.getPassword()));
        }
        return toResponse(userRepo.save(u));
    }

    @Transactional
    public UserResponse deactivate(Long id) {
        User u = userRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + id));
        u.setStatus("INACTIVE");
        return toResponse(userRepo.save(u));
    }

    private UserResponse toResponse(User u) {
        UserResponse r = new UserResponse();
        r.setId(u.getId());
        r.setFullName(u.getFullName());
        r.setEmail(u.getEmail());
        r.setRole(u.getRole());
        r.setSiteId(u.getSiteId());
        r.setStatus(u.getStatus());
        r.setCreatedAt(u.getCreatedAt());
        return r;
    }
}
