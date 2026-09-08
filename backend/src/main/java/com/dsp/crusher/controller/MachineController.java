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
    @Operation(summary = "List machines. Default: active only. ?includeInactive=true to include inactive.")
    public List<MachineResponse> list(
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return includeInactive ? service.listAll() : service.listActive();
    }

    @GetMapping("/{id}")
    public MachineResponse get(@PathVariable Long id) {
        return service.getById(id);
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public ResponseEntity<MachineResponse> create(@Valid @RequestBody MachineRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(req));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public MachineResponse update(@PathVariable Long id, @Valid @RequestBody MachineRequest req) {
        return service.update(id, req);
    }

    @PatchMapping("/{id}/toggle-active")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    @Operation(summary = "Toggle is_active flag — instantly hides/shows in pickers without deleting")
    public MachineResponse toggleActive(@PathVariable Long id) {
        return service.toggleActive(id);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('OWNER_ADMIN')")
    @Operation(summary = "Permanently soft-delete. Blocked if historical data exists — use toggle instead.")
    public ResponseEntity<Void> deactivate(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
