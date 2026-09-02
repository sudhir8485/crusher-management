package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
import com.dsp.crusher.config.TenantContext;
import org.springframework.security.core.context.SecurityContextHolder;
import com.dsp.crusher.dto.VehicleDailyLogRequest;
import com.dsp.crusher.dto.VehicleDailyLogResponse;
import com.dsp.crusher.entity.Vehicle;
import com.dsp.crusher.entity.VehicleDailyLog;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.VehicleDailyLogRepository;
import com.dsp.crusher.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class VehicleDailyLogService {

    private final VehicleDailyLogRepository repo;
    private final VehicleRepository vehicleRepo;

    public List<VehicleDailyLogResponse> list(LocalDate from, LocalDate to, Long siteId) {
        Long sid = effectiveSiteId(siteId);
        List<VehicleDailyLog> rows;
        if (from != null && to != null)
            rows = repo.findByDateRangeAndSite(from, to, sid);
        else if (from != null)
            rows = repo.findByDateAndSite(from, sid);
        else
            rows = repo.findByStatusOrderByLogDateDescIdDesc("ACTIVE");
        return enrich(rows);
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

    public VehicleDailyLogResponse get(Long id) {
        return enrich(List.of(repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("VehicleDailyLog not found: " + id)))).get(0);
    }

    @Transactional
    public VehicleDailyLogResponse create(VehicleDailyLogRequest req, Long targetSiteId) {
        VehicleDailyLog log = new VehicleDailyLog();
        log.setTenantId(TenantContext.get());
        log.setSiteId(resolveCreateSite(targetSiteId));
        apply(log, req);
        return enrich(List.of(repo.save(log))).get(0);
    }

    @Transactional
    public VehicleDailyLogResponse update(Long id, VehicleDailyLogRequest req) {
        VehicleDailyLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("VehicleDailyLog not found: " + id));
        apply(log, req);
        return enrich(List.of(repo.save(log))).get(0);
    }

    @Transactional
    public void deactivate(Long id) {
        VehicleDailyLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("VehicleDailyLog not found: " + id));
        log.setStatus("INACTIVE");
        repo.save(log);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private void apply(VehicleDailyLog log, VehicleDailyLogRequest req) {
        log.setLogDate(req.getLogDate());
        log.setVehicleId(req.getVehicleId());
        log.setLoadingLocation(req.getLoadingLocation());
        log.setUnloadingLocation(req.getUnloadingLocation());
        log.setOpeningReading(req.getOpeningReading());
        log.setClosingReading(req.getClosingReading());
        log.setDieselNote(req.getDieselNote());

        // Computed: total KM
        if (req.getOpeningReading() != null && req.getClosingReading() != null) {
            BigDecimal km = req.getClosingReading().subtract(req.getOpeningReading());
            log.setTotalKm(km.compareTo(BigDecimal.ZERO) >= 0 ? km : BigDecimal.ZERO);
        } else {
            log.setTotalKm(null);
        }

        // Computed: total trips
        int day = req.getTripsDay() != null ? req.getTripsDay() : 0;
        int night = req.getTripsNight() != null ? req.getTripsNight() : 0;
        log.setTripsDay(day);
        log.setTripsNight(night);
        log.setTotalTrips(day + night);
    }

    private List<VehicleDailyLogResponse> enrich(List<VehicleDailyLog> rows) {
        List<Long> vehicleIds = rows.stream()
                .map(VehicleDailyLog::getVehicleId).distinct().collect(Collectors.toList());
        Map<Long, Vehicle> vehicles = vehicleRepo.findAllById(vehicleIds).stream()
                .collect(Collectors.toMap(Vehicle::getId, v -> v));

        return rows.stream().map(log -> {
            VehicleDailyLogResponse r = new VehicleDailyLogResponse();
            r.setId(log.getId());
            r.setLogDate(log.getLogDate());
            r.setVehicleId(log.getVehicleId());
            r.setLoadingLocation(log.getLoadingLocation());
            r.setUnloadingLocation(log.getUnloadingLocation());
            r.setOpeningReading(log.getOpeningReading());
            r.setClosingReading(log.getClosingReading());
            r.setTotalKm(log.getTotalKm());
            r.setTripsDay(log.getTripsDay());
            r.setTripsNight(log.getTripsNight());
            r.setTotalTrips(log.getTotalTrips());
            r.setDieselNote(log.getDieselNote());
            r.setStatus(log.getStatus());

            Vehicle v = vehicles.get(log.getVehicleId());
            if (v != null) {
                r.setVehicleDisplayName(v.getDisplayName() != null ? v.getDisplayName() : v.getPlateNumber());
                r.setVehiclePlateNumber(v.getPlateNumber());
            }
            return r;
        }).collect(Collectors.toList());
    }
}
