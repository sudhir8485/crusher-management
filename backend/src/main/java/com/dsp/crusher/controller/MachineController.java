package com.dsp.crusher.controller;

import com.dsp.crusher.dto.MachineRequest;
import com.dsp.crusher.dto.MachineResponse;
import com.dsp.crusher.service.MachineService;
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
@RequestMapping("/api/machines")
@Tag(name = "Machines")
@RequiredArgsConstructor
public class MachineController {

    private final MachineService service;

    @GetMapping
    @Operation(summary = "List all active machines with their work types")
    public List<MachineResponse> list() {
        return service.listActive();
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get machine by ID")
    public MachineResponse get(@PathVariable Long id) {
        return service.getById(id);
    }

    @PostMapping
    @Operation(summary = "Add a new machine")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public ResponseEntity<MachineResponse> create(@Valid @RequestBody MachineRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(req));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update machine and its work types")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public MachineResponse update(@PathVariable Long id, @Valid @RequestBody MachineRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Deactivate machine (blocked if linked vehicle is active)")
    @PreAuthorize("hasRole('OWNER_ADMIN')")
    public ResponseEntity<Void> deactivate(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
