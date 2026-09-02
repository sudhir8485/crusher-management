package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
import com.dsp.crusher.config.TenantContext;
import org.springframework.security.core.context.SecurityContextHolder;
import com.dsp.crusher.dto.MachineWorkLogRequest;
import com.dsp.crusher.dto.MachineWorkLogResponse;
import com.dsp.crusher.entity.Machine;
import com.dsp.crusher.entity.MachineWorkLog;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.MachineRepository;
import com.dsp.crusher.repository.MachineWorkLogRepository;
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
public class MachineWorkService {

    private final MachineWorkLogRepository repo;
    private final MachineRepository machineRepo;

    public List<MachineWorkLogResponse> list(LocalDate from, LocalDate to, Long siteId) {
        Long sid = effectiveSiteId(siteId);
        List<MachineWorkLog> rows;
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

    public MachineWorkLogResponse get(Long id) {
        MachineWorkLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("MachineWorkLog not found: " + id));
        return enrich(List.of(log)).get(0);
    }

    @Transactional
    public MachineWorkLogResponse create(MachineWorkLogRequest req) {
        MachineWorkLog log = new MachineWorkLog();
        log.setTenantId(TenantContext.get());
        log.setSiteId(SiteContext.get());
        apply(log, req);
        return enrich(List.of(repo.save(log))).get(0);
    }

    @Transactional
    public MachineWorkLogResponse update(Long id, MachineWorkLogRequest req) {
        MachineWorkLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("MachineWorkLog not found: " + id));
        apply(log, req);
        return enrich(List.of(repo.save(log))).get(0);
    }

    @Transactional
    public void deactivate(Long id) {
        MachineWorkLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("MachineWorkLog not found: " + id));
        log.setStatus("INACTIVE");
        repo.save(log);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private void apply(MachineWorkLog log, MachineWorkLogRequest req) {
        log.setLogDate(req.getLogDate());
        log.setMachineId(req.getMachineId());
        log.setWorkDescription(req.getWorkDescription());
        log.setMode(req.getMode() != null ? req.getMode() : "BUCKET");
        log.setOpeningReading(req.getOpeningReading());
        log.setClosingReading(req.getClosingReading());
        log.setNotes(req.getNotes());

        if (req.getOpeningReading() != null && req.getClosingReading() != null) {
            BigDecimal hours = req.getClosingReading().subtract(req.getOpeningReading());
            log.setTotalHours(hours.compareTo(BigDecimal.ZERO) >= 0 ? hours : BigDecimal.ZERO);
        } else {
            log.setTotalHours(null);
        }
    }

    private List<MachineWorkLogResponse> enrich(List<MachineWorkLog> rows) {
        List<Long> machineIds = rows.stream()
                .map(MachineWorkLog::getMachineId).distinct().collect(Collectors.toList());
        Map<Long, Machine> machines = machineRepo.findAllById(machineIds).stream()
                .collect(Collectors.toMap(Machine::getId, m -> m));

        return rows.stream().map(log -> {
            MachineWorkLogResponse r = new MachineWorkLogResponse();
            r.setId(log.getId());
            r.setLogDate(log.getLogDate());
            r.setMachineId(log.getMachineId());
            r.setWorkDescription(log.getWorkDescription());
            r.setMode(log.getMode());
            r.setOpeningReading(log.getOpeningReading());
            r.setClosingReading(log.getClosingReading());
            r.setTotalHours(log.getTotalHours());
            r.setNotes(log.getNotes());
            r.setStatus(log.getStatus());

            Machine m = machines.get(log.getMachineId());
            if (m != null) {
                r.setMachineName(m.getName());
                r.setMachineType(m.getMachineType());
            }
            return r;
        }).collect(Collectors.toList());
    }
}
