package com.dsp.crusher.repository;

import com.dsp.crusher.entity.VehicleDailyLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.util.List;

public interface VehicleDailyLogRepository extends JpaRepository<VehicleDailyLog, Long> {

    List<VehicleDailyLog> findByStatusOrderByLogDateDescIdDesc(String status);

    List<VehicleDailyLog> findByLogDateAndStatusOrderByVehicleIdAscIdAsc(LocalDate date, String status);

    List<VehicleDailyLog> findByLogDateBetweenAndStatusOrderByLogDateDescIdDesc(
            LocalDate from, LocalDate to, String status);

    // for reports — ASC order, optional vehicle filter
    List<VehicleDailyLog> findByLogDateBetweenAndStatusOrderByLogDateAscIdAsc(
            LocalDate from, LocalDate to, String status);

    List<VehicleDailyLog> findByVehicleIdAndLogDateBetweenAndStatusOrderByLogDateAscIdAsc(
            Long vehicleId, LocalDate from, LocalDate to, String status);

    @Query("SELECT v FROM VehicleDailyLog v WHERE v.logDate = :date AND v.status = 'ACTIVE' AND (:siteId IS NULL OR v.siteId = :siteId) ORDER BY v.vehicleId ASC, v.id ASC")
    List<VehicleDailyLog> findByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    @Query("SELECT v FROM VehicleDailyLog v WHERE v.logDate BETWEEN :from AND :to AND v.status = 'ACTIVE' AND (:siteId IS NULL OR v.siteId = :siteId) ORDER BY v.logDate DESC, v.id DESC")
    List<VehicleDailyLog> findByDateRangeAndSite(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT v FROM VehicleDailyLog v WHERE v.logDate BETWEEN :from AND :to AND v.status = 'ACTIVE' AND (:siteId IS NULL OR v.siteId = :siteId) ORDER BY v.logDate ASC, v.id ASC")
    List<VehicleDailyLog> findByDateRangeAndSiteAsc(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT v FROM VehicleDailyLog v WHERE v.vehicleId = :vehicleId AND v.logDate BETWEEN :from AND :to AND v.status = 'ACTIVE' AND (:siteId IS NULL OR v.siteId = :siteId) ORDER BY v.logDate ASC, v.id ASC")
    List<VehicleDailyLog> findByVehicleIdAndDateRangeAndSite(@Param("vehicleId") Long vehicleId, @Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);
}
