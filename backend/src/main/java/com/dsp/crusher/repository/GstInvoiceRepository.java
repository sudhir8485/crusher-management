package com.dsp.crusher.repository;

import com.dsp.crusher.entity.GstInvoice;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface GstInvoiceRepository extends JpaRepository<GstInvoice, Long> {

    List<GstInvoice> findByStatusOrderByInvoiceDateDescIdDesc(String status);
    Page<GstInvoice> findByStatusOrderByInvoiceDateDescIdDesc(String status, Pageable pageable);

    List<GstInvoice> findByVendorIdAndStatusOrderByInvoiceDateDescIdDesc(Long vendorId, String status);
    Page<GstInvoice> findByVendorIdAndStatusOrderByInvoiceDateDescIdDesc(Long vendorId, String status, Pageable pageable);

    List<GstInvoice> findByInvoiceDateBetweenAndStatusOrderByInvoiceDateDescIdDesc(
            LocalDate from, LocalDate to, String status);
    Page<GstInvoice> findByInvoiceDateBetweenAndStatusOrderByInvoiceDateDescIdDesc(
            LocalDate from, LocalDate to, String status, Pageable pageable);

    long countByTenantIdAndInvoiceNoStartingWith(Long tenantId, String prefix);

    @Query("SELECT COALESCE(SUM(i.grandTotal), 0) FROM GstInvoice i WHERE i.invoiceDate BETWEEN :from AND :to AND i.status = 'ACTIVE'")
    BigDecimal sumGrandTotalByDateRange(@Param("from") LocalDate from, @Param("to") LocalDate to);

    long countByInvoiceDateBetweenAndStatus(LocalDate from, LocalDate to, String status);

    List<GstInvoice> findByVendorIdAndInvoiceDateBetweenAndStatusOrderByInvoiceDateAscIdAsc(
            Long vendorId, LocalDate from, LocalDate to, String status);

    // All invoices for a vendor up to a date (for opening balance calculation)
    @Query("SELECT COALESCE(SUM(i.grandTotal), 0) FROM GstInvoice i WHERE i.vendorId = :vendorId AND i.invoiceDate < :before AND i.status = 'ACTIVE'")
    BigDecimal sumGrandTotalByVendorBefore(@Param("vendorId") Long vendorId, @Param("before") LocalDate before);

    // Total invoiced (all active invoices)
    @Query("SELECT COALESCE(SUM(i.grandTotal), 0) FROM GstInvoice i WHERE i.status = 'ACTIVE'")
    BigDecimal sumAllGrandTotal();
}
