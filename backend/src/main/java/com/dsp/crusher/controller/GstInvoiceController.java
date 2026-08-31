package com.dsp.crusher.controller;

import com.dsp.crusher.dto.GstInvoiceRequest;
import com.dsp.crusher.dto.GstInvoiceResponse;
import com.dsp.crusher.service.GstInvoiceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/invoices")
@RequiredArgsConstructor
public class GstInvoiceController {

    private final GstInvoiceService service;

    @GetMapping
    public List<GstInvoiceResponse> list(
            @RequestParam(required = false) Long vendorId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return service.list(vendorId, from, to);
    }

    @GetMapping("/{id}")
    public GstInvoiceResponse get(@PathVariable Long id) {
        return service.get(id);
    }

    @PostMapping
    public GstInvoiceResponse create(@Valid @RequestBody GstInvoiceRequest req) {
        return service.create(req);
    }

    @PutMapping("/{id}")
    public GstInvoiceResponse update(@PathVariable Long id, @Valid @RequestBody GstInvoiceRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
