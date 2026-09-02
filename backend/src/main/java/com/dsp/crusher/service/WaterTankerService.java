package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
import com.dsp.crusher.config.TenantContext;
import org.springframework.security.core.context.SecurityContextHolder;
import com.dsp.crusher.dto.WaterTankerLogRequest;
import com.dsp.crusher.dto.WaterTankerLogResponse;
import com.dsp.crusher.entity.Vehicle;
import com.dsp.crusher.entity.WaterTankerLog;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.VehicleRepository;
import com.dsp.crusher.repository.WaterTankerLogRepository;
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
public class WaterTankerService {

    private final WaterTankerLogRepository repo;
    private final VehicleRepository vehicleRepo;

    public List<WaterTankerLogResponse> listAll(Long siteId) {
        Long sid = effectiveSiteId(siteId);
        if (sid == null) return enrich(repo.findByStatusOrderByLogDateDescIdDesc("ACTIVE"));
        return enrich(repo.findByDateRangeAndSite(LocalDate.of(2000,1,1), LocalDate.now().plusYears(1), sid));
    }

    public List<WaterTankerLogResponse> listByDate(LocalDate date, Long siteId) {
        return enrich(repo.findByDateAndSite(date, effectiveSiteId(siteId)));
    }

    public List<WaterTankerLogResponse> listByDateRange(LocalDate from, LocalDate to, Long siteId) {
        return enrich(repo.findByDateRangeAndSite(from, to, effectiveSiteId(siteId)));
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

    public WaterTankerLogResponse getById(Long id) {
        WaterTankerLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Water tanker log not found: " + id));
        return enrich(List.of(log)).get(0);
    }

    @Transactional
    public WaterTankerLogResponse create(WaterTankerLogRequest req, Long targetSiteId) {
        WaterTankerLog log = new WaterTankerLog();
        log.setTenantId(TenantContext.get());
        log.setSiteId(resolveCreateSite(targetSiteId));
        apply(log, req);
        return enrich(List.of(repo.save(log))).get(0);
    }

    @Transactional
    public WaterTankerLogResponse update(Long id, WaterTankerLogRequest req) {
        WaterTankerLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Water tanker log not found: " + id));
        apply(log, req);
        return enrich(List.of(repo.save(log))).get(0);
    }

    @Transactional
    public void deactivate(Long id) {
        WaterTankerLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Water tanker log not found: " + id));
        log.setStatus("INACTIVE");
        repo.save(log);
    }

    private void apply(WaterTankerLog log, WaterTankerLogRequest req) {
        log.setLogDate(req.getLogDate());
        log.setVehicleId(req.getVehicleId());
        log.setHoursWorked(req.getHoursWorked());
        log.setKmRun(req.getKmRun());
        log.setTripsCount(req.getTripsCount());
        log.setRate(req.getRate());
        log.setNotes(req.getNotes());
    }

    private List<WaterTankerLogResponse> enrich(List<WaterTankerLog> logs) {
        if (logs.isEmpty()) return List.of();

        Map<Long, Vehicle> vehicles = vehicleRepo.findAll().stream()
                .collect(Collectors.toMap(Vehicle::getId, v -> v));

        return logs.stream().map(log -> {
            WaterTankerLogResponse r = new WaterTankerLogResponse();
            r.setId(log.getId());
            r.setLogDate(log.getLogDate());
            r.setVehicleId(log.getVehicleId());
            r.setHoursWorked(log.getHoursWorked());
            r.setKmRun(log.getKmRun());
            r.setTripsCount(log.getTripsCount());
            r.setRate(log.getRate());
            r.setNotes(log.getNotes());
            r.setCreatedAt(log.getCreatedAt());

            // Compute amount: prefer hours-based, fall back to trips-based
            if (log.getRate() != null) {
                if (log.getHoursWorked() != null) {
                    r.setAmount(log.getHoursWorked().multiply(log.getRate()));
                } else if (log.getTripsCount() != null) {
                    r.setAmount(BigDecimal.valueOf(log.getTripsCount()).multiply(log.getRate()));
                }
            }

            if (log.getVehicleId() != null) {
                Vehicle v = vehicles.get(log.getVehicleId());
                if (v != null) {
                    r.setVehicleDisplayName(v.getDisplayName());
                    r.setVehiclePlateNumber(v.getPlateNumber());
                }
            }
            return r;
        }).collect(Collectors.toList());
    }
}
