package com.dsp.crusher.controller;

import com.dsp.crusher.dto.DashboardResponse;
import com.dsp.crusher.dto.SiteStaffDashboardResponse;
import com.dsp.crusher.service.DashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final DashboardService service;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER_ADMIN','OFFICE_ACCOUNTANT')")
    public DashboardResponse get() {
        return service.get();
    }

    @GetMapping("/site-staff")
    @PreAuthorize("hasRole('SITE_STAFF')")
    public SiteStaffDashboardResponse getSiteStaff() {
        return service.getSiteStaff();
    }
}
