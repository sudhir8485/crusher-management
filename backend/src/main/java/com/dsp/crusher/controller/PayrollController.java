package com.dsp.crusher.controller;

import com.dsp.crusher.dto.PayrollSummaryResponse;
import com.dsp.crusher.dto.RecordAdvanceRequest;
import com.dsp.crusher.service.PayrollService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

@RestController
@RequestMapping("/api/payroll")
@RequiredArgsConstructor
public class PayrollController {

    private final PayrollService service;

    @GetMapping
    public List<PayrollSummaryResponse> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        LocalDate[] range = resolveRange(from, to);
        return service.listPayroll(range[0], range[1]);
    }

    @GetMapping("/{employeeId}")
    public PayrollSummaryResponse detail(
            @PathVariable Long employeeId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        LocalDate[] range = resolveRange(from, to);
        return service.getEmployeePayroll(employeeId, range[0], range[1]);
    }

    @PostMapping("/advances")
    public PayrollSummaryResponse.AdvanceEntry recordAdvance(
            @Valid @RequestBody RecordAdvanceRequest req) {
        return service.recordAdvance(req);
    }

    @PutMapping("/advances/{id}")
    public PayrollSummaryResponse.AdvanceEntry updateAdvance(
            @PathVariable Long id,
            @Valid @RequestBody RecordAdvanceRequest req) {
        return service.updateAdvance(id, req);
    }

    @DeleteMapping("/advances/{id}")
    public ResponseEntity<Void> deleteAdvance(@PathVariable Long id) {
        service.deleteAdvance(id);
        return ResponseEntity.noContent().build();
    }

    private LocalDate[] resolveRange(LocalDate from, LocalDate to) {
        YearMonth current = YearMonth.now();
        LocalDate effectiveTo   = to   != null ? to   : current.atEndOfMonth();
        LocalDate effectiveFrom = from != null ? from : current.atDay(1);
        return new LocalDate[]{effectiveFrom, effectiveTo};
    }
}
