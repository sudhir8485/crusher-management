package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
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
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
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

    // ── List queries ──────────────────────────────────────────────────────────

    public List<TripResponse> listAll(Long siteId) {
        Long sid = effectiveSiteId(siteId);
        if (sid == null) return enrich(tripRepo.findByStatusOrderByTripDateDescIdDesc("ACTIVE"));
        return enrich(tripRepo.findByDateRangeAndSite(
                LocalDate.of(2000, 1, 1), LocalDate.now().plusYears(1), sid));
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

    // ── Mutations ─────────────────────────────────────────────────────────────

    @Transactional
    public TripResponse create(TripRequest req, Long targetSiteId) {
        validate(req);
        Trip t = new Trip();
        t.setTenantId(TenantContext.get());
        t.setSiteId(resolveCreateSite(targetSiteId));
        applyRequest(t, req);
        return enrich(List.of(tripRepo.save(t))).get(0);
    }

    @Transactional
    public TripResponse update(Long id, TripRequest req) {
        validate(req);
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

    // ── Validation ────────────────────────────────────────────────────────────

    private void validate(TripRequest req) {
        String pType = req.getPartyType() != null ? req.getPartyType() : "REGULAR";
        if ("REGULAR".equals(pType)) {
            if (req.getVendorId() == null)
                throw new IllegalArgumentException("Party is required for regular customer");
        } else if ("ONE_TIME".equals(pType)) {
            if (req.getOneTimeCustomerName() == null || req.getOneTimeCustomerName().isBlank())
                throw new IllegalArgumentException("Customer name is required for one-time customer");
        } else {
            throw new IllegalArgumentException("Invalid party type: " + pType);
        }

        String vMode = req.getVehicleMode() != null ? req.getVehicleMode() : "COMPANY";
        if ("COMPANY".equals(vMode) && req.getVehicleId() == null)
            throw new IllegalArgumentException("Vehicle is required for company vehicle mode");

        if (req.getLoadedWeightKg() != null) {
            if (req.getLoadedWeightKg().compareTo(BigDecimal.ZERO) < 0)
                throw new IllegalArgumentException("Loaded weight cannot be negative");
        }
        if (req.getEmptyWeightKg() != null) {
            if (req.getEmptyWeightKg().compareTo(BigDecimal.ZERO) < 0)
                throw new IllegalArgumentException("Empty weight cannot be negative");
        }
        if (req.getLoadedWeightKg() != null && req.getEmptyWeightKg() != null) {
            if (req.getEmptyWeightKg().compareTo(req.getLoadedWeightKg()) > 0)
                throw new IllegalArgumentException("Empty weight cannot exceed loaded weight");
        }
        if (req.getSaleRate() != null && req.getSaleRate().compareTo(BigDecimal.ZERO) < 0)
            throw new IllegalArgumentException("Sale rate cannot be negative");
        if (req.getDistanceKm() != null && req.getDistanceKm().compareTo(BigDecimal.ZERO) < 0)
            throw new IllegalArgumentException("Distance cannot be negative");
        if (req.getTransportRatePerKm() != null && req.getTransportRatePerKm().compareTo(BigDecimal.ZERO) < 0)
            throw new IllegalArgumentException("Transport rate cannot be negative");
    }

    // ── Apply + Calculate ─────────────────────────────────────────────────────

    private void applyRequest(Trip t, TripRequest req) {
        t.setTripDate(req.getTripDate());

        // Party
        String pType = req.getPartyType() != null ? req.getPartyType() : "REGULAR";
        t.setPartyType(pType);
        if ("REGULAR".equals(pType)) {
            t.setVendorId(req.getVendorId());
            t.setOneTimeCustomerName(null);
            t.setOneTimeCustomerPhone(null);
            t.setOneTimeCustomerAddr(null);
        } else {
            t.setVendorId(null);
            t.setOneTimeCustomerName(req.getOneTimeCustomerName());
            t.setOneTimeCustomerPhone(req.getOneTimeCustomerPhone());
            t.setOneTimeCustomerAddr(req.getOneTimeCustomerAddr());
        }

        // Material
        t.setMaterialId(req.getMaterialId());
        t.setQuantityUnit(req.getQuantityUnit() != null ? req.getQuantityUnit() : "BRASS");

        // Weights
        t.setLoadedWeightKg(req.getLoadedWeightKg());
        t.setEmptyWeightKg(req.getEmptyWeightKg());

        // Manual quantity (used when weights absent or BRASS without conversion)
        if (req.getBillableQuantity() != null) t.setBillableQuantity(req.getBillableQuantity());

        t.setSaleRate(req.getSaleRate());

        // Vehicle & transport
        String vMode = req.getVehicleMode() != null ? req.getVehicleMode() : "COMPANY";
        t.setVehicleMode(vMode);
        if ("OWN_VEHICLE".equals(vMode)) {
            t.setVehicleId(null);
            t.setTransportMode("CALCULATE");
            t.setDistanceKm(null);
            t.setTransportRatePerKm(null);
            t.setTransportationCharge(BigDecimal.ZERO);
        } else {
            t.setVehicleId(req.getVehicleId());
            String tMode = req.getTransportMode() != null ? req.getTransportMode() : "CALCULATE";
            t.setTransportMode(tMode);
            if ("DIRECT".equals(tMode)) {
                t.setDistanceKm(null);
                t.setTransportRatePerKm(null);
                BigDecimal direct = req.getTransportationChargeDirect();
                t.setTransportationCharge(direct != null ? direct.setScale(2, RoundingMode.HALF_UP) : BigDecimal.ZERO);
            } else {
                t.setDistanceKm(req.getDistanceKm());
                t.setTransportRatePerKm(req.getTransportRatePerKm());
            }
        }

        // Documents & additional
        t.setDspChallanNo(req.getDspChallanNo());
        t.setVendorChallanNo(req.getVendorChallanNo());
        t.setChannelNo(req.getChannelNo());
        t.setLoadingLocation(req.getLoadingLocation());
        t.setUnloadingLocation(req.getUnloadingLocation());
        t.setNotes(req.getNotes());

        // Legacy fields backward compat
        if (req.getLoadedWeightTon() != null) t.setLoadedWeightTon(req.getLoadedWeightTon());
        if (req.getEmptyWeightTon() != null)  t.setEmptyWeightTon(req.getEmptyWeightTon());

        // Recalculate billing (backend is authoritative)
        Material material = req.getMaterialId() != null
                ? materialRepo.findById(req.getMaterialId()).orElse(null)
                : null;
        computeBilling(t, material);
    }

    private void computeBilling(Trip t, Material material) {
        // 1. Net weight
        if (t.getLoadedWeightKg() != null && t.getEmptyWeightKg() != null) {
            BigDecimal net = t.getLoadedWeightKg().subtract(t.getEmptyWeightKg());
            t.setNetWeightKg(net.max(BigDecimal.ZERO));

            // 2. Quantity from weights (overrides manually-sent billableQuantity)
            if ("TON".equals(t.getQuantityUnit())) {
                t.setBillableQuantity(net.max(BigDecimal.ZERO)
                        .divide(BigDecimal.valueOf(1000), 3, RoundingMode.HALF_UP));
            } else { // BRASS
                if (material != null && material.getKgPerBrass() != null
                        && material.getKgPerBrass().compareTo(BigDecimal.ZERO) > 0) {
                    t.setBillableQuantity(net.max(BigDecimal.ZERO)
                            .divide(material.getKgPerBrass(), 3, RoundingMode.HALF_UP));
                }
                // else keep manually-set billableQuantity from request
            }
        }

        // 3. Material amount
        BigDecimal qty  = t.getBillableQuantity();
        BigDecimal rate = t.getSaleRate();
        t.setMaterialAmount((qty != null && rate != null)
                ? qty.multiply(rate).setScale(2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO);

        // 4. Transportation charge
        if ("OWN_VEHICLE".equals(t.getVehicleMode())) {
            t.setTransportationCharge(BigDecimal.ZERO);
        } else if ("DIRECT".equals(t.getTransportMode())) {
            // already set from request in applyRequest; ensure non-null
            if (t.getTransportationCharge() == null) t.setTransportationCharge(BigDecimal.ZERO);
        } else { // CALCULATE — qty × km × rate
            BigDecimal tQty = t.getBillableQuantity();
            if (t.getDistanceKm() != null && t.getTransportRatePerKm() != null
                    && tQty != null && tQty.compareTo(BigDecimal.ZERO) > 0) {
                t.setTransportationCharge(
                        t.getDistanceKm()
                                .multiply(tQty)
                                .multiply(t.getTransportRatePerKm())
                                .setScale(2, RoundingMode.HALF_UP));
            } else {
                t.setTransportationCharge(BigDecimal.ZERO);
            }
        }

        // 5. Total bill
        BigDecimal matAmt   = t.getMaterialAmount()     != null ? t.getMaterialAmount()     : BigDecimal.ZERO;
        BigDecimal transAmt = t.getTransportationCharge() != null ? t.getTransportationCharge() : BigDecimal.ZERO;
        t.setTotalBill(matAmt.add(transAmt));

        // 6. Keep legacy quantityBrass in sync for old reports
        if ("BRASS".equals(t.getQuantityUnit()) && t.getBillableQuantity() != null) {
            t.setQuantityBrass(t.getBillableQuantity());
        } else if (t.getQuantityBrass() == null && t.getBillableQuantity() != null) {
            t.setQuantityBrass(t.getBillableQuantity());
        }
    }

    // ── Enrich ────────────────────────────────────────────────────────────────

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

            // Party
            r.setPartyType(t.getPartyType());
            r.setVendorId(t.getVendorId());
            r.setOneTimeCustomerName(t.getOneTimeCustomerName());
            r.setOneTimeCustomerPhone(t.getOneTimeCustomerPhone());
            r.setOneTimeCustomerAddr(t.getOneTimeCustomerAddr());
            if ("REGULAR".equals(t.getPartyType()) && t.getVendorId() != null) {
                Vendor v = vendors.get(t.getVendorId());
                if (v != null) {
                    r.setVendorName(v.getName());
                    r.setVendorContact(v.getContact());
                    r.setPartyDisplayName(v.getName());
                    r.setPartyPhone(v.getContact());
                }
            } else if ("ONE_TIME".equals(t.getPartyType())) {
                r.setPartyDisplayName(t.getOneTimeCustomerName());
                r.setPartyPhone(t.getOneTimeCustomerPhone());
            }

            // Material
            r.setMaterialId(t.getMaterialId());
            r.setQuantityUnit(t.getQuantityUnit());
            r.setLoadedWeightKg(t.getLoadedWeightKg());
            r.setEmptyWeightKg(t.getEmptyWeightKg());
            r.setNetWeightKg(t.getNetWeightKg());
            r.setBillableQuantity(t.getBillableQuantity());
            r.setSaleRate(t.getSaleRate());
            r.setMaterialAmount(t.getMaterialAmount());
            if (t.getMaterialId() != null) {
                Material m = materials.get(t.getMaterialId());
                if (m != null) r.setMaterialName(m.getName());
            }

            // Vehicle
            r.setVehicleMode(t.getVehicleMode());
            r.setTransportMode(t.getTransportMode());
            r.setVehicleId(t.getVehicleId());
            r.setDistanceKm(t.getDistanceKm());
            r.setTransportRatePerKm(t.getTransportRatePerKm());
            r.setTransportationCharge(t.getTransportationCharge());
            r.setTotalBill(t.getTotalBill());
            if (t.getVehicleId() != null) {
                Vehicle v = vehicles.get(t.getVehicleId());
                if (v != null) {
                    r.setVehicleDisplayName(v.getDisplayName());
                    r.setVehiclePlateNumber(v.getPlateNumber());
                }
            }

            // Documents & additional
            r.setDspChallanNo(t.getDspChallanNo());
            r.setVendorChallanNo(t.getVendorChallanNo());
            r.setChannelNo(t.getChannelNo());
            r.setLoadingLocation(t.getLoadingLocation());
            r.setUnloadingLocation(t.getUnloadingLocation());
            r.setNotes(t.getNotes());

            // Legacy
            r.setQuantityBrass(t.getQuantityBrass());
            r.setLoadedWeightTon(t.getLoadedWeightTon());
            r.setEmptyWeightTon(t.getEmptyWeightTon());

            r.setCreatedAt(t.getCreatedAt());
            return r;
        }).collect(Collectors.toList());
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

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
}
