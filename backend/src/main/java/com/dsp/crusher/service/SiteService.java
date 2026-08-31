package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.SiteRequest;
import com.dsp.crusher.entity.Site;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.SiteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class SiteService {

    private final SiteRepository repo;

    public List<Site> listActive() {
        return repo.findByStatus("ACTIVE");
    }

    public Site getById(Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Site not found: " + id));
    }

    @Transactional
    public Site create(SiteRequest req) {
        Site s = new Site();
        s.setTenantId(TenantContext.get());
        s.setName(req.getName());
        s.setLocation(req.getLocation());
        return repo.save(s);
    }

    @Transactional
    public Site update(Long id, SiteRequest req) {
        Site s = getById(id);
        s.setName(req.getName());
        s.setLocation(req.getLocation());
        return repo.save(s);
    }

    @Transactional
    public void deactivate(Long id) {
        Site s = getById(id);
        s.setStatus("INACTIVE");
        repo.save(s);
    }
}
