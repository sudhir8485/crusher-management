package com.dsp.crusher.repository;

import com.dsp.crusher.entity.GstInvoice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface GstInvoiceRepository extends JpaRepository<GstInvoice, Long> {

    List<GstInvoice> findByStatusOrderByInvoiceDateDescIdDesc(String status);

    List<GstInvoice> findByVendorIdAndStatusOrderByInvoiceDateDescIdDesc(Long vendorId, String status);

    List<GstInvoice> findByInvoiceDateBetweenAndStatusOrderByInvoiceDateDescIdDesc(
            LocalDate from, LocalDate to, String status);

    long countByTenantIdAndInvoiceNoStartingWith(Long tenantId, String prefix);

    @Query("SELECT COALESCE(SUM(i.grandTotal), 0) FROM GstInvoice i WHERE i.invoiceDate BETWEEN :from AND :to AND i.status = 'ACTIVE'")
    BigDecimal sumGrandTotalByDateRange(@Param("from") LocalDate from, @Param("to") LocalDate to);

    long countByInvoiceDateBetweenAndStatus(LocalDate from, LocalDate to, String status);

    List<GstInvoice> findByVendorIdAndInvoiceDateBetweenAndStatusOrderByInvoiceDateAscIdAsc(
            Long vendorId, LocalDate from, LocalDate to, String status);

    // All invoices for a vendor up to a date (for opening balance calculation)
    @Query("SELECT COALESCE(SUM(i.grandTotal), 0) FROM GstInvoice i WHERE i.vendorId = :vendorId AND i.invoiceDate < :before AND i.status = 'ACTIVE'")
    BigDecimal sumGrandTotalByVendorBefore(@Param("vendorId") Long vendorId, @Param("before") LocalDate before);
}
