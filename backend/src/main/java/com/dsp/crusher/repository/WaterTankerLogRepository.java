package com.dsp.crusher.repository;

import com.dsp.crusher.entity.WaterTankerLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.util.List;

public interface WaterTankerLogRepository extends JpaRepository<WaterTankerLog, Long> {
    List<WaterTankerLog> findByStatusOrderByLogDateDescIdDesc(String status);
    List<WaterTankerLog> findByLogDateAndStatusOrderByIdAsc(LocalDate date, String status);
    List<WaterTankerLog> findByLogDateBetweenAndStatusOrderByLogDateDescIdDesc(LocalDate from, LocalDate to, String status);

    @Query("SELECT w FROM WaterTankerLog w WHERE w.logDate = :date AND w.status = 'ACTIVE' AND (:siteId IS NULL OR w.siteId = :siteId) ORDER BY w.id ASC")
    List<WaterTankerLog> findByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    @Query("SELECT w FROM WaterTankerLog w WHERE w.logDate BETWEEN :from AND :to AND w.status = 'ACTIVE' AND (:siteId IS NULL OR w.siteId = :siteId) ORDER BY w.logDate DESC, w.id DESC")
    List<WaterTankerLog> findByDateRangeAndSite(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);
}
