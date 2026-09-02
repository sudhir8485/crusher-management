package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
import com.dsp.crusher.config.TenantContext;
import org.springframework.security.core.context.SecurityContextHolder;
import com.dsp.crusher.dto.DabarEntryRequest;
import com.dsp.crusher.dto.DabarEntryResponse;
import com.dsp.crusher.entity.DabarEntry;
import com.dsp.crusher.entity.Vehicle;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.DabarEntryRepository;
import com.dsp.crusher.repository.VehicleRepository;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DabarService {

    private final DabarEntryRepository repo;
    private final VehicleRepository vehicleRepo;
    private final VendorRepository vendorRepo;

    public List<DabarEntryResponse> listAll(Long siteId) {
        Long sid = effectiveSiteId(siteId);
        if (sid == null) return enrich(repo.findByStatusOrderByEntryDateDescIdDesc("ACTIVE"));
        return enrich(repo.findByDateRangeAndSite(java.time.LocalDate.of(2000,1,1), java.time.LocalDate.now().plusYears(1), sid));
    }

    public List<DabarEntryResponse> listByDate(LocalDate date, Long siteId) {
        return enrich(repo.findByDateAndSite(date, effectiveSiteId(siteId)));
    }

    public List<DabarEntryResponse> listByDateRange(LocalDate from, LocalDate to, Long siteId) {
        return enrich(repo.findByDateRangeAndSite(from, to, effectiveSiteId(siteId)));
    }

    public DabarEntryResponse getById(Long id) {
        DabarEntry e = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Dabar entry not found: " + id));
        return enrich(List.of(e)).get(0);
    }

    @Transactional
    public DabarEntryResponse create(DabarEntryRequest req, Long targetSiteId) {
        DabarEntry e = new DabarEntry();
        e.setTenantId(TenantContext.get());
        e.setSiteId(resolveCreateSite(targetSiteId));
        apply(e, req);
        return enrich(List.of(repo.save(e))).get(0);
    }

    @Transactional
    public DabarEntryResponse update(Long id, DabarEntryRequest req) {
        DabarEntry e = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Dabar entry not found: " + id));
        apply(e, req);
        return enrich(List.of(repo.save(e))).get(0);
    }

    @Transactional
    public void deactivate(Long id) {
        DabarEntry e = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Dabar entry not found: " + id));
        e.setStatus("INACTIVE");
        repo.save(e);
    }

    private Long effectiveSiteId(Long requested) {
        boolean isSiteStaff = SecurityContextHolder.getContext().getAuthentication()
                .getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_SITE_STAFF"));
        return isSiteStaff ? SiteContext.get() : requested;
    }

    private Long resolveCreateSite(Long targetSiteId) {
        Long sid = effectiveSiteId(targetSiteId);
        if (sid == null) throw new IllegalArgumentException("Select a site before creating entries");
        return sid;
    }

    private void apply(DabarEntry e, DabarEntryRequest req) {
        e.setEntryDate(req.getEntryDate());
        e.setVehicleId(req.getVehicleId());
        e.setVendorId(req.getVendorId());
        e.setTripsCount(req.getTripsCount());
        e.setQuantityBrass(req.getQuantityBrass());
        e.setNotes(req.getNotes());
    }

    private List<DabarEntryResponse> enrich(List<DabarEntry> entries) {
        if (entries.isEmpty()) return List.of();

        Map<Long, Vehicle> vehicles = vehicleRepo.findAll().stream()
                .collect(Collectors.toMap(Vehicle::getId, v -> v));
        Map<Long, Vendor> vendors = vendorRepo.findAll().stream()
                .collect(Collectors.toMap(Vendor::getId, v -> v));

        return entries.stream().map(e -> {
            DabarEntryResponse r = new DabarEntryResponse();
            r.setId(e.getId());
            r.setEntryDate(e.getEntryDate());
            r.setVehicleId(e.getVehicleId());
            r.setVendorId(e.getVendorId());
            r.setTripsCount(e.getTripsCount());
            r.setQuantityBrass(e.getQuantityBrass());
            r.setNotes(e.getNotes());
            r.setCreatedAt(e.getCreatedAt());

            if (e.getVehicleId() != null) {
                Vehicle v = vehicles.get(e.getVehicleId());
                if (v != null) {
                    r.setVehicleDisplayName(v.getDisplayName());
                    r.setVehiclePlateNumber(v.getPlateNumber());
                }
            }
            if (e.getVendorId() != null) {
                Vendor v = vendors.get(e.getVendorId());
                if (v != null) r.setVendorName(v.getName());
            }
            return r;
        }).collect(Collectors.toList());
    }
}
