package com.dsp.crusher.controller;

import com.dsp.crusher.dto.VehicleDailyLogRequest;
import com.dsp.crusher.dto.VehicleDailyLogResponse;
import com.dsp.crusher.service.VehicleDailyLogService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/vehicle-daily-log")
@RequiredArgsConstructor
public class VehicleDailyLogController {

    private final VehicleDailyLogService service;

    @GetMapping
    public List<VehicleDailyLogResponse> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) Long siteId) {
        return service.list(from, to, siteId);
    }

    @GetMapping("/{id}")
    public VehicleDailyLogResponse get(@PathVariable Long id) {
        return service.get(id);
    }

    @PostMapping
    public VehicleDailyLogResponse create(
            @Valid @RequestBody VehicleDailyLogRequest req,
            @RequestParam(required = false) Long siteId) {
        return service.create(req, siteId);
    }

    @PutMapping("/{id}")
    public VehicleDailyLogResponse update(@PathVariable Long id, @Valid @RequestBody VehicleDailyLogRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
