package com.dsp.crusher.repository;

import com.dsp.crusher.entity.DabarEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.util.List;

public interface DabarEntryRepository extends JpaRepository<DabarEntry, Long> {
    List<DabarEntry> findByStatusOrderByEntryDateDescIdDesc(String status);
    List<DabarEntry> findByEntryDateAndStatusOrderByIdAsc(LocalDate date, String status);
    List<DabarEntry> findByEntryDateBetweenAndStatusOrderByEntryDateDescIdDesc(LocalDate from, LocalDate to, String status);

    @Query("SELECT d FROM DabarEntry d WHERE d.entryDate = :date AND d.status = 'ACTIVE' AND (:siteId IS NULL OR d.siteId = :siteId) ORDER BY d.id ASC")
    List<DabarEntry> findByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    @Query("SELECT d FROM DabarEntry d WHERE d.entryDate BETWEEN :from AND :to AND d.status = 'ACTIVE' AND (:siteId IS NULL OR d.siteId = :siteId) ORDER BY d.entryDate DESC, d.id DESC")
    List<DabarEntry> findByDateRangeAndSite(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);
}
