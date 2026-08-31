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
}
