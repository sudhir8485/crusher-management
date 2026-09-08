package com.dsp.crusher.repository;

import com.dsp.crusher.entity.Machine;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MachineRepository extends JpaRepository<Machine, Long> {
    // Active-only (default list / pickers)
    List<Machine> findByStatusAndIsActiveTrue(String status);
    // All non-deleted including inactive (admin "show inactive" view)
    List<Machine> findByStatus(String status);
    List<Machine> findByVendorIdAndStatus(Long vendorId, String status);
    List<Machine> findByLinkedVehicleIdAndStatus(Long linkedVehicleId, String status);
}
