package com.dsp.crusher.controller;

import com.dsp.crusher.dto.ServiceRequest;
import com.dsp.crusher.entity.ServiceRecord;
import com.dsp.crusher.service.ServiceMasterService;
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
@RequestMapping("/api/services")
@Tag(name = "Services")
@RequiredArgsConstructor
public class ServiceController {

    private final ServiceMasterService service;

    @GetMapping
    @Operation(summary = "List all active services")
    public List<ServiceRecord> list() {
        return service.listActive();
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get service by ID")
    public ServiceRecord get(@PathVariable Long id) {
        return service.getById(id);
    }

    @PostMapping
    @Operation(summary = "Add a new service")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public ResponseEntity<ServiceRecord> create(@Valid @RequestBody ServiceRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(req));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update service")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public ServiceRecord update(@PathVariable Long id, @Valid @RequestBody ServiceRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Deactivate service")
    @PreAuthorize("hasRole('OWNER_ADMIN')")
    public ResponseEntity<Void> deactivate(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
