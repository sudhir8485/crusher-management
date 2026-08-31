package com.dsp.crusher.repository;

import com.dsp.crusher.entity.Trip;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;

public interface TripRepository extends JpaRepository<Trip, Long> {
    List<Trip> findByStatusOrderByTripDateDescIdDesc(String status);
    List<Trip> findByTripDateAndStatusOrderByIdAsc(LocalDate date, String status);
    List<Trip> findByTripDateBetweenAndStatusOrderByTripDateDescIdDesc(LocalDate from, LocalDate to, String status);
}
