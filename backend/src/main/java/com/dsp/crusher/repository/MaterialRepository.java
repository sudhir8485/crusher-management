package com.dsp.crusher.repository;

import com.dsp.crusher.entity.Material;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MaterialRepository extends JpaRepository<Material, Long> {
    List<Material> findByStatus(String status);
}
