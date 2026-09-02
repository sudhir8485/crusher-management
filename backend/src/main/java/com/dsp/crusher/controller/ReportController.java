package com.dsp.crusher.controller;

import com.dsp.crusher.dto.ConsolidatedDailyReport;
import com.dsp.crusher.dto.ReportResponse;
import com.dsp.crusher.service.DailyReportService;
import com.dsp.crusher.service.ReportService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/reports")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER_ADMIN','OFFICE_ACCOUNTANT','SITE_STAFF')")
public class ReportController {

    private final ReportService service;
    private final DailyReportService dailyService;

    @GetMapping("/daily")
    public ConsolidatedDailyReport daily(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return dailyService.build(date != null ? date : LocalDate.now());
    }

    private LocalDate defaultFrom(LocalDate to) {
        return to.withDayOfMonth(1);
    }

    @GetMapping("/vehicle-log")
    public ReportResponse vehicleLog(
            @RequestParam(required = false) Long vehicleId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        LocalDate effectiveTo   = to   != null ? to   : LocalDate.now();
        LocalDate effectiveFrom = from != null ? from : defaultFrom(effectiveTo);
        return service.vehicleLogReport(vehicleId, effectiveFrom, effectiveTo);
    }

    @GetMapping("/machine-work")
    public ReportResponse machineWork(
            @RequestParam(required = false) Long machineId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        LocalDate effectiveTo   = to   != null ? to   : LocalDate.now();
        LocalDate effectiveFrom = from != null ? from : defaultFrom(effectiveTo);
        return service.machineWorkReport(machineId, effectiveFrom, effectiveTo);
    }

    @GetMapping("/diesel")
    public ReportResponse diesel(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        LocalDate effectiveTo   = to   != null ? to   : LocalDate.now();
        LocalDate effectiveFrom = from != null ? from : defaultFrom(effectiveTo);
        return service.dieselReport(effectiveFrom, effectiveTo);
    }

    @GetMapping("/trips")
    public ReportResponse trips(
            @RequestParam(required = false) Long vehicleId,
            @RequestParam(required = false) Long materialId,
            @RequestParam(required = false) Long vendorId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        LocalDate effectiveTo   = to   != null ? to   : LocalDate.now();
        LocalDate effectiveFrom = from != null ? from : defaultFrom(effectiveTo);
        return service.tripsReport(vehicleId, materialId, vendorId, effectiveFrom, effectiveTo);
    }
}
