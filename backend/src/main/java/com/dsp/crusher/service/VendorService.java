package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.VendorRequest;
import com.dsp.crusher.dto.VendorResponse;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.GstInvoiceRepository;
import com.dsp.crusher.repository.VendorPaymentRepository;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class VendorService {

    private final VendorRepository repo;
    private final GstInvoiceRepository invoiceRepo;
    private final VendorPaymentRepository paymentRepo;

    public List<VendorResponse> listActive() {
        return repo.findByStatus("ACTIVE").stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    private VendorResponse toResponse(Vendor v) {
        VendorResponse r = new VendorResponse();
        r.setId(v.getId());
        r.setName(v.getName());
        r.setGstin(v.getGstin());
        r.setContact(v.getContact());
        r.setAddress(v.getAddress());
        r.setStatus(v.getStatus());
        BigDecimal invTotal = invoiceRepo.sumAllGrandTotalByVendorId(v.getId());
        BigDecimal paidTotal = paymentRepo.sumByVendorId(v.getId());
        r.setOutstandingAmount(invTotal.subtract(paidTotal));
        r.setUnpaidInvoiceCount(0); // computed from outstanding; kept for future
        return r;
    }

    public Vendor getById(Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Vendor not found: " + id));
    }

    @Transactional
    public Vendor create(VendorRequest req) {
        Vendor v = new Vendor();
        v.setTenantId(TenantContext.get());
        v.setName(req.getName());
        v.setGstin(req.getGstin());
        v.setContact(req.getContact());
        v.setAddress(req.getAddress());
        return repo.save(v);
    }

    @Transactional
    public Vendor update(Long id, VendorRequest req) {
        Vendor v = getById(id);
        v.setName(req.getName());
        v.setGstin(req.getGstin());
        v.setContact(req.getContact());
        v.setAddress(req.getAddress());
        return repo.save(v);
    }

    @Transactional
    public void deactivate(Long id) {
        Vendor v = getById(id);
        v.setStatus("INACTIVE");
        repo.save(v);
    }
}
