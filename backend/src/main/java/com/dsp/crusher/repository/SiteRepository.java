package com.dsp.crusher.repository;

import com.dsp.crusher.entity.Site;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SiteRepository extends JpaRepository<Site, Long> {
    List<Site> findByStatus(String status);
}
