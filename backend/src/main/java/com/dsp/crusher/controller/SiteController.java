package com.dsp.crusher.controller;

import com.dsp.crusher.dto.SiteRequest;
import com.dsp.crusher.entity.Site;
import com.dsp.crusher.service.SiteService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/sites")
@Tag(name = "Sites")
@RequiredArgsConstructor
public class SiteController {

    private final SiteService service;

    @GetMapping
    @Operation(summary = "List all active sites")
    public List<Site> list() {
        return service.listActive();
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get site by ID")
    public Site get(@PathVariable Long id) {
        return service.getById(id);
    }

    @PostMapping
    @Operation(summary = "Add a new site")
    @PreAuthorize("hasRole('OWNER_ADMIN')")
    public ResponseEntity<Site> create(@Valid @RequestBody SiteRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(req));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update site")
    @PreAuthorize("hasRole('OWNER_ADMIN')")
    public Site update(@PathVariable Long id, @Valid @RequestBody SiteRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Deactivate site")
    @PreAuthorize("hasRole('OWNER_ADMIN')")
    public ResponseEntity<Void> deactivate(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
