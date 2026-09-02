package com.dsp.crusher.repository;

import com.dsp.crusher.entity.Trip;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface TripRepository extends JpaRepository<Trip, Long> {
    List<Trip> findByStatusOrderByTripDateDescIdDesc(String status);
    List<Trip> findByTripDateAndStatusOrderByIdAsc(LocalDate date, String status);
    List<Trip> findByTripDateBetweenAndStatusOrderByTripDateDescIdDesc(LocalDate from, LocalDate to, String status);

    long countByTripDateAndStatus(LocalDate date, String status);

    @Query("SELECT COALESCE(SUM(t.quantityBrass), 0) FROM Trip t WHERE t.tripDate = :date AND t.status = 'ACTIVE'")
    BigDecimal sumBrassByDate(@Param("date") LocalDate date);

    @Query("SELECT COALESCE(SUM(t.quantityBrass), 0) FROM Trip t WHERE t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE'")
    BigDecimal sumBrassByDateRange(@Param("from") LocalDate from, @Param("to") LocalDate to);

    @Query("SELECT t.materialId, COUNT(t), COALESCE(SUM(t.quantityBrass), 0) FROM Trip t WHERE t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' GROUP BY t.materialId")
    List<Object[]> summarizeByMaterial(@Param("from") LocalDate from, @Param("to") LocalDate to);

    // for reports — ASC order, with optional filters
    List<Trip> findByTripDateBetweenAndStatusOrderByTripDateAscIdAsc(LocalDate from, LocalDate to, String status);

    List<Trip> findByVehicleIdAndTripDateBetweenAndStatusOrderByTripDateAscIdAsc(Long vehicleId, LocalDate from, LocalDate to, String status);

    List<Trip> findByMaterialIdAndTripDateBetweenAndStatusOrderByTripDateAscIdAsc(Long materialId, LocalDate from, LocalDate to, String status);

    List<Trip> findByVendorIdAndTripDateBetweenAndStatusOrderByTripDateAscIdAsc(Long vendorId, LocalDate from, LocalDate to, String status);

    // Site-aware queries (siteId IS NULL → all sites for admin)
    @Query("SELECT t FROM Trip t WHERE t.tripDate = :date AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId) ORDER BY t.id ASC")
    List<Trip> findByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    @Query("SELECT t FROM Trip t WHERE t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId) ORDER BY t.tripDate DESC, t.id DESC")
    List<Trip> findByDateRangeAndSite(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT COUNT(t) FROM Trip t WHERE t.tripDate = :date AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId)")
    long countByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    @Query("SELECT COALESCE(SUM(t.quantityBrass), 0) FROM Trip t WHERE t.tripDate = :date AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId)")
    BigDecimal sumBrassByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    @Query("SELECT t.materialId, COUNT(t), COALESCE(SUM(t.quantityBrass), 0) FROM Trip t WHERE t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId) GROUP BY t.materialId")
    List<Object[]> summarizeByMaterialAndSite(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);
}
