package com.dsp.crusher.repository;

import com.dsp.crusher.entity.VehicleDailyLog;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;

public interface VehicleDailyLogRepository extends JpaRepository<VehicleDailyLog, Long> {

    List<VehicleDailyLog> findByStatusOrderByLogDateDescIdDesc(String status);

    List<VehicleDailyLog> findByLogDateAndStatusOrderByVehicleIdAscIdAsc(LocalDate date, String status);

    List<VehicleDailyLog> findByLogDateBetweenAndStatusOrderByLogDateDescIdDesc(
            LocalDate from, LocalDate to, String status);
}
