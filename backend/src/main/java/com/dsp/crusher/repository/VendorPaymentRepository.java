package com.dsp.crusher.repository;

import com.dsp.crusher.entity.VendorPayment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface VendorPaymentRepository extends JpaRepository<VendorPayment, Long> {

    List<VendorPayment> findByStatusOrderByPaymentDateDescIdDesc(String status);
    Page<VendorPayment> findByStatusOrderByPaymentDateDescIdDesc(String status, Pageable pageable);

    List<VendorPayment> findByVendorIdAndStatusOrderByPaymentDateDescIdDesc(Long vendorId, String status);
    Page<VendorPayment> findByVendorIdAndStatusOrderByPaymentDateDescIdDesc(Long vendorId, String status, Pageable pageable);

    List<VendorPayment> findByPaymentDateBetweenAndStatusOrderByPaymentDateDescIdDesc(
            LocalDate from, LocalDate to, String status);
    Page<VendorPayment> findByPaymentDateBetweenAndStatusOrderByPaymentDateDescIdDesc(
            LocalDate from, LocalDate to, String status, Pageable pageable);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.vendorId = :vendorId AND p.status = 'ACTIVE'")
    BigDecimal sumByVendorId(@Param("vendorId") Long vendorId);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.paymentDate BETWEEN :from AND :to AND p.status = 'ACTIVE'")
    BigDecimal sumByDateRange(@Param("from") LocalDate from, @Param("to") LocalDate to);

    // Sum of all payments linked to invoices (for outstanding calculation)
    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.invoiceId IS NOT NULL AND p.status = 'ACTIVE'")
    BigDecimal sumAllLinkedPayments();

    List<VendorPayment> findByVendorIdAndPaymentDateBetweenAndStatusOrderByPaymentDateAscIdAsc(
            Long vendorId, LocalDate from, LocalDate to, String status);

    List<VendorPayment> findByInvoiceIdAndStatusOrderByPaymentDateAscIdAsc(Long invoiceId, String status);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.invoiceId = :invoiceId AND p.status = 'ACTIVE'")
    BigDecimal sumByInvoiceId(@Param("invoiceId") Long invoiceId);

    // All payments for a vendor up to a date (for opening balance calculation)
    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.vendorId = :vendorId AND p.paymentDate < :before AND p.status = 'ACTIVE'")
    BigDecimal sumAmountByVendorBefore(@Param("vendorId") Long vendorId, @Param("before") LocalDate before);
}
