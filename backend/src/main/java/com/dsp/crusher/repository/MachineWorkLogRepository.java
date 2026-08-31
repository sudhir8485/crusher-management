package com.dsp.crusher.repository;

import com.dsp.crusher.entity.MachineWorkLog;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;

public interface MachineWorkLogRepository extends JpaRepository<MachineWorkLog, Long> {

    List<MachineWorkLog> findByStatusOrderByLogDateDescIdDesc(String status);

    List<MachineWorkLog> findByLogDateAndStatusOrderByIdDesc(LocalDate date, String status);

    List<MachineWorkLog> findByLogDateBetweenAndStatusOrderByLogDateDescIdDesc(
            LocalDate from, LocalDate to, String status);
}
