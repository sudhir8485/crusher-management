package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
import com.dsp.crusher.config.TenantContext;
import org.springframework.security.core.context.SecurityContextHolder;
import com.dsp.crusher.dto.DabarEntryRequest;
import com.dsp.crusher.dto.DabarEntryResponse;
import com.dsp.crusher.entity.DabarEntry;
import com.dsp.crusher.entity.Site;
import com.dsp.crusher.entity.TransportPayable;
import com.dsp.crusher.entity.Vehicle;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.DabarEntryRepository;
import com.dsp.crusher.repository.SiteRepository;
import com.dsp.crusher.repository.TransportPayableRepository;
import com.dsp.crusher.repository.UserRepository;
import com.dsp.crusher.repository.VehicleRepository;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DabarService {

    private final DabarEntryRepository repo;
    private final VehicleRepository vehicleRepo;
    private final VendorRepository vendorRepo;
    private final SiteRepository siteRepo;
    private final TransportPayableRepository payableRepo;
    private final UserRepository userRepo;

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
        Long siteId = resolveCreateSite(targetSiteId);
        e.setSiteId(siteId);
        apply(e, req);
        e.setCreatedByName(getCurrentUserName());
        e = repo.save(e); // persist to get the generated ID
        handleTransportPayable(e, req, siteId);
        return enrich(List.of(e)).get(0);
    }

    @Transactional
    public DabarEntryResponse update(Long id, DabarEntryRequest req) {
        DabarEntry e = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Dabar entry not found: " + id));
        apply(e, req);
        e.setUpdatedByName(getCurrentUserName());
        e = repo.save(e);
        handleTransportPayable(e, req, e.getSiteId());
        updatePayableAmount(e.getId(), req);
        return enrich(List.of(e)).get(0);
    }

    private void updatePayableAmount(Long dabarEntryId, DabarEntryRequest req) {
        if (req.getTransportPayableAmount() == null) return;
        payableRepo.findBySourceTypeAndSourceEntryIdAndStatus("DABAR", dabarEntryId, "ACTIVE")
                .ifPresent(p -> {
                    if (!p.isSettled()) { // never overwrite a settled payable's amount
                        p.setAmount(req.getTransportPayableAmount());
                        payableRepo.save(p);
                    }
                });
    }

    @Transactional
    public void deactivate(Long id) {
        DabarEntry e = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Dabar entry not found: " + id));
        e.setStatus("INACTIVE");
        repo.save(e);
        // Deactivate any linked transport payable
        payableRepo.findBySourceTypeAndSourceEntryIdAndStatus("DABAR", id, "ACTIVE")
                .ifPresent(p -> { p.setStatus("INACTIVE"); payableRepo.save(p); });
    }

    // ── Transport payable logic ───────────────────────────────────────────────

    /**
     * Determines whether a transport payable toggle should be shown in the UI.
     * Returns: "NONE" (tenant vehicle), "NETS" (vendor vehicle, same as site's billed party),
     * or "ELIGIBLE" (vendor vehicle, different party — toggle should be shown).
     */
    public String payableEligibility(Long vehicleId, Long siteId) {
        Vehicle vehicle = vehicleRepo.findById(vehicleId).orElse(null);
        if (vehicle == null || !"VENDOR".equals(vehicle.getOwner())) return "NONE";

        Site site = siteRepo.findById(siteId).orElse(null);
        if (site == null) return "ELIGIBLE";

        if ("CLIENT_SITE".equals(site.getSiteType())
                && site.getLinkedPartyId() != null
                && site.getLinkedPartyId().equals(vehicle.getVendorId())) {
            return "NETS"; // vehicle owner IS the site's billed party — no duplicate payable
        }
        return "ELIGIBLE";
    }

    private void handleTransportPayable(DabarEntry entry, DabarEntryRequest req, Long siteId) {
        if (req.getCreateTransportPayable() == null) return;

        // Deactivate existing payable first
        payableRepo.findBySourceTypeAndSourceEntryIdAndStatus("DABAR", entry.getId(), "ACTIVE")
                .ifPresent(p -> { p.setStatus("INACTIVE"); payableRepo.save(p); });

        if (!Boolean.TRUE.equals(req.getCreateTransportPayable())) return;

        // Validate eligibility before creating
        String eligibility = payableEligibility(entry.getVehicleId(), siteId);
        if (!"ELIGIBLE".equals(eligibility)) return;

        Vehicle vehicle = vehicleRepo.findById(entry.getVehicleId()).orElse(null);
        if (vehicle == null || vehicle.getVendorId() == null) return;

        TransportPayable payable = new TransportPayable();
        payable.setTenantId(entry.getTenantId());
        payable.setSiteId(siteId);
        payable.setEntryDate(entry.getEntryDate());
        payable.setSourceType("DABAR");
        payable.setSourceEntryId(entry.getId());
        payable.setVehicleId(entry.getVehicleId());
        payable.setPartyId(vehicle.getVendorId());
        payableRepo.save(payable);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

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

    private String getCurrentUserName() {
        try {
            String principal = SecurityContextHolder.getContext().getAuthentication().getName();
            Long userId = Long.parseLong(principal);
            return userRepo.findById(userId).map(u -> u.getFullName()).orElse(principal);
        } catch (Exception e) {
            return null;
        }
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

        // Load active payables for these entries in one query via direct lookup
        List<Long> entryIds = entries.stream().map(DabarEntry::getId).collect(Collectors.toList());
        // Use per-entry lookup — entry count is small (single-day view)
        Map<Long, TransportPayable> payableByEntryId = entryIds.stream()
                .map(id -> payableRepo.findBySourceTypeAndSourceEntryIdAndStatus("DABAR", id, "ACTIVE"))
                .filter(Optional::isPresent)
                .map(Optional::get)
                .collect(Collectors.toMap(TransportPayable::getSourceEntryId, p -> p));

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
            r.setCreatedByName(e.getCreatedByName());
            r.setUpdatedByName(e.getUpdatedByName());

            if (e.getVehicleId() != null) {
                Vehicle v = vehicles.get(e.getVehicleId());
                if (v != null) {
                    r.setVehicleDisplayName(v.getDisplayName());
                    r.setVehiclePlateNumber(v.getPlateNumber());
                    r.setVehicleOwner(v.getOwner());
                    if ("VENDOR".equals(v.getOwner()) && v.getVendorId() != null) {
                        r.setVehicleOwnedByPartyId(v.getVendorId());
                        Vendor owner = vendors.get(v.getVendorId());
                        if (owner != null) r.setVehicleOwnedByPartyName(owner.getName());
                    }
                }
            }
            if (e.getVendorId() != null) {
                Vendor v = vendors.get(e.getVendorId());
                if (v != null) r.setVendorName(v.getName());
            }

            TransportPayable payable = payableByEntryId.get(e.getId());
            if (payable != null) {
                r.setTransportPayableId(payable.getId());
                r.setTransportPayableActive(true);
                r.setTransportPayableAmount(payable.getAmount());
                r.setTransportPayableSettled(payable.isSettled());
            }
            return r;
        }).collect(Collectors.toList());
    }
}
