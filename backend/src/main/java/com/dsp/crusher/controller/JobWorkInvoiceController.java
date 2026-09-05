package com.dsp.crusher.controller;

import com.dsp.crusher.dto.JobWorkInvoiceRequest;
import com.dsp.crusher.dto.JobWorkInvoiceResponse;
import com.dsp.crusher.dto.PageResponse;
import com.dsp.crusher.service.JobWorkInvoiceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;

@RestController
@RequestMapping("/api/job-work-invoices")
@RequiredArgsConstructor
public class JobWorkInvoiceController {

    private final JobWorkInvoiceService service;

    @GetMapping
    public PageResponse<JobWorkInvoiceResponse> list(
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "25") int size) {
        return service.list(page, size);
    }

    @GetMapping("/{id}")
    public JobWorkInvoiceResponse get(@PathVariable Long id) {
        return service.get(id);
    }

    @PostMapping
    public JobWorkInvoiceResponse create(@Valid @RequestBody JobWorkInvoiceRequest req) {
        return service.create(req);
    }

    @PutMapping("/{id}")
    public JobWorkInvoiceResponse update(@PathVariable Long id,
                                          @Valid @RequestBody JobWorkInvoiceRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.deactivate(id);
        return ResponseEntity.noContent().build();
    }

    /** Recalculate GST from Service Master — only on PENDING invoices. */
    @PostMapping("/{id}/recalculate-gst")
    public JobWorkInvoiceResponse recalculateGst(@PathVariable Long id) {
        return service.recalculateGst(id);
    }

    /** Set GST rate directly on a PENDING invoice (no Service Master lookup). */
    @PostMapping("/{id}/set-gst-rate")
    public JobWorkInvoiceResponse setGstRate(@PathVariable Long id,
                                              @RequestParam BigDecimal rate) {
        return service.setGstRate(id, rate);
    }
}
