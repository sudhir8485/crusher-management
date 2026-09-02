package com.dsp.crusher.service;

import com.dsp.crusher.config.JwtConfig;
import com.dsp.crusher.dto.LoginRequest;
import com.dsp.crusher.dto.LoginResponse;
import com.dsp.crusher.entity.User;
import com.dsp.crusher.exception.UnauthorizedException;
import com.dsp.crusher.repository.TenantRepository;
import com.dsp.crusher.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepo;
    private final TenantRepository tenantRepo;
    private final PasswordEncoder passwordEncoder;
    private final JwtConfig jwtConfig;

    public LoginResponse login(LoginRequest request) {
        User user = userRepo.findByEmailNative(request.getEmail())
                .orElseThrow(() -> new UnauthorizedException("Invalid email or password"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new UnauthorizedException("Invalid email or password");
        }

        if (!"ACTIVE".equals(user.getStatus())) {
            throw new UnauthorizedException("Account is inactive");
        }

        String tenantName = tenantRepo.findById(user.getTenantId())
                .map(t -> t.getName())
                .orElse("");

        String token = jwtConfig.generate(user.getId(), user.getTenantId(), user.getRole(), user.getSiteId());
        return new LoginResponse(token, user.getRole(), user.getFullName(),
                user.getTenantId(), user.getSiteId(), tenantName);
    }
}
