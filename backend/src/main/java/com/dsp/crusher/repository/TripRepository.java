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
}
