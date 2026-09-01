package com.dsp.crusher.controller;

import com.dsp.crusher.dto.PageResponse;
import com.dsp.crusher.dto.VendorPaymentRequest;
import com.dsp.crusher.dto.VendorPaymentResponse;
import com.dsp.crusher.service.VendorPaymentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/vendor-payments")
@RequiredArgsConstructor
public class VendorPaymentController {

    private final VendorPaymentService service;

    @GetMapping
    public PageResponse<VendorPaymentResponse> list(
            @RequestParam(required = false) Long vendorId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "25") int size) {
        return service.list(vendorId, from, to, page, size);
    }

    @GetMapping("/{id}")
    public VendorPaymentResponse get(@PathVariable Long id) {
        return service.get(id);
    }

    @PostMapping
    public VendorPaymentResponse create(@Valid @RequestBody VendorPaymentRequest req) {
        return service.create(req);
    }

    @PutMapping("/{id}")
    public VendorPaymentResponse update(@PathVariable Long id, @Valid @RequestBody VendorPaymentRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
