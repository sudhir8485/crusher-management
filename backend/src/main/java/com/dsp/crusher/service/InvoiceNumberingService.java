package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.repository.GstInvoiceRepository;
import com.dsp.crusher.repository.JobWorkInvoiceRepository;
import com.dsp.crusher.repository.TenantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;

/**
 * Single source of truth for invoice number generation.
 * Counts across BOTH gst_invoices and job_work_invoices so the FY/N
 * sequence is continuous regardless of invoice type.
 * Invoice prefix is tenant-configurable (e.g. "DSP", "ABC") via Business Profile.
 */
@Service
@RequiredArgsConstructor
public class InvoiceNumberingService {

    private final GstInvoiceRepository    gstRepo;
    private final JobWorkInvoiceRepository jwRepo;
    private final TenantRepository        tenantRepo;

    public String nextInvoiceNo(LocalDate date) {
        int year = date.getMonthValue() >= 4 ? date.getYear() : date.getYear() - 1;
        String fy = year + "-" + String.format("%02d", (year + 1) % 100);

        Long tenantId = TenantContext.get();
        String tenantPrefix = tenantRepo.findById(tenantId)
                .map(t -> t.getInvoicePrefix() != null ? t.getInvoicePrefix().trim() : "INV")
                .orElse("INV");

        String prefix = tenantPrefix + "/" + fy + "/";
        long count = gstRepo.countByTenantIdAndInvoiceNoStartingWith(tenantId, prefix)
                   + jwRepo.countByTenantIdAndInvoiceNoStartingWith(tenantId, prefix);
        return prefix + (count + 1);
    }
}
