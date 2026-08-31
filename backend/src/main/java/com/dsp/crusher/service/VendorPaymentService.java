package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.VendorPaymentRequest;
import com.dsp.crusher.dto.VendorPaymentResponse;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.entity.VendorPayment;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.VendorPaymentRepository;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class VendorPaymentService {

    private final VendorPaymentRepository repo;
    private final VendorRepository vendorRepo;

    public List<VendorPaymentResponse> list(Long vendorId, LocalDate from, LocalDate to) {
        List<VendorPayment> rows;
        if (vendorId != null)
            rows = repo.findByVendorIdAndStatusOrderByPaymentDateDescIdDesc(vendorId, "ACTIVE");
        else if (from != null && to != null)
            rows = repo.findByPaymentDateBetweenAndStatusOrderByPaymentDateDescIdDesc(from, to, "ACTIVE");
        else
            rows = repo.findByStatusOrderByPaymentDateDescIdDesc("ACTIVE");
        return enrich(rows);
    }

    public VendorPaymentResponse get(Long id) {
        VendorPayment p = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("VendorPayment not found: " + id));
        return enrich(List.of(p)).get(0);
    }

    @Transactional
    public VendorPaymentResponse create(VendorPaymentRequest req) {
        VendorPayment p = new VendorPayment();
        p.setTenantId(TenantContext.get());
        apply(p, req);
        return enrich(List.of(repo.save(p))).get(0);
    }

    @Transactional
    public VendorPaymentResponse update(Long id, VendorPaymentRequest req) {
        VendorPayment p = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("VendorPayment not found: " + id));
        apply(p, req);
        return enrich(List.of(repo.save(p))).get(0);
    }

    @Transactional
    public void deactivate(Long id) {
        VendorPayment p = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("VendorPayment not found: " + id));
        p.setStatus("INACTIVE");
        repo.save(p);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private void apply(VendorPayment p, VendorPaymentRequest req) {
        p.setVendorId(req.getVendorId());
        p.setPaymentDate(req.getPaymentDate());
        p.setAmount(req.getAmount());
        p.setPaymentMode(req.getPaymentMode() != null ? req.getPaymentMode() : "CASH");
        p.setReferenceNo(req.getReferenceNo());
        p.setNotes(req.getNotes());
    }

    private List<VendorPaymentResponse> enrich(List<VendorPayment> rows) {
        List<Long> vendorIds = rows.stream()
                .map(VendorPayment::getVendorId).distinct().collect(Collectors.toList());
        Map<Long, Vendor> vendors = vendorRepo.findAllById(vendorIds).stream()
                .collect(Collectors.toMap(Vendor::getId, v -> v));

        return rows.stream().map(p -> {
            VendorPaymentResponse r = new VendorPaymentResponse();
            r.setId(p.getId());
            r.setVendorId(p.getVendorId());
            r.setPaymentDate(p.getPaymentDate());
            r.setAmount(p.getAmount());
            r.setPaymentMode(p.getPaymentMode());
            r.setReferenceNo(p.getReferenceNo());
            r.setNotes(p.getNotes());
            r.setStatus(p.getStatus());
            Vendor v = vendors.get(p.getVendorId());
            if (v != null) r.setVendorName(v.getName());
            return r;
        }).collect(Collectors.toList());
    }
}
