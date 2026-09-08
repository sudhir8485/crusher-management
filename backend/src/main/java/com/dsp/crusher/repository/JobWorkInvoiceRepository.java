package com.dsp.crusher.repository;

import com.dsp.crusher.entity.JobWorkInvoice;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface JobWorkInvoiceRepository extends JpaRepository<JobWorkInvoice, Long> {

    Page<JobWorkInvoice> findByStatusOrderByInvoiceDateDescIdDesc(String status, Pageable pageable);

    long countByTenantIdAndInvoiceNoStartingWith(Long tenantId, String prefix);

    // Ledger: load with items in one query to avoid N+1
    @Query("SELECT DISTINCT i FROM JobWorkInvoice i LEFT JOIN FETCH i.items " +
           "WHERE i.vendorId = :vendorId AND i.invoiceDate BETWEEN :from AND :to AND i.status = 'ACTIVE' " +
           "ORDER BY i.invoiceDate ASC, i.id ASC")
    List<JobWorkInvoice> findWithItemsByVendorAndDateRange(
            @Param("vendorId") Long vendorId,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to);

    // Opening balance: sum all active job-work invoices for this vendor before a date
    @Query("SELECT COALESCE(SUM(i.grandTotal), 0) FROM JobWorkInvoice i " +
           "WHERE i.vendorId = :vendorId AND i.invoiceDate < :before AND i.status = 'ACTIVE'")
    BigDecimal sumGrandTotalByVendorBefore(
            @Param("vendorId") Long vendorId,
            @Param("before") LocalDate before);

    /** Find active invoices for the same site + service whose period overlaps [from, to].
     *  Excludes invoices without a period set, and optionally the invoice being edited. */
    @Query("SELECT DISTINCT i FROM JobWorkInvoice i JOIN i.items item " +
           "WHERE i.siteId = :siteId AND item.serviceId = :serviceId AND i.status = 'ACTIVE' " +
           "AND i.periodFrom IS NOT NULL AND i.periodTo IS NOT NULL " +
           "AND i.periodFrom <= :to AND i.periodTo >= :from " +
           "AND (:excludeId IS NULL OR i.id <> :excludeId) " +
           "ORDER BY i.id ASC")
    List<JobWorkInvoice> findOverlappingByPeriod(
            @Param("siteId") Long siteId,
            @Param("serviceId") Long serviceId,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to,
            @Param("excludeId") Long excludeId);

    boolean existsByVendorId(Long vendorId);
}
