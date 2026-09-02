package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
import com.dsp.crusher.config.TenantContext;
import org.springframework.security.core.context.SecurityContextHolder;
import com.dsp.crusher.dto.DailyReportResponse;
import com.dsp.crusher.dto.TripRequest;
import com.dsp.crusher.dto.TripResponse;
import com.dsp.crusher.entity.Material;
import com.dsp.crusher.entity.Trip;
import com.dsp.crusher.entity.Vehicle;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.MaterialRepository;
import com.dsp.crusher.repository.TripRepository;
import com.dsp.crusher.repository.VehicleRepository;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TripService {

    private final TripRepository tripRepo;
    private final VehicleRepository vehicleRepo;
    private final MaterialRepository materialRepo;
    private final VendorRepository vendorRepo;

    public List<TripResponse> listAll(Long siteId) {
        Long sid = effectiveSiteId(siteId);
        if (sid == null) return enrich(tripRepo.findByStatusOrderByTripDateDescIdDesc("ACTIVE"));
        return enrich(tripRepo.findByDateRangeAndSite(LocalDate.of(2000,1,1), LocalDate.now().plusYears(1), sid));
    }

    public List<TripResponse> listByDate(LocalDate date, Long siteId) {
        return enrich(tripRepo.findByDateAndSite(date, effectiveSiteId(siteId)));
    }

    public List<TripResponse> listByDateRange(LocalDate from, LocalDate to, Long siteId) {
        return enrich(tripRepo.findByDateRangeAndSite(from, to, effectiveSiteId(siteId)));
    }

    public DailyReportResponse dailyReport(LocalDate date, Long siteId) {
        List<TripResponse> trips = listByDate(date, siteId);

        Map<String, BigDecimal> byMaterial = new LinkedHashMap<>();
        for (TripResponse t : trips) {
            String key = t.getMaterialName() != null ? t.getMaterialName() : "Unknown";
            BigDecimal qty = t.getQuantityBrass() != null ? t.getQuantityBrass() : BigDecimal.ZERO;
            byMaterial.merge(key, qty, BigDecimal::add);
        }

        List<DailyReportResponse.MaterialSummary> summaries = byMaterial.entrySet().stream()
                .map(e -> {
                    DailyReportResponse.MaterialSummary s = new DailyReportResponse.MaterialSummary();
                    s.setMaterialName(e.getKey());
                    s.setTotalBrass(e.getValue());
                    return s;
                })
                .collect(Collectors.toList());

        BigDecimal grandTotal = summaries.stream()
                .map(DailyReportResponse.MaterialSummary::getTotalBrass)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        DailyReportResponse report = new DailyReportResponse();
        report.setDate(date);
        report.setTrips(trips);
        report.setMaterialSummaries(summaries);
        report.setGrandTotalBrass(grandTotal);
        return report;
    }

    public TripResponse getById(Long id) {
        Trip t = tripRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Trip not found: " + id));
        return enrich(List.of(t)).get(0);
    }

    @Transactional
    public TripResponse create(TripRequest req, Long targetSiteId) {
        Trip t = new Trip();
        t.setTenantId(TenantContext.get());
        t.setSiteId(resolveCreateSite(targetSiteId));
        applyRequest(t, req);
        return enrich(List.of(tripRepo.save(t))).get(0);
    }

    @Transactional
    public TripResponse update(Long id, TripRequest req) {
        Trip t = tripRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Trip not found: " + id));
        applyRequest(t, req);
        return enrich(List.of(tripRepo.save(t))).get(0);
    }

    @Transactional
    public void deactivate(Long id) {
        Trip t = tripRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Trip not found: " + id));
        t.setStatus("INACTIVE");
        tripRepo.save(t);
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private Long effectiveSiteId(Long requested) {
        boolean isSiteStaff = SecurityContextHolder.getContext().getAuthentication()
                .getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_SITE_STAFF"));
        return isSiteStaff ? SiteContext.get() : requested;
    }

    private Long resolveCreateSite(Long targetSiteId) {
        Long sid = effectiveSiteId(targetSiteId);
        if (sid == null) throw new IllegalArgumentException("Select a site before creating entries");
        return sid;
    }

    private void applyRequest(Trip t, TripRequest req) {
        t.setTripDate(req.getTripDate());
        t.setLoadingLocation(req.getLoadingLocation());
        t.setUnloadingLocation(req.getUnloadingLocation());
        t.setChannelNo(req.getChannelNo());
        t.setMaterialId(req.getMaterialId());
        t.setQuantityBrass(req.getQuantityBrass());
        t.setLoadedWeightTon(req.getLoadedWeightTon());
        t.setEmptyWeightTon(req.getEmptyWeightTon());
        t.setVehicleId(req.getVehicleId());
        t.setVendorId(req.getVendorId());
        t.setDspChallanNo(req.getDspChallanNo());
        t.setVendorChallanNo(req.getVendorChallanNo());
    }

    private List<TripResponse> enrich(List<Trip> trips) {
        if (trips.isEmpty()) return List.of();

        Map<Long, Vehicle> vehicles = vehicleRepo.findAll().stream()
                .collect(Collectors.toMap(Vehicle::getId, v -> v));
        Map<Long, Material> materials = materialRepo.findAll().stream()
                .collect(Collectors.toMap(Material::getId, m -> m));
        Map<Long, Vendor> vendors = vendorRepo.findAll().stream()
                .collect(Collectors.toMap(Vendor::getId, v -> v));

        return trips.stream().map(t -> {
            TripResponse r = new TripResponse();
            r.setId(t.getId());
            r.setTripDate(t.getTripDate());
            r.setLoadingLocation(t.getLoadingLocation());
            r.setUnloadingLocation(t.getUnloadingLocation());
            r.setChannelNo(t.getChannelNo());
            r.setMaterialId(t.getMaterialId());
            r.setQuantityBrass(t.getQuantityBrass());
            r.setLoadedWeightTon(t.getLoadedWeightTon());
            r.setEmptyWeightTon(t.getEmptyWeightTon());
            r.setVehicleId(t.getVehicleId());
            r.setVendorId(t.getVendorId());
            r.setDspChallanNo(t.getDspChallanNo());
            r.setVendorChallanNo(t.getVendorChallanNo());
            r.setCreatedAt(t.getCreatedAt());

            if (t.getMaterialId() != null) {
                Material m = materials.get(t.getMaterialId());
                if (m != null) r.setMaterialName(m.getName());
            }
            if (t.getVehicleId() != null) {
                Vehicle v = vehicles.get(t.getVehicleId());
                if (v != null) {
                    r.setVehicleDisplayName(v.getDisplayName());
                    r.setVehiclePlateNumber(v.getPlateNumber());
                }
            }
            if (t.getVendorId() != null) {
                Vendor v = vendors.get(t.getVendorId());
                if (v != null) r.setVendorName(v.getName());
            }
            return r;
        }).collect(Collectors.toList());
    }
}
