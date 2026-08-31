package com.dsp.crusher.controller;

import com.dsp.crusher.dto.AttendanceDayResponse;
import com.dsp.crusher.dto.AttendanceMarkRequest;
import com.dsp.crusher.service.AttendanceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/attendance")
@RequiredArgsConstructor
public class AttendanceController {

    private final AttendanceService service;

    @GetMapping
    public AttendanceDayResponse getDay(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return service.getDay(date != null ? date : LocalDate.now());
    }

    @PostMapping("/mark")
    public AttendanceDayResponse mark(@Valid @RequestBody AttendanceMarkRequest req) {
        return service.mark(req);
    }
}
