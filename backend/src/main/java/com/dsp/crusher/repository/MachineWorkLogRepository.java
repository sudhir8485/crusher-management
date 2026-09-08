package com.dsp.crusher.repository;

import com.dsp.crusher.entity.MachineWorkLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface MachineWorkLogRepository extends JpaRepository<MachineWorkLog, Long> {

    List<MachineWorkLog> findByStatusOrderByLogDateDescIdDesc(String status);

    List<MachineWorkLog> findByLogDateAndStatusOrderByIdDesc(LocalDate date, String status);

    List<MachineWorkLog> findByLogDateBetweenAndStatusOrderByLogDateDescIdDesc(
            LocalDate from, LocalDate to, String status);

    @Query("SELECT COALESCE(SUM(m.totalHours), 0) FROM MachineWorkLog m WHERE m.logDate BETWEEN :from AND :to AND m.status = 'ACTIVE'")
    BigDecimal sumHoursByDateRange(@Param("from") LocalDate from, @Param("to") LocalDate to);

    // for reports — ASC order, optional machine filter
    List<MachineWorkLog> findByLogDateBetweenAndStatusOrderByLogDateAscIdAsc(
            LocalDate from, LocalDate to, String status);

    List<MachineWorkLog> findByMachineIdAndLogDateBetweenAndStatusOrderByLogDateAscIdAsc(
            Long machineId, LocalDate from, LocalDate to, String status);

    @Query("SELECT m FROM MachineWorkLog m WHERE m.logDate = :date AND m.status = 'ACTIVE' AND (:siteId IS NULL OR m.siteId = :siteId) ORDER BY m.id DESC")
    List<MachineWorkLog> findByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    @Query("SELECT m FROM MachineWorkLog m WHERE m.logDate BETWEEN :from AND :to AND m.status = 'ACTIVE' AND (:siteId IS NULL OR m.siteId = :siteId) ORDER BY m.logDate DESC, m.id DESC")
    List<MachineWorkLog> findByDateRangeAndSite(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT m FROM MachineWorkLog m WHERE m.logDate BETWEEN :from AND :to AND m.status = 'ACTIVE' AND (:siteId IS NULL OR m.siteId = :siteId) ORDER BY m.logDate ASC, m.id ASC")
    List<MachineWorkLog> findByDateRangeAndSiteAsc(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT m FROM MachineWorkLog m WHERE m.machineId = :machineId AND m.logDate BETWEEN :from AND :to AND m.status = 'ACTIVE' AND (:siteId IS NULL OR m.siteId = :siteId) ORDER BY m.logDate ASC, m.id ASC")
    List<MachineWorkLog> findByMachineIdAndDateRangeAndSite(@Param("machineId") Long machineId, @Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT COALESCE(SUM(m.totalHours), 0) FROM MachineWorkLog m WHERE m.logDate BETWEEN :from AND :to AND m.status = 'ACTIVE' AND (:siteId IS NULL OR m.siteId = :siteId)")
    BigDecimal sumHoursByDateRangeAndSite(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    // ── Customer Billable — used by LedgerService ────────────────────────────

    // Only returns entries without a linked GST invoice — those with gstInvoiceId appear
    // in the ledger via the GstInvoice directly and must not be double-counted.
    @Query("SELECT m FROM MachineWorkLog m WHERE m.customerId = :customerId AND m.workPurpose = 'CUSTOMER_BILLABLE' AND m.gstInvoiceId IS NULL AND m.logDate BETWEEN :from AND :to AND m.status = 'ACTIVE' ORDER BY m.logDate ASC, m.id ASC")
    List<MachineWorkLog> findBillableByCustomerAndDateRange(@Param("customerId") Long customerId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    @Query("SELECT COALESCE(SUM(m.totalAmount), 0) FROM MachineWorkLog m WHERE m.customerId = :customerId AND m.workPurpose = 'CUSTOMER_BILLABLE' AND m.rateStatus = 'SET' AND m.gstInvoiceId IS NULL AND m.logDate < :before AND m.status = 'ACTIVE'")
    java.math.BigDecimal sumTotalAmountByCustomerBefore(@Param("customerId") Long customerId, @Param("before") LocalDate before);

    boolean existsByMachineId(Long machineId);
    boolean existsByCustomerId(Long customerId);
}
