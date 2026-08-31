package com.dsp.crusher.repository;

import com.dsp.crusher.entity.Machine;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MachineRepository extends JpaRepository<Machine, Long> {
    List<Machine> findByStatus(String status);
    List<Machine> findByVendorIdAndStatus(Long vendorId, String status);
}
