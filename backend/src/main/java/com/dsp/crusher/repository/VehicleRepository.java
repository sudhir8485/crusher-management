package com.dsp.crusher.repository;

import com.dsp.crusher.entity.Vehicle;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface VehicleRepository extends JpaRepository<Vehicle, Long> {
    // Active-only (default list / pickers)
    List<Vehicle> findByStatusAndIsActiveTrue(String status);
    // All non-deleted including inactive (admin "show inactive" view)
    List<Vehicle> findByStatus(String status);
    List<Vehicle> findByOwnerAndStatus(String owner, String status);
    List<Vehicle> findByVendorIdAndStatus(Long vendorId, String status);
    List<Vehicle> findByLinkedMachineIdAndStatus(Long linkedMachineId, String status);
}
