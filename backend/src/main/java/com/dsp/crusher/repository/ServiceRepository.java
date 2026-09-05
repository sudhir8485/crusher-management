package com.dsp.crusher.repository;

import com.dsp.crusher.entity.ServiceRecord;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ServiceRepository extends JpaRepository<ServiceRecord, Long> {
    List<ServiceRecord> findByStatus(String status);
}
