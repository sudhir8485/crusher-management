package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.MachineWorkLogRequest;
import com.dsp.crusher.dto.MachineWorkLogResponse;
import com.dsp.crusher.entity.GstInvoice;
import com.dsp.crusher.entity.GstInvoiceItem;
import com.dsp.crusher.entity.Machine;
import com.dsp.crusher.entity.MachineWorkLog;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.GstInvoiceRepository;
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
        // If rate was provided at creation time and customer is GST-registered, create invoice now
        autoCreateGstInvoice(log);
        return enrich(List.of(repo.save(log))).get(0);
    }

    @Transactional
    public MachineWorkLogResponse update(Long id, MachineWorkLogRequest req) {
        MachineWorkLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("MachineWorkLog not found: " + id));

        Long oldGstInvoiceId  = log.getGstInvoiceId();
        boolean becomingInternal = "INTERNAL".equals(req.getWorkPurpose());

        apply(log, req);

        if (oldGstInvoiceId != null && becomingInternal) {
            // Work purpose changed to Internal: deactivate the linked invoice
            invoiceRepo.findById(oldGstInvoiceId).ifPresent(inv -> {
                inv.setStatus("INACTIVE");
                invoiceRepo.save(inv);
            });
            log.setGstInvoiceId(null);
        } else if (oldGstInvoiceId != null) {
            // Still billable: sync invoice amount if invoice is still PENDING (hours may have changed)
            syncPendingInvoiceAmount(log, oldGstInvoiceId);
        } else {
            // No invoice yet: create one if rate is now SET and customer is GST-registered
            autoCreateGstInvoice(log);
        }

        return enrich(List.of(repo.save(log))).get(0);
    }

    @Transactional
    public void deactivate(Long id) {
        MachineWorkLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("MachineWorkLog not found: " + id));
        log.setStatus("INACTIVE");
        // Cascade deactivation to any auto-generated GST invoice
        if (log.getGstInvoiceId() != null) {
            invoiceRepo.findById(log.getGstInvoiceId()).ifPresent(inv -> {
                inv.setStatus("INACTIVE");
                invoiceRepo.save(inv);
            });
        }
        repo.save(log);
    }

    /**
     * Sets or updates the rate on a Customer Billable entry, computes totalAmount.
     *
     * For GST-registered customers: auto-creates a PENDING GST Invoice on first call.
     * On subsequent rate edits: updates the invoice only if it is still PENDING —
     * a SET (GST-locked) invoice blocks rate changes (GST has already been confirmed).
     *
     * GST Invoice always starts PENDING because machines have no configured GST rate.
     * The user must set the GST rate explicitly via the party account ledger — the same
     * mechanism used when a material or service has gst_rate_configured = false.
     */
    @Transactional
    public MachineWorkLogResponse setRate(Long id, BigDecimal rate) {
        MachineWorkLog log = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("MachineWorkLog not found: " + id));

        if (!"CUSTOMER_BILLABLE".equals(log.getWorkPurpose())) {
            throw new IllegalStateException("Rate can only be set on Customer Billable entries");
        }

        // Guard: once GST is locked (SET), the taxable base cannot change
        if (log.getGstInvoiceId() != null) {
            GstInvoice existing = invoiceRepo.findById(log.getGstInvoiceId()).orElse(null);
            if (existing != null && "SET".equals(existing.getGstStatus())) {
                throw new IllegalStateException(
                        "GST invoice " + existing.getInvoiceNo() + " is already locked. " +
                        "Rate cannot be changed after GST is confirmed.");
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

        // Auto-create or sync GST invoice for GST-registered customers
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

    // ── Helpers ──────────────────────────────────────────────────────────────

    private void apply(MachineWorkLog log, MachineWorkLogRequest req) {
        log.setLogDate(req.getLogDate());
        log.setMachineId(req.getMachineId());
        log.setWorkDescription(req.getWorkDescription());
        log.setMode(req.getMode() != null ? req.getMode() : "BUCKET");
        log.setOpeningReading(req.getOpeningReading());
        log.setClosingReading(req.getClosingReading());
        log.setNotes(req.getNotes());

        BigDecimal hours = null;
        if (req.getOpeningReading() != null && req.getClosingReading() != null) {
            hours = req.getClosingReading().subtract(req.getOpeningReading());
            log.setTotalHours(hours.compareTo(BigDecimal.ZERO) >= 0 ? hours : BigDecimal.ZERO);
        } else {
            log.setTotalHours(null);
        }

        String purpose = req.getWorkPurpose() != null ? req.getWorkPurpose() : "INTERNAL";
        log.setWorkPurpose(purpose);

        if ("CUSTOMER_BILLABLE".equals(purpose)) {
            log.setCustomerId(req.getCustomerId());
            if (!"SET".equals(log.getRateStatus())) {
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
                    log.setRateStatus("PENDING");
                    log.setTotalAmount(null);
                }
            } else {
                // Rate is locked: re-compute totalAmount if hours changed
                if (log.getRate() != null && log.getTotalHours() != null) {
                    log.setTotalAmount(log.getRate().multiply(log.getTotalHours()).setScale(2, RoundingMode.HALF_UP));
                }
            }
        } else {
            log.setCustomerId(null);
            log.setRate(null);
            log.setRateStatus(null);
            log.setTotalAmount(null);
            log.setRateSetBy(null);
            log.setRateSetAt(null);
            log.setRatePrev(null);
            // gstInvoiceId is cleared by update() when switching to INTERNAL
        }
    }

    /** Creates a GST invoice for the log if not yet created, rate is SET, and customer is GST-registered. */
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

    /** Updates a PENDING invoice's line item amount when the rate or hours change. SET invoices are untouched. */
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

        GstInvoice inv = new GstInvoice();
        inv.setTenantId(TenantContext.get());
        inv.setVendorId(log.getCustomerId());
        inv.setInvoiceDate(log.getLogDate());
        inv.setInvoiceNo(nextInvoiceNo(log.getLogDate()));
        inv.setNotes("Auto-generated from Machine Work — set GST rate in party account to confirm");
        inv.setSgstRate(BigDecimal.ZERO);
        inv.setCgstRate(BigDecimal.ZERO);
        inv.setSubtotal(log.getTotalAmount());
        inv.setSgstAmount(BigDecimal.ZERO);
        inv.setCgstAmount(BigDecimal.ZERO);
        inv.setGrandTotal(log.getTotalAmount());
        inv.setGstStatus("PENDING");

        GstInvoiceItem item = new GstInvoiceItem();
        item.setInvoice(inv);
        item.setDescription(buildItemDescription(log, machineName));
        item.setRate(log.getRate());
        item.setQuantityBrass(log.getTotalHours());
        item.setAmount(log.getTotalAmount());
        inv.getItems().add(item);

        return inv;
    }

    private String buildItemDescription(MachineWorkLog log, String machineName) {
        StringBuilder sb = new StringBuilder(machineName).append(" — Machine Work");
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
