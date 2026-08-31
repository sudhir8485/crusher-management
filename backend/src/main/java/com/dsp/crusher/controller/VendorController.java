package com.dsp.crusher.controller;

import com.dsp.crusher.dto.VendorRequest;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.service.VendorService;
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
@RequestMapping("/api/vendors")
@Tag(name = "Vendors")
@RequiredArgsConstructor
public class VendorController {

    private final VendorService service;

    @GetMapping
    @Operation(summary = "List all active vendors")
    public List<Vendor> list() {
        return service.listActive();
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get vendor by ID")
    public Vendor get(@PathVariable Long id) {
        return service.getById(id);
    }

    @PostMapping
    @Operation(summary = "Add a new vendor")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public ResponseEntity<Vendor> create(@Valid @RequestBody VendorRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(req));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update vendor")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public Vendor update(@PathVariable Long id, @Valid @RequestBody VendorRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Deactivate vendor")
    @PreAuthorize("hasRole('OWNER_ADMIN')")
    public ResponseEntity<Void> deactivate(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
