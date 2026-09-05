package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.repository.GstInvoiceRepository;
import com.dsp.crusher.repository.JobWorkInvoiceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;

/**
 * Single source of truth for invoice number generation.
 * Counts across BOTH gst_invoices and job_work_invoices so the DSP/FY/N
 * sequence is continuous regardless of invoice type.
 */
@Service
@RequiredArgsConstructor
public class InvoiceNumberingService {

    private final GstInvoiceRepository    gstRepo;
    private final JobWorkInvoiceRepository jwRepo;

    public String nextInvoiceNo(LocalDate date) {
        int year = date.getMonthValue() >= 4 ? date.getYear() : date.getYear() - 1;
        String fy     = year + "-" + String.format("%02d", (year + 1) % 100);
        String prefix = "DSP/" + fy + "/";
        long count = gstRepo.countByTenantIdAndInvoiceNoStartingWith(TenantContext.get(), prefix)
                   + jwRepo.countByTenantIdAndInvoiceNoStartingWith(TenantContext.get(), prefix);
        return prefix + (count + 1);
    }
}
