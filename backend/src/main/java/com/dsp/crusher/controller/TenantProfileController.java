package com.dsp.crusher.controller;

import com.dsp.crusher.dto.TenantProfileRequest;
import com.dsp.crusher.dto.TenantProfileResponse;
import com.dsp.crusher.service.TenantProfileService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/tenant/profile")
@RequiredArgsConstructor
public class TenantProfileController {

    private final TenantProfileService service;

    @GetMapping
    public TenantProfileResponse get() {
        return service.get();
    }

    @PutMapping
    @PreAuthorize("hasRole('OWNER_ADMIN')")
    public TenantProfileResponse update(@RequestBody TenantProfileRequest req) {
        return service.update(req);
    }
}
