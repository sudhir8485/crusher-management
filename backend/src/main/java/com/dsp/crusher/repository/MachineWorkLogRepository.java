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

    @Query("SELECT COALESCE(SUM(m.totalHours), 0) FROM MachineWorkLog m WHERE m.logDate BETWEEN :from AND :to AND m.status = 'ACTIVE' AND (:siteId IS NULL OR m.siteId = :siteId)")
    BigDecimal sumHoursByDateRangeAndSite(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);
}
