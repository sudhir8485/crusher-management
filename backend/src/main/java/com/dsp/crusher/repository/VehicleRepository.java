package com.dsp.crusher.repository;

import com.dsp.crusher.entity.Vehicle;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface VehicleRepository extends JpaRepository<Vehicle, Long> {
    List<Vehicle> findByStatus(String status);
    List<Vehicle> findByOwnerAndStatus(String owner, String status);
    List<Vehicle> findByVendorIdAndStatus(Long vendorId, String status);
}
