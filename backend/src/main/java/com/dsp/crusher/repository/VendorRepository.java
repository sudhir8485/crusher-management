package com.dsp.crusher.repository;

import com.dsp.crusher.entity.Vendor;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface VendorRepository extends JpaRepository<Vendor, Long> {
    // Active-only (default list / pickers)
    List<Vendor> findByStatusAndIsActiveTrue(String status);
    // All non-deleted including inactive
    List<Vendor> findByStatus(String status);
}
