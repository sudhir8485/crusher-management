package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.SiteRequest;
import com.dsp.crusher.dto.SiteResponse;
import com.dsp.crusher.entity.Site;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.SiteRepository;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class SiteService {

    private final SiteRepository repo;
    private final VendorRepository vendorRepo;

    public List<SiteResponse> listActive() {
        return repo.findByStatus("ACTIVE").stream().map(this::toResponse).toList();
    }

    public SiteResponse getById(Long id) {
        return toResponse(repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Site not found: " + id)));
    }

    /** Internal — returns entity for services that need the raw Site (e.g. TripService). */
    public Site getEntityById(Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Site not found: " + id));
    }

    @Transactional
    public SiteResponse create(SiteRequest req) {
        Site s = new Site();
        s.setTenantId(TenantContext.get());
        apply(s, req);
        return toResponse(repo.save(s));
    }

    @Transactional
    public SiteResponse update(Long id, SiteRequest req) {
        Site s = getEntityById(id);
        apply(s, req);
        return toResponse(repo.save(s));
    }

    private void apply(Site s, SiteRequest req) {
        s.setName(req.getName());
        s.setLocation(req.getLocation());
        if (req.getSiteType() != null) s.setSiteType(req.getSiteType());
        if ("CLIENT_SITE".equals(s.getSiteType())) {
            s.setLinkedPartyId(req.getLinkedPartyId());
        } else {
            s.setLinkedPartyId(null);
        }
    }

    @Transactional
    public void deactivate(Long id) {
        Site s = getEntityById(id);
        s.setStatus("INACTIVE");
        repo.save(s);
    }

    private SiteResponse toResponse(Site s) {
        SiteResponse r = new SiteResponse();
        r.setId(s.getId());
        r.setTenantId(s.getTenantId());
        r.setName(s.getName());
        r.setLocation(s.getLocation());
        r.setSiteType(s.getSiteType());
        r.setLinkedPartyId(s.getLinkedPartyId());
        r.setStatus(s.getStatus());
        r.setCreatedAt(s.getCreatedAt());
        if (s.getLinkedPartyId() != null) {
            vendorRepo.findById(s.getLinkedPartyId())
                    .ifPresent(v -> r.setLinkedPartyName(v.getName()));
        }
        return r;
    }
}
