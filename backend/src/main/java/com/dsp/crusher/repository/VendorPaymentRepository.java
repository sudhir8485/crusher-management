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

    // Today's collections count
    long countByPaymentDateAndStatus(LocalDate date, String status);

    // RECEIVED payments up to a date (opening balance: reduces what party owes DSP)
    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.vendorId = :vendorId AND p.direction = 'RECEIVED' AND p.paymentDate < :before AND p.status = 'ACTIVE'")
    BigDecimal sumAmountByVendorBefore(@Param("vendorId") Long vendorId, @Param("before") LocalDate before);

    // PAID payments up to a date (opening balance: reduces what DSP owes party)
    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.vendorId = :vendorId AND p.direction = 'PAID' AND p.paymentDate < :before AND p.status = 'ACTIVE'")
    BigDecimal sumPaidByVendorBefore(@Param("vendorId") Long vendorId, @Param("before") LocalDate before);

    // All-time RECEIVED payments for a single vendor (for getTripBalance outstanding)
    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.vendorId = :vendorId AND p.direction = 'RECEIVED' AND p.status = 'ACTIVE'")
    BigDecimal sumReceivedByVendorId(@Param("vendorId") Long vendorId);

    // All-time PAID payments for a single vendor (for getTripBalance outstanding)
    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.vendorId = :vendorId AND p.direction = 'PAID' AND p.status = 'ACTIVE'")
    BigDecimal sumPaidByVendorId(@Param("vendorId") Long vendorId);

    // Batch RECEIVED payment sums (accounts list)
    @Query("SELECT p.vendorId, COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.vendorId IN :vendorIds AND p.direction = 'RECEIVED' AND p.status = 'ACTIVE' GROUP BY p.vendorId")
    List<Object[]> sumByVendorIds(@Param("vendorIds") List<Long> vendorIds);

    // Batch PAID payment sums (accounts list)
    @Query("SELECT p.vendorId, COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.vendorId IN :vendorIds AND p.direction = 'PAID' AND p.status = 'ACTIVE' GROUP BY p.vendorId")
    List<Object[]> sumPaidByVendorIds(@Param("vendorIds") List<Long> vendorIds);

    @Query("SELECT p.vendorId, MAX(p.paymentDate) FROM VendorPayment p WHERE p.vendorId IN :vendorIds AND p.status = 'ACTIVE' GROUP BY p.vendorId")
    List<Object[]> lastPaymentDateByVendorIds(@Param("vendorIds") List<Long> vendorIds);

    boolean existsByVendorId(Long vendorId);
}
