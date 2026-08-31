package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
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

    public List<TripResponse> listAll() {
        return enrich(tripRepo.findByStatusOrderByTripDateDescIdDesc("ACTIVE"));
    }

    public List<TripResponse> listByDate(LocalDate date) {
        return enrich(tripRepo.findByTripDateAndStatusOrderByIdAsc(date, "ACTIVE"));
    }

    public List<TripResponse> listByDateRange(LocalDate from, LocalDate to) {
        return enrich(tripRepo.findByTripDateBetweenAndStatusOrderByTripDateDescIdDesc(from, to, "ACTIVE"));
    }

    public DailyReportResponse dailyReport(LocalDate date) {
        List<TripResponse> trips = listByDate(date);

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
    public TripResponse create(TripRequest req) {
        Trip t = new Trip();
        t.setTenantId(TenantContext.get());
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
