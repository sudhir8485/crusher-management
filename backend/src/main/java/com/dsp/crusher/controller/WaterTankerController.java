package com.dsp.crusher.controller;

import com.dsp.crusher.dto.WaterTankerLogRequest;
import com.dsp.crusher.dto.WaterTankerLogResponse;
import com.dsp.crusher.service.WaterTankerService;
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
@RequestMapping("/api/water-tanker")
@Tag(name = "Water Tanker Log")
@RequiredArgsConstructor
public class WaterTankerController {

    private final WaterTankerService service;

    @GetMapping
    @Operation(summary = "List water tanker logs (optionally filter by date range and site)")
    public List<WaterTankerLogResponse> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) Long siteId) {
        if (from != null && to != null) return service.listByDateRange(from, to, siteId);
        if (from != null) return service.listByDate(from, siteId);
        return service.listAll(siteId);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get water tanker log by ID")
    public WaterTankerLogResponse get(@PathVariable Long id) {
        return service.getById(id);
    }

    @PostMapping
    @Operation(summary = "Log a water tanker work day")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT', 'SITE_STAFF')")
    public ResponseEntity<WaterTankerLogResponse> create(@Valid @RequestBody WaterTankerLogRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(req));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a water tanker log")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public WaterTankerLogResponse update(@PathVariable Long id, @Valid @RequestBody WaterTankerLogRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Delete (deactivate) a water tanker log")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public ResponseEntity<Void> deactivate(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
