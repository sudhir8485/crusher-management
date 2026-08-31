package com.dsp.crusher.controller;

import com.dsp.crusher.dto.DailyReportResponse;
import com.dsp.crusher.dto.TripRequest;
import com.dsp.crusher.dto.TripResponse;
import com.dsp.crusher.service.TripService;
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
@RequestMapping("/api/trips")
@Tag(name = "Trips")
@RequiredArgsConstructor
public class TripController {

    private final TripService service;

    @GetMapping
    @Operation(summary = "List trips (optionally filter by date range)")
    public List<TripResponse> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        if (from != null && to != null) return service.listByDateRange(from, to);
        if (from != null) return service.listByDate(from);
        return service.listAll();
    }

    @GetMapping("/daily-report")
    @Operation(summary = "Daily material sale report for a given date")
    public DailyReportResponse dailyReport(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return service.dailyReport(date != null ? date : LocalDate.now());
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get trip by ID")
    public TripResponse get(@PathVariable Long id) {
        return service.getById(id);
    }

    @PostMapping
    @Operation(summary = "Create a new trip entry")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT', 'SITE_STAFF')")
    public ResponseEntity<TripResponse> create(@Valid @RequestBody TripRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(req));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a trip")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public TripResponse update(@PathVariable Long id, @Valid @RequestBody TripRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Delete (deactivate) a trip")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public ResponseEntity<Void> deactivate(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
