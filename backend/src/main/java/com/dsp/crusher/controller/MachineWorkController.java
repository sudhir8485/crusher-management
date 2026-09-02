package com.dsp.crusher.controller;

import com.dsp.crusher.dto.MachineWorkLogRequest;
import com.dsp.crusher.dto.MachineWorkLogResponse;
import com.dsp.crusher.service.MachineWorkService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/machine-work")
@RequiredArgsConstructor
public class MachineWorkController {

    private final MachineWorkService service;

    @GetMapping
    public List<MachineWorkLogResponse> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) Long siteId) {
        return service.list(from, to, siteId);
    }

    @GetMapping("/{id}")
    public MachineWorkLogResponse get(@PathVariable Long id) {
        return service.get(id);
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT', 'SITE_STAFF')")
    public MachineWorkLogResponse create(
            @Valid @RequestBody MachineWorkLogRequest req,
            @RequestParam(required = false) Long siteId) {
        return service.create(req, siteId);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public MachineWorkLogResponse update(@PathVariable Long id, @Valid @RequestBody MachineWorkLogRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
