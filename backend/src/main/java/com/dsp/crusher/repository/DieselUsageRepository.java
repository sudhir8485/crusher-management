package com.dsp.crusher.repository;

import com.dsp.crusher.entity.DieselUsage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface DieselUsageRepository extends JpaRepository<DieselUsage, Long> {
    List<DieselUsage> findByStatusOrderByUsageDateDescIdDesc(String status);
    List<DieselUsage> findByUsageDateAndStatusOrderByIdAsc(LocalDate date, String status);
    List<DieselUsage> findByUsageDateBetweenAndStatusOrderByUsageDateDescIdDesc(LocalDate from, LocalDate to, String status);

    @Query("SELECT COALESCE(SUM(u.quantityLiters), 0) FROM DieselUsage u WHERE u.status = 'ACTIVE'")
    BigDecimal sumTotalUsed();

    List<DieselUsage> findByUsageDateBetweenAndStatusOrderByUsageDateAscIdAsc(LocalDate from, LocalDate to, String status);

    @Query("SELECT COALESCE(SUM(u.quantityLiters), 0) FROM DieselUsage u WHERE u.usageDate < :before AND u.status = 'ACTIVE'")
    BigDecimal sumUsedBefore(@org.springframework.data.repository.query.Param("before") LocalDate before);

    @Query("SELECT COALESCE(SUM(u.quantityLiters), 0) FROM DieselUsage u WHERE u.usageDate < :before AND u.status = 'ACTIVE' AND (:siteId IS NULL OR u.siteId = :siteId)")
    BigDecimal sumUsedBeforeAndSite(@Param("before") LocalDate before, @Param("siteId") Long siteId);

    @Query("SELECT u FROM DieselUsage u WHERE u.usageDate = :date AND u.status = 'ACTIVE' AND (:siteId IS NULL OR u.siteId = :siteId) ORDER BY u.id ASC")
    List<DieselUsage> findByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    @Query("SELECT u FROM DieselUsage u WHERE u.usageDate BETWEEN :from AND :to AND u.status = 'ACTIVE' AND (:siteId IS NULL OR u.siteId = :siteId) ORDER BY u.usageDate ASC, u.id ASC")
    List<DieselUsage> findByDateRangeAndSite(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT COALESCE(SUM(u.quantityLiters), 0) FROM DieselUsage u WHERE u.status = 'ACTIVE' AND (:siteId IS NULL OR u.siteId = :siteId)")
    BigDecimal sumTotalUsedBySite(@Param("siteId") Long siteId);
}
