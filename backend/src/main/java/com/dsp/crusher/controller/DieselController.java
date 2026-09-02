package com.dsp.crusher.controller;

import com.dsp.crusher.dto.*;
import com.dsp.crusher.service.DieselService;
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
@RequestMapping("/api/diesel")
@Tag(name = "Diesel")
@RequiredArgsConstructor
public class DieselController {

    private final DieselService service;

    @GetMapping("/balance")
    @Operation(summary = "Current diesel stock balance (total received - total used)")
    public DieselBalanceResponse balance(@RequestParam(required = false) Long siteId) {
        return service.balance(siteId);
    }

    // ── Receipts ──────────────────────────────────────────────────────────────

    @GetMapping("/receipts")
    @Operation(summary = "List diesel receipts (optionally filter by date range and site)")
    public List<DieselReceiptResponse> listReceipts(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) Long siteId) {
        return service.listReceipts(from, to, siteId);
    }

    @GetMapping("/receipts/{id}")
    @Operation(summary = "Get diesel receipt by ID")
    public DieselReceiptResponse getReceipt(@PathVariable Long id) {
        return service.getReceipt(id);
    }

    @PostMapping("/receipts")
    @Operation(summary = "Record a diesel receipt (pump or direct)")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT', 'SITE_STAFF')")
    public ResponseEntity<DieselReceiptResponse> createReceipt(
            @Valid @RequestBody DieselReceiptRequest req,
            @RequestParam(required = false) Long siteId) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.createReceipt(req, siteId));
    }

    @PutMapping("/receipts/{id}")
    @Operation(summary = "Update a diesel receipt")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public DieselReceiptResponse updateReceipt(@PathVariable Long id, @Valid @RequestBody DieselReceiptRequest req) {
        return service.updateReceipt(id, req);
    }

    @DeleteMapping("/receipts/{id}")
    @Operation(summary = "Delete (deactivate) a diesel receipt")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public ResponseEntity<Void> deactivateReceipt(@PathVariable Long id) {
        service.deactivateReceipt(id);
        return ResponseEntity.noContent().build();
    }

    // ── Usages ────────────────────────────────────────────────────────────────

    @GetMapping("/usages")
    @Operation(summary = "List diesel usage entries (optionally filter by date range and site)")
    public List<DieselUsageResponse> listUsages(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) Long siteId) {
        return service.listUsages(from, to, siteId);
    }

    @GetMapping("/usages/{id}")
    @Operation(summary = "Get diesel usage by ID")
    public DieselUsageResponse getUsage(@PathVariable Long id) {
        return service.getUsage(id);
    }

    @PostMapping("/usages")
    @Operation(summary = "Record diesel used by a machine or vehicle")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT', 'SITE_STAFF')")
    public ResponseEntity<DieselUsageResponse> createUsage(
            @Valid @RequestBody DieselUsageRequest req,
            @RequestParam(required = false) Long siteId) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.createUsage(req, siteId));
    }

    @PutMapping("/usages/{id}")
    @Operation(summary = "Update a diesel usage entry")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public DieselUsageResponse updateUsage(@PathVariable Long id, @Valid @RequestBody DieselUsageRequest req) {
        return service.updateUsage(id, req);
    }

    @DeleteMapping("/usages/{id}")
    @Operation(summary = "Delete (deactivate) a diesel usage entry")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public ResponseEntity<Void> deactivateUsage(@PathVariable Long id) {
        service.deactivateUsage(id);
        return ResponseEntity.noContent().build();
    }
}
