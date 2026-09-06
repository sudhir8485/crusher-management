package com.dsp.crusher.controller;

import com.dsp.crusher.dto.AutoQtyResponse;
import com.dsp.crusher.dto.JobWorkInvoiceRequest;
import com.dsp.crusher.dto.JobWorkInvoiceResponse;
import com.dsp.crusher.dto.PageResponse;
import com.dsp.crusher.service.JobWorkInvoiceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;

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

    /** Auto-calculate quantity from underlying records for a Job-Work invoice line.
     *  Source (TRIP_QUANTITIES or DABAR_QUANTITIES) is determined by the service's configuration.
     *  Returns unbilled quantity, billed-count info, and period-overlap warning.
     *  Pass excludeInvoiceId when editing an existing invoice so its own linked records are treated as available. */
    @GetMapping("/auto-qty")
    public AutoQtyResponse autoQty(
            @RequestParam Long siteId,
            @RequestParam Long serviceId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) Long excludeInvoiceId) {
        return service.calcAutoQty(siteId, serviceId, from, to, excludeInvoiceId);
    }
}
