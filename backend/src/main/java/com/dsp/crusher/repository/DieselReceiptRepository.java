package com.dsp.crusher.repository;

import com.dsp.crusher.entity.DieselReceipt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface DieselReceiptRepository extends JpaRepository<DieselReceipt, Long> {
    List<DieselReceipt> findByStatusOrderByReceiptDateDescIdDesc(String status);
    List<DieselReceipt> findByReceiptDateAndStatusOrderByIdAsc(LocalDate date, String status);
    List<DieselReceipt> findByReceiptDateBetweenAndStatusOrderByReceiptDateDescIdDesc(LocalDate from, LocalDate to, String status);

    @Query("SELECT COALESCE(SUM(r.quantityLiters), 0) FROM DieselReceipt r WHERE r.status = 'ACTIVE'")
    BigDecimal sumTotalReceived();

    List<DieselReceipt> findByReceiptDateBetweenAndStatusOrderByReceiptDateAscIdAsc(LocalDate from, LocalDate to, String status);

    @Query("SELECT COALESCE(SUM(r.quantityLiters), 0) FROM DieselReceipt r WHERE r.receiptDate < :before AND r.status = 'ACTIVE'")
    BigDecimal sumReceivedBefore(@Param("before") LocalDate before);

    @Query("SELECT r FROM DieselReceipt r WHERE r.receiptDate = :date AND r.status = 'ACTIVE' AND (:siteId IS NULL OR r.siteId = :siteId) ORDER BY r.id ASC")
    List<DieselReceipt> findByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    @Query("SELECT r FROM DieselReceipt r WHERE r.receiptDate BETWEEN :from AND :to AND r.status = 'ACTIVE' AND (:siteId IS NULL OR r.siteId = :siteId) ORDER BY r.receiptDate ASC, r.id ASC")
    List<DieselReceipt> findByDateRangeAndSite(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT COALESCE(SUM(r.quantityLiters), 0) FROM DieselReceipt r WHERE r.status = 'ACTIVE' AND (:siteId IS NULL OR r.siteId = :siteId)")
    BigDecimal sumTotalReceivedBySite(@Param("siteId") Long siteId);
}
