package com.dsp.crusher.controller;

import com.dsp.crusher.dto.DabarEntryRequest;
import com.dsp.crusher.dto.DabarEntryResponse;
import com.dsp.crusher.service.DabarService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/dabar")
@Tag(name = "Dabar (Raw Stone Intake)")
@RequiredArgsConstructor
public class DabarController {

    private final DabarService service;

    @GetMapping
    @Operation(summary = "List dabar entries (optionally filter by date range and site)")
    public List<DabarEntryResponse> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) Long siteId) {
        if (from != null && to != null) return service.listByDateRange(from, to, siteId);
        if (from != null) return service.listByDate(from, siteId);
        return service.listAll(siteId);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get dabar entry by ID")
    public DabarEntryResponse get(@PathVariable Long id) {
        return service.getById(id);
    }

    @PostMapping
    @Operation(summary = "Record a new dabar (raw stone) intake entry")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT', 'SITE_STAFF')")
    public ResponseEntity<DabarEntryResponse> create(
            @Valid @RequestBody DabarEntryRequest req,
            @RequestParam(required = false) Long siteId) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(req, siteId));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a dabar entry")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public DabarEntryResponse update(@PathVariable Long id, @Valid @RequestBody DabarEntryRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Delete (deactivate) a dabar entry")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public ResponseEntity<Void> deactivate(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
