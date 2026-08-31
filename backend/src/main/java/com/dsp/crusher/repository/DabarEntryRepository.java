package com.dsp.crusher.repository;

import com.dsp.crusher.entity.DabarEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;

public interface DabarEntryRepository extends JpaRepository<DabarEntry, Long> {
    List<DabarEntry> findByStatusOrderByEntryDateDescIdDesc(String status);
    List<DabarEntry> findByEntryDateAndStatusOrderByIdAsc(LocalDate date, String status);
    List<DabarEntry> findByEntryDateBetweenAndStatusOrderByEntryDateDescIdDesc(LocalDate from, LocalDate to, String status);
}
