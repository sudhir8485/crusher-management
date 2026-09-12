package com.dsp.crusher.controller;

import com.dsp.crusher.dto.CreateTenantRequest;
import com.dsp.crusher.dto.ResetPasswordRequest;
import com.dsp.crusher.dto.TenantListResponse;
import com.dsp.crusher.service.AdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin")
@Tag(name = "Platform Admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService service;

    @GetMapping("/tenants")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    @Operation(summary = "List all tenants")
    public List<TenantListResponse> listTenants() {
        return service.listTenants();
    }

    @PostMapping("/tenants")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create a new tenant with an Owner/Admin user")
    public TenantListResponse createTenant(@Valid @RequestBody CreateTenantRequest req) {
        return service.createTenant(req);
    }

    @PatchMapping("/tenants/{id}/deactivate")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    @Operation(summary = "Deactivate a tenant")
    public TenantListResponse deactivateTenant(@PathVariable Long id) {
        return service.deactivateTenant(id);
    }

    @PatchMapping("/tenants/{id}/reactivate")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    @Operation(summary = "Reactivate a tenant")
    public TenantListResponse reactivateTenant(@PathVariable Long id) {
        return service.reactivateTenant(id);
    }

    @PostMapping("/tenants/{id}/reset-password")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    @Operation(summary = "Reset password for the tenant's Owner/Admin")
    public ResponseEntity<Void> resetPassword(
            @PathVariable Long id,
            @Valid @RequestBody ResetPasswordRequest req) {
        service.resetTenantOwnerPassword(id, req);
        return ResponseEntity.noContent().build();
    }
}
