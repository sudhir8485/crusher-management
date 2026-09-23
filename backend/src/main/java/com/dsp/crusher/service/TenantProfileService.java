package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.TenantProfileRequest;
import com.dsp.crusher.dto.TenantProfileResponse;
import com.dsp.crusher.entity.Tenant;
import com.dsp.crusher.repository.TenantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class TenantProfileService {

    private final TenantRepository tenantRepo;

    public TenantProfileResponse get() {
        Long tenantId = TenantContext.get();
        Tenant t = tenantRepo.findById(tenantId)
                .orElseThrow(() -> new RuntimeException("Tenant not found"));
        return toResponse(t);
    }

    @Transactional
    public TenantProfileResponse update(TenantProfileRequest req) {
        Long tenantId = TenantContext.get();
        Tenant t = tenantRepo.findById(tenantId)
                .orElseThrow(() -> new RuntimeException("Tenant not found"));

        if (req.getName() != null && !req.getName().isBlank()) {
            t.setName(req.getName().trim());
        }
        t.setAddress(req.getAddress());
        t.setPhone(req.getPhone());
        t.setEmail(req.getEmail());
        t.setGstin(req.getGstin());
        if (req.getLogoBase64() != null) {
            t.setLogoBase64(req.getLogoBase64().isBlank() ? null : req.getLogoBase64());
        }
        if (req.getBankName()      != null) t.setBankName(req.getBankName().isBlank()      ? null : req.getBankName().trim());
        if (req.getBankAccountNo() != null) t.setBankAccountNo(req.getBankAccountNo().isBlank() ? null : req.getBankAccountNo().trim());
        if (req.getBankIfsc()      != null) t.setBankIfsc(req.getBankIfsc().isBlank()      ? null : req.getBankIfsc().trim().toUpperCase());
        if (req.getInvoicePrefix() != null) {
            String prefix = req.getInvoicePrefix().trim().toUpperCase();
            if (!prefix.isBlank()) t.setInvoicePrefix(prefix);
        }
        if (req.getInvoiceTerms() != null) t.setInvoiceTerms(req.getInvoiceTerms().isBlank() ? null : req.getInvoiceTerms().trim());
        t.setUpdatedAt(LocalDateTime.now());
        return toResponse(tenantRepo.save(t));
    }

    private TenantProfileResponse toResponse(Tenant t) {
        return new TenantProfileResponse(
                t.getId(), t.getName(), t.getAddress(),
                t.getPhone(), t.getEmail(), t.getGstin(), t.getLogoBase64(),
                t.getBankName(), t.getBankAccountNo(), t.getBankIfsc(),
                t.getInvoicePrefix() != null ? t.getInvoicePrefix() : "INV",
                t.getInvoiceTerms());
    }
}
