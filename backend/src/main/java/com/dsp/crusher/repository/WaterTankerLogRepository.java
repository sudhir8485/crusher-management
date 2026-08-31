package com.dsp.crusher.repository;

import com.dsp.crusher.entity.WaterTankerLog;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;

public interface WaterTankerLogRepository extends JpaRepository<WaterTankerLog, Long> {
    List<WaterTankerLog> findByStatusOrderByLogDateDescIdDesc(String status);
    List<WaterTankerLog> findByLogDateAndStatusOrderByIdAsc(LocalDate date, String status);
    List<WaterTankerLog> findByLogDateBetweenAndStatusOrderByLogDateDescIdDesc(LocalDate from, LocalDate to, String status);
}
