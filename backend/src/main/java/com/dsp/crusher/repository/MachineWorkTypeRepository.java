package com.dsp.crusher.repository;

import com.dsp.crusher.entity.MachineWorkType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MachineWorkTypeRepository extends JpaRepository<MachineWorkType, Long> {
    List<MachineWorkType> findByMachineIdAndStatusOrderByDisplayOrderAsc(Long machineId, String status);
    List<MachineWorkType> findByMachineIdInAndStatus(List<Long> machineIds, String status);
}
