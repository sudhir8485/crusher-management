package com.dsp.crusher.controller;

import com.dsp.crusher.dto.VendorLedgerResponse;
import com.dsp.crusher.service.LedgerService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/ledger")
@RequiredArgsConstructor
public class LedgerController {

    private final LedgerService service;

    @GetMapping("/vendor/{vendorId}")
    public VendorLedgerResponse vendorLedger(
            @PathVariable Long vendorId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {

        LocalDate effectiveTo   = (to   != null) ? to   : LocalDate.now();
        LocalDate effectiveFrom = (from != null) ? from : effectiveTo.withDayOfMonth(1);
        return service.vendorLedger(vendorId, effectiveFrom, effectiveTo);
    }
}
