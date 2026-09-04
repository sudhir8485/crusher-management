package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.MachineWorkLogRequest;
import com.dsp.crusher.dto.MachineWorkLogResponse;
import com.dsp.crusher.entity.Machine;
import com.dsp.crusher.entity.MachineWorkLog;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.MachineRepository;
import com.dsp.crusher.repository.MachineWorkLogRepository;
import com.dsp.crusher.repository.UserRepository;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MachineWorkService {

    private final MachineWorkLogRepository repo;
    private final MachineRepository        machineRepo;
    private final VendorRepository         vendorRepo;
    private final UserRepository           userRepo;

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

    private Long resolveCreateSite(Long targetSiteId) {
        Long sid = effectiveSiteId(targetSiteId);
        if (sid == null) throw new IllegalArgumentException("Select a site before creating entries");
        return sid;
    }

    public MachineWorkLogResponse get(Long id) {
        MachineWorkLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("MachineWorkLog not found: " + id));
        return enrich(List.of(log)).get(0);
    }

    @Transactional
    public MachineWorkLogResponse create(MachineWorkLogRequest req, Long targetSiteId) {
        MachineWorkLog log = new MachineWorkLog();
        log.setTenantId(TenantContext.get());
        log.setSiteId(resolveCreateSite(targetSiteId));
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

    /**
     * Sets or updates the rate on a Customer Billable entry, computes totalAmount,
     * and records the audit trail (who/when). Works on both PENDING and SET entries.
     */
    @Transactional
    public MachineWorkLogResponse setRate(Long id, BigDecimal rate) {
        MachineWorkLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("MachineWorkLog not found: " + id));

        if (!"CUSTOMER_BILLABLE".equals(log.getWorkPurpose())) {
            throw new IllegalStateException("Rate can only be set on Customer Billable entries");
        }

        log.setRatePrev(log.getRate());
        log.setRate(rate);
        log.setRateStatus("SET");
        log.setRateSetBy(getCurrentUserName());
        log.setRateSetAt(LocalDateTime.now());

        if (log.getTotalHours() != null) {
            log.setTotalAmount(
                rate.multiply(log.getTotalHours()).setScale(2, RoundingMode.HALF_UP));
        }

        return enrich(List.of(repo.save(log))).get(0);
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

        // Compute totalHours
        BigDecimal hours = null;
        if (req.getOpeningReading() != null && req.getClosingReading() != null) {
            hours = req.getClosingReading().subtract(req.getOpeningReading());
            log.setTotalHours(hours.compareTo(BigDecimal.ZERO) >= 0 ? hours : BigDecimal.ZERO);
        } else {
            log.setTotalHours(null);
        }

        // Work purpose / billing fields
        String purpose = req.getWorkPurpose() != null ? req.getWorkPurpose() : "INTERNAL";
        log.setWorkPurpose(purpose);

        if ("CUSTOMER_BILLABLE".equals(purpose)) {
            log.setCustomerId(req.getCustomerId());
            // Protect SET rate from being overwritten via edit
            if (!"SET".equals(log.getRateStatus())) {
                if (req.getRate() != null) {
                    log.setRate(req.getRate());
                    log.setRateStatus("SET");
                    log.setRateSetBy(getCurrentUserName());
                    log.setRateSetAt(LocalDateTime.now());
                    BigDecimal h = log.getTotalHours();
                    if (h != null) {
                        log.setTotalAmount(
                            req.getRate().multiply(h).setScale(2, RoundingMode.HALF_UP));
                    }
                } else {
                    log.setRateStatus("PENDING");
                    log.setTotalAmount(null);
                }
            } else {
                // Rate is SET: re-compute totalAmount if hours changed
                if (log.getRate() != null && log.getTotalHours() != null) {
                    log.setTotalAmount(
                        log.getRate().multiply(log.getTotalHours()).setScale(2, RoundingMode.HALF_UP));
                }
            }
        } else {
            // Internal: clear all billable fields
            log.setCustomerId(null);
            log.setRate(null);
            log.setRateStatus(null);
            log.setTotalAmount(null);
            log.setRateSetBy(null);
            log.setRateSetAt(null);
            log.setRatePrev(null);
        }
    }

    private List<MachineWorkLogResponse> enrich(List<MachineWorkLog> rows) {
        List<Long> machineIds = rows.stream()
                .map(MachineWorkLog::getMachineId).distinct().collect(Collectors.toList());
        Map<Long, Machine> machines = machineRepo.findAllById(machineIds).stream()
                .collect(Collectors.toMap(Machine::getId, m -> m));

        List<Long> customerIds = rows.stream()
                .filter(l -> l.getCustomerId() != null)
                .map(MachineWorkLog::getCustomerId).distinct().collect(Collectors.toList());
        Map<Long, Vendor> customers = customerIds.isEmpty() ? Map.of() :
                vendorRepo.findAllById(customerIds).stream()
                        .collect(Collectors.toMap(Vendor::getId, v -> v));

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
            r.setWorkPurpose(log.getWorkPurpose());
            r.setCustomerId(log.getCustomerId());
            r.setRate(log.getRate());
            r.setRateStatus(log.getRateStatus());
            r.setTotalAmount(log.getTotalAmount());
            r.setRateSetBy(log.getRateSetBy());
            r.setRateSetAt(log.getRateSetAt());

            Machine m = machines.get(log.getMachineId());
            if (m != null) {
                r.setMachineName(m.getName());
                r.setMachineType(m.getMachineType());
            }

            if (log.getCustomerId() != null) {
                Vendor cust = customers.get(log.getCustomerId());
                if (cust != null) r.setCustomerName(cust.getName());
            }

            return r;
        }).collect(Collectors.toList());
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
}
