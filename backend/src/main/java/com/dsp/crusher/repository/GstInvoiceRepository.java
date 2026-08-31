package com.dsp.crusher.repository;

import com.dsp.crusher.entity.GstInvoice;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;

public interface GstInvoiceRepository extends JpaRepository<GstInvoice, Long> {

    List<GstInvoice> findByStatusOrderByInvoiceDateDescIdDesc(String status);

    List<GstInvoice> findByVendorIdAndStatusOrderByInvoiceDateDescIdDesc(Long vendorId, String status);

    List<GstInvoice> findByInvoiceDateBetweenAndStatusOrderByInvoiceDateDescIdDesc(
            LocalDate from, LocalDate to, String status);

    long countByTenantIdAndInvoiceNoStartingWith(Long tenantId, String prefix);
}
