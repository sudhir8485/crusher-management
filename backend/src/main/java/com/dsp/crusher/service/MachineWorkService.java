package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.MachineWorkLogRequest;
import com.dsp.crusher.dto.MachineWorkLogResponse;
import com.dsp.crusher.entity.GstInvoice;
import com.dsp.crusher.entity.GstInvoiceItem;
import com.dsp.crusher.entity.Machine;
import com.dsp.crusher.entity.MachineWorkLog;
import com.dsp.crusher.entity.MachineWorkType;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.GstInvoiceRepository;
import com.dsp.crusher.repository.MachineRepository;
import com.dsp.crusher.repository.MachineWorkLogRepository;
import com.dsp.crusher.repository.MachineWorkTypeRepository;
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
    private final MachineWorkTypeRepository workTypeRepo;
    private final VendorRepository         vendorRepo;
    private final UserRepository           userRepo;
    private final GstInvoiceRepository     invoiceRepo;

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
        log = repo.save(log);
        autoCreateGstInvoice(log);
        return enrich(List.of(repo.save(log))).get(0);
    }

    @Transactional
    public MachineWorkLogResponse update(Long id, MachineWorkLogRequest req) {
        MachineWorkLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("MachineWorkLog not found: " + id));

        Long oldGstInvoiceId = log.getGstInvoiceId();
        boolean becomingInternal = "INTERNAL".equals(req.getWorkPurpose());

        // Guard: cannot change rate once GST invoice is locked (GST confirmed)
        if (oldGstInvoiceId != null && !becomingInternal && req.getRate() != null) {
            GstInvoice existing = invoiceRepo.findById(oldGstInvoiceId).orElse(null);
            if (existing != null && "SET".equals(existing.getGstStatus())
                    && (log.getRate() == null || req.getRate().compareTo(log.getRate()) != 0)) {
                throw new IllegalStateException(
                    "GST invoice " + existing.getInvoiceNo() + " is already confirmed. " +
                    "Rate cannot be changed after GST is locked.");
            }
        }

        apply(log, req);

        if (oldGstInvoiceId != null && becomingInternal) {
            invoiceRepo.findById(oldGstInvoiceId).ifPresent(inv -> {
                inv.setStatus("INACTIVE");
                invoiceRepo.save(inv);
            });
            log.setGstInvoiceId(null);
        } else if (oldGstInvoiceId != null) {
            syncPendingInvoiceAmount(log, oldGstInvoiceId);
        } else {
            autoCreateGstInvoice(log);
        }

        return enrich(List.of(repo.save(log))).get(0);
    }

    /** Convenience endpoint — same as editing via PUT with a new rate. Kept for API compatibility. */
    @Transactional
    public MachineWorkLogResponse setRate(Long id, BigDecimal rate) {
        MachineWorkLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("MachineWorkLog not found: " + id));
        if (!"CUSTOMER_BILLABLE".equals(log.getWorkPurpose())) {
            throw new IllegalStateException("Rate can only be set on Customer Billable entries");
        }
        if (log.getGstInvoiceId() != null) {
            GstInvoice existing = invoiceRepo.findById(log.getGstInvoiceId()).orElse(null);
            if (existing != null && "SET".equals(existing.getGstStatus())) {
                throw new IllegalStateException(
                    "GST invoice " + existing.getInvoiceNo() + " is already confirmed. " +
                    "Rate cannot be changed after GST is locked.");
            }
        }
        log.setRatePrev(log.getRate());
        log.setRate(rate);
        log.setRateStatus("SET");
        log.setRateSetBy(getCurrentUserName());
        log.setRateSetAt(LocalDateTime.now());
        if (log.getTotalHours() != null) {
            log.setTotalAmount(rate.multiply(log.getTotalHours()).setScale(2, RoundingMode.HALF_UP));
        }
        if (log.getCustomerId() != null && log.getTotalAmount() != null) {
            Vendor customer = vendorRepo.findById(log.getCustomerId()).orElse(null);
            if (customer != null && Boolean.TRUE.equals(customer.getGstRegistered())) {
                if (log.getGstInvoiceId() == null) {
                    GstInvoice inv = buildMachineWorkInvoice(log);
                    inv = invoiceRepo.save(inv);
                    log.setGstInvoiceId(inv.getId());
                } else {
                    syncPendingInvoiceAmount(log, log.getGstInvoiceId());
                }
            }
        }
        return enrich(List.of(repo.save(log))).get(0);
    }

    @Transactional
    public void deactivate(Long id) {
        MachineWorkLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("MachineWorkLog not found: " + id));
        log.setStatus("INACTIVE");
        if (log.getGstInvoiceId() != null) {
            invoiceRepo.findById(log.getGstInvoiceId()).ifPresent(inv -> {
                inv.setStatus("INACTIVE");
                invoiceRepo.save(inv);
            });
        }
        repo.save(log);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private void apply(MachineWorkLog log, MachineWorkLogRequest req) {
        log.setLogDate(req.getLogDate());
        log.setMachineId(req.getMachineId());
        log.setWorkDescription(req.getWorkDescription());
        log.setWorkTypeId(req.getWorkTypeId());
        log.setNotes(req.getNotes());

        // Resolve mode from work type label when workTypeId provided
        if (req.getWorkTypeId() != null) {
            workTypeRepo.findById(req.getWorkTypeId())
                    .ifPresent(wt -> log.setMode(wt.getLabel()));
        } else {
            log.setMode(req.getMode());
        }

        // Compute hours
        BigDecimal hours = null;
        if (req.getOpeningReading() != null && req.getClosingReading() != null) {
            hours = req.getClosingReading().subtract(req.getOpeningReading());
            log.setOpeningReading(req.getOpeningReading());
            log.setClosingReading(req.getClosingReading());
            log.setTotalHours(hours.compareTo(BigDecimal.ZERO) >= 0 ? hours : BigDecimal.ZERO);
        } else {
            log.setOpeningReading(req.getOpeningReading());
            log.setClosingReading(req.getClosingReading());
            log.setTotalHours(null);
        }

        String purpose = req.getWorkPurpose() != null ? req.getWorkPurpose() : "INTERNAL";
        log.setWorkPurpose(purpose);

        if ("CUSTOMER_BILLABLE".equals(purpose)) {
            log.setCustomerId(req.getCustomerId());
            if (req.getRate() != null) {
                log.setRate(req.getRate());
                log.setRateStatus("SET");
                log.setRateSetBy(getCurrentUserName());
                log.setRateSetAt(LocalDateTime.now());
                BigDecimal h = log.getTotalHours();
                if (h != null) {
                    log.setTotalAmount(req.getRate().multiply(h).setScale(2, RoundingMode.HALF_UP));
                }
            } else {
                log.setRate(null);
                log.setRateStatus("PENDING");
                log.setTotalAmount(null);
            }
        } else {
            log.setCustomerId(null);
            log.setRate(null);
            log.setRateStatus(null);
            log.setTotalAmount(null);
            log.setRateSetBy(null);
            log.setRateSetAt(null);
            log.setRatePrev(null);
        }
    }

    private void autoCreateGstInvoice(MachineWorkLog log) {
        if (!"SET".equals(log.getRateStatus())) return;
        if (log.getTotalAmount() == null || log.getCustomerId() == null) return;
        if (log.getGstInvoiceId() != null) return;

        Vendor customer = vendorRepo.findById(log.getCustomerId()).orElse(null);
        if (customer == null || !Boolean.TRUE.equals(customer.getGstRegistered())) return;

        GstInvoice inv = buildMachineWorkInvoice(log);
        inv = invoiceRepo.save(inv);
        log.setGstInvoiceId(inv.getId());
    }

    private void syncPendingInvoiceAmount(MachineWorkLog log, Long invoiceId) {
        if (log.getTotalAmount() == null) return;
        invoiceRepo.findById(invoiceId).ifPresent(inv -> {
            if (!"PENDING".equals(inv.getGstStatus())) return;
            Machine machine = machineRepo.findById(log.getMachineId()).orElse(null);
            String machineName = machine != null ? machine.getName() : "Machine";
            if (!inv.getItems().isEmpty()) {
                GstInvoiceItem item = inv.getItems().get(0);
                item.setDescription(buildItemDescription(log, machineName));
                item.setRate(log.getRate());
                item.setQuantityBrass(log.getTotalHours());
                item.setAmount(log.getTotalAmount());
            }
            inv.setSubtotal(log.getTotalAmount());
            inv.setSgstAmount(BigDecimal.ZERO);
            inv.setCgstAmount(BigDecimal.ZERO);
            inv.setGrandTotal(log.getTotalAmount());
            invoiceRepo.save(inv);
        });
    }

    private GstInvoice buildMachineWorkInvoice(MachineWorkLog log) {
        Machine machine = machineRepo.findById(log.getMachineId()).orElse(null);
        String machineName = machine != null ? machine.getName() : "Machine";

        // Resolve GST defaults from work type
        BigDecimal gstRate = BigDecimal.ZERO;
        if (log.getWorkTypeId() != null) {
            MachineWorkType wt = workTypeRepo.findById(log.getWorkTypeId()).orElse(null);
            if (wt != null && wt.getDefaultGstRate() != null
                    && wt.getDefaultGstRate().compareTo(BigDecimal.ZERO) > 0) {
                gstRate = wt.getDefaultGstRate();
            }
        }
        BigDecimal halfGst = gstRate.divide(new BigDecimal("2"), 2, RoundingMode.HALF_UP);
        BigDecimal subtotal = log.getTotalAmount();
        BigDecimal sgstAmt = subtotal.multiply(halfGst)
                .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        BigDecimal cgstAmt = sgstAmt;
        BigDecimal grandTotal = subtotal.add(sgstAmt).add(cgstAmt);
        String gstStatus = gstRate.compareTo(BigDecimal.ZERO) > 0 ? "SET" : "PENDING";

        GstInvoice inv = new GstInvoice();
        inv.setTenantId(TenantContext.get());
        inv.setVendorId(log.getCustomerId());
        inv.setInvoiceDate(log.getLogDate());
        inv.setInvoiceNo(nextInvoiceNo(log.getLogDate()));
        inv.setNotes(gstStatus.equals("SET")
                ? "Auto-generated from Machine Work"
                : "Auto-generated from Machine Work — set GST rate in party account to confirm");
        inv.setSgstRate(halfGst);
        inv.setCgstRate(halfGst);
        inv.setSubtotal(subtotal);
        inv.setSgstAmount(sgstAmt);
        inv.setCgstAmount(cgstAmt);
        inv.setGrandTotal(grandTotal);
        inv.setGstStatus(gstStatus);

        GstInvoiceItem item = new GstInvoiceItem();
        item.setInvoice(inv);
        item.setDescription(buildItemDescription(log, machineName));
        item.setRate(log.getRate());
        item.setQuantityBrass(log.getTotalHours());
        item.setAmount(subtotal);
        inv.getItems().add(item);

        return inv;
    }

    private String buildItemDescription(MachineWorkLog log, String machineName) {
        StringBuilder sb = new StringBuilder(machineName);
        if (log.getMode() != null && !log.getMode().isBlank()) {
            sb.append(" — ").append(log.getMode());
        } else {
            sb.append(" — Machine Work");
        }
        if (log.getTotalHours() != null) {
            sb.append(" (").append(log.getTotalHours().stripTrailingZeros().toPlainString()).append(" hrs");
            if (log.getRate() != null) {
                sb.append(" @ ₹").append(log.getRate().stripTrailingZeros().toPlainString()).append("/hr");
            }
            sb.append(")");
        }
        return sb.toString();
    }

    private String nextInvoiceNo(LocalDate date) {
        int year = date.getMonthValue() >= 4 ? date.getYear() : date.getYear() - 1;
        String fy = year + "-" + String.format("%02d", (year + 1) % 100);
        long count = invoiceRepo.countByTenantIdAndInvoiceNoStartingWith(TenantContext.get(), "DSP/" + fy + "/");
        return "DSP/" + fy + "/" + (count + 1);
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

        List<Long> invoiceIds = rows.stream()
                .filter(l -> l.getGstInvoiceId() != null)
                .map(MachineWorkLog::getGstInvoiceId).distinct().collect(Collectors.toList());
        Map<Long, String> invoiceStatuses = invoiceIds.isEmpty() ? Map.of() :
                invoiceRepo.findAllById(invoiceIds).stream()
                        .collect(Collectors.toMap(GstInvoice::getId, GstInvoice::getGstStatus));

        return rows.stream().map(log -> {
            MachineWorkLogResponse r = new MachineWorkLogResponse();
            r.setId(log.getId());
            r.setLogDate(log.getLogDate());
            r.setMachineId(log.getMachineId());
            r.setWorkDescription(log.getWorkDescription());
            r.setMode(log.getMode());
            r.setWorkTypeId(log.getWorkTypeId());
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
            r.setGstInvoiceId(log.getGstInvoiceId());
            if (log.getGstInvoiceId() != null) {
                r.setGstInvoiceStatus(invoiceStatuses.get(log.getGstInvoiceId()));
            }
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
