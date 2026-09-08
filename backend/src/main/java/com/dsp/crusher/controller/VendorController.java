package com.dsp.crusher.controller;

import com.dsp.crusher.dto.PartyStatementResponse;
import com.dsp.crusher.dto.VendorBalanceResponse;
import com.dsp.crusher.dto.VendorRequest;
import com.dsp.crusher.dto.VendorResponse;
import com.dsp.crusher.dto.VendorTripBalanceResponse;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.service.VendorService;
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
@RequestMapping("/api/parties")
@Tag(name = "Parties")
@RequiredArgsConstructor
public class VendorController {

    private final VendorService service;

    @GetMapping
    @Operation(summary = "List parties. Default: active only. ?includeInactive=true to include inactive.")
    public List<VendorResponse> list(
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return includeInactive ? service.listAll() : service.listActive();
    }

    @GetMapping("/balances")
    @Operation(summary = "All parties with trip-based outstanding balance + last activity date")
    public List<VendorBalanceResponse> balances() {
        return service.getBalances();
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get party by ID")
    public Vendor get(@PathVariable Long id) {
        return service.getById(id);
    }

    @GetMapping("/{id}/statement")
    @Operation(summary = "Khatabook-style trip+payment statement with running balance")
    public PartyStatementResponse statement(
            @PathVariable Long id,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return service.getStatement(id, from, to);
    }

    @GetMapping("/{id}/trip-balance")
    @Operation(summary = "Get trip-based outstanding balance and trip list for FIFO preview")
    public VendorTripBalanceResponse tripBalance(@PathVariable Long id) {
        return service.getTripBalance(id);
    }

    @PostMapping
    @Operation(summary = "Add a new party")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public ResponseEntity<Vendor> create(@Valid @RequestBody VendorRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(req));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update party")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    public Vendor update(@PathVariable Long id, @Valid @RequestBody VendorRequest req) {
        return service.update(id, req);
    }

    @PatchMapping("/{id}/toggle-active")
    @PreAuthorize("hasAnyRole('OWNER_ADMIN', 'OFFICE_ACCOUNTANT')")
    @Operation(summary = "Toggle is_active flag — instantly hides/shows in pickers without deleting")
    public VendorResponse toggleActive(@PathVariable Long id) {
        return service.toggleActive(id);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Permanently soft-delete. Blocked if historical data exists — use toggle instead.")
    @PreAuthorize("hasRole('OWNER_ADMIN')")
    public ResponseEntity<Void> deactivate(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
