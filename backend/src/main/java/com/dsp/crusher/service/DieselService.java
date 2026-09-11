package com.dsp.crusher.service;

import com.dsp.crusher.config.SiteContext;
import com.dsp.crusher.config.TenantContext;
import org.springframework.security.core.context.SecurityContextHolder;
import com.dsp.crusher.dto.*;
import com.dsp.crusher.entity.*;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.*;
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
public class DieselService {

    private final DieselReceiptRepository receiptRepo;
    private final DieselUsageRepository   usageRepo;
    private final VendorRepository        vendorRepo;
    private final MachineRepository       machineRepo;
    private final VehicleRepository       vehicleRepo;
    private final VendorPaymentRepository paymentRepo;
    private final UserRepository          userRepo;

    // ── Balance ──────────────────────────────────────────────────────────────

    public DieselBalanceResponse balance(Long siteId) {
        Long sid = effectiveSiteId(siteId);
        BigDecimal received = receiptRepo.sumTotalReceivedBySite(sid);
        BigDecimal used     = usageRepo.sumTotalUsedBySite(sid);
        DieselBalanceResponse r = new DieselBalanceResponse();
        r.setTotalReceivedLiters(received);
        r.setTotalUsedLiters(used);
        r.setBalanceLiters(received.subtract(used));
        return r;
    }

    // ── Receipts ─────────────────────────────────────────────────────────────

    public List<DieselReceiptResponse> listReceipts(LocalDate from, LocalDate to, Long siteId) {
        Long sid = effectiveSiteId(siteId);
        List<DieselReceipt> list;
        if (from != null && to != null)
            list = receiptRepo.findByDateRangeAndSite(from, to, sid);
        else if (from != null)
            list = receiptRepo.findByDateAndSite(from, sid);
        else
            list = receiptRepo.findByStatusOrderByReceiptDateDescIdDesc("ACTIVE");
        return enrichReceipts(list);
    }

    public DieselReceiptResponse getReceipt(Long id) {
        return enrichReceipts(List.of(receiptRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Diesel receipt not found: " + id)))).get(0);
    }

    @Transactional
    public DieselReceiptResponse createReceipt(DieselReceiptRequest req, Long targetSiteId) {
        DieselReceipt r = new DieselReceipt();
        r.setTenantId(TenantContext.get());
        r.setSiteId(resolveCreateSite(targetSiteId));
        applyReceipt(r, req);
        r.setCreatedByName(getCurrentUserName());
        receiptRepo.save(r);
        createAdvancePaymentIfNeeded(r, req);
        return enrichReceipts(List.of(receiptRepo.save(r))).get(0);
    }

    @Transactional
    public DieselReceiptResponse updateReceipt(Long id, DieselReceiptRequest req) {
        DieselReceipt r = receiptRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Diesel receipt not found: " + id));
        // Deactivate prior advance payment before re-applying
        deactivateAdvancePayment(r);
        applyReceipt(r, req);
        r.setUpdatedByName(getCurrentUserName());
        receiptRepo.save(r);
        createAdvancePaymentIfNeeded(r, req);
        return enrichReceipts(List.of(receiptRepo.save(r))).get(0);
    }

    @Transactional
    public void deactivateReceipt(Long id) {
        DieselReceipt r = receiptRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Diesel receipt not found: " + id));
        deactivateAdvancePayment(r);
        r.setStatus("INACTIVE");
        receiptRepo.save(r);
    }

    // ── Usages ────────────────────────────────────────────────────────────────

    public List<DieselUsageResponse> listUsages(LocalDate from, LocalDate to, Long siteId) {
        Long sid = effectiveSiteId(siteId);
        List<DieselUsage> list;
        if (from != null && to != null)
            list = usageRepo.findByDateRangeAndSite(from, to, sid);
        else if (from != null)
            list = usageRepo.findByDateAndSite(from, sid);
        else
            list = usageRepo.findByStatusOrderByUsageDateDescIdDesc("ACTIVE");
        return enrichUsages(list);
    }

    public DieselUsageResponse getUsage(Long id) {
        return enrichUsages(List.of(usageRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Diesel usage not found: " + id)))).get(0);
    }

    @Transactional
    public DieselUsageResponse createUsage(DieselUsageRequest req, Long targetSiteId) {
        DieselUsage u = new DieselUsage();
        u.setTenantId(TenantContext.get());
        Long sid = resolveCreateSite(targetSiteId);
        u.setSiteId(sid);
        applyUsage(u, req);
        u.setCreatedByName(getCurrentUserName());
        usageRepo.save(u);
        createDieselPaymentIfNeeded(u, req);
        DieselUsageResponse resp = enrichUsages(List.of(usageRepo.save(u))).get(0);
        BigDecimal balance = receiptRepo.sumTotalReceivedBySite(sid)
                .subtract(usageRepo.sumTotalUsedBySite(sid));
        resp.setStockWarning(balance.compareTo(BigDecimal.ZERO) < 0);
        return resp;
    }

    @Transactional
    public DieselUsageResponse updateUsage(Long id, DieselUsageRequest req) {
        DieselUsage u = usageRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Diesel usage not found: " + id));
        deactivateDieselPayment(u);
        applyUsage(u, req);
        u.setUpdatedByName(getCurrentUserName());
        usageRepo.save(u);
        createDieselPaymentIfNeeded(u, req);
        return enrichUsages(List.of(usageRepo.save(u))).get(0);
    }

    @Transactional
    public void deactivateUsage(Long id) {
        DieselUsage u = usageRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Diesel usage not found: " + id));
        deactivateDieselPayment(u);
        u.setStatus("INACTIVE");
        usageRepo.save(u);
    }

    // ── Party Advance helpers ─────────────────────────────────────────────────

    private void createAdvancePaymentIfNeeded(DieselReceipt r, DieselReceiptRequest req) {
        if (!"PARTY_ADVANCE".equals(req.getSource())) return;
        if (req.getAdvancePartyId() == null)
            throw new IllegalArgumentException("Party is required for Party Advance receipt");
        if (req.getAdvanceAmount() == null)
            throw new IllegalArgumentException("Amount is required for Party Advance receipt");

        VendorPayment p = new VendorPayment();
        p.setTenantId(r.getTenantId());
        p.setVendorId(req.getAdvancePartyId());
        p.setPaymentDate(r.getReceiptDate());
        p.setAmount(req.getAdvanceAmount());
        p.setPaymentMode("DIESEL_ADVANCE");
        p.setNotes("Diesel advance: " + r.getQuantityLiters().toPlainString() + " L (diesel receipt #" + r.getId() + ")");
        p = paymentRepo.save(p);

        r.setAdvancePartyId(req.getAdvancePartyId());
        r.setAdvancePaymentId(p.getId());
    }

    private void deactivateAdvancePayment(DieselReceipt r) {
        if (r.getAdvancePaymentId() == null) return;
        paymentRepo.findById(r.getAdvancePaymentId()).ifPresent(p -> {
            p.setStatus("INACTIVE");
            paymentRepo.save(p);
        });
        r.setAdvancePartyId(null);
        r.setAdvancePaymentId(null);
    }

    // ── External-vehicle diesel payable helpers ───────────────────────────────

    private void createDieselPaymentIfNeeded(DieselUsage u, DieselUsageRequest req) {
        if (req.getVehicleId() == null || req.getRatePerLiter() == null) return;
        Vehicle vehicle = vehicleRepo.findById(req.getVehicleId()).orElse(null);
        if (vehicle == null || !"VENDOR".equals(vehicle.getOwner()) || vehicle.getVendorId() == null) return;

        BigDecimal dieselValue = u.getQuantityLiters().multiply(req.getRatePerLiter());

        VendorPayment p = new VendorPayment();
        p.setTenantId(u.getTenantId());
        p.setVendorId(vehicle.getVendorId());
        p.setPaymentDate(u.getUsageDate());
        p.setAmount(dieselValue);
        p.setPaymentMode("DIESEL_CREDIT");
        String plate = vehicle.getPlateNumber() != null ? vehicle.getPlateNumber() : "vehicle";
        p.setNotes("Diesel given: " + u.getQuantityLiters().toPlainString() + " L to " + plate + " (diesel usage #" + u.getId() + ")");
        p = paymentRepo.save(p);

        u.setDieselPaymentId(p.getId());
    }

    private void deactivateDieselPayment(DieselUsage u) {
        if (u.getDieselPaymentId() == null) return;
        paymentRepo.findById(u.getDieselPaymentId()).ifPresent(p -> {
            p.setStatus("INACTIVE");
            paymentRepo.save(p);
        });
        u.setDieselPaymentId(null);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

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

    private void applyReceipt(DieselReceipt r, DieselReceiptRequest req) {
        r.setReceiptDate(req.getReceiptDate());
        r.setSource(req.getSource());
        r.setQuantityLiters(req.getQuantityLiters());
        if ("PARTY_ADVANCE".equals(req.getSource())) {
            // No rate/vendor/invoiceNo for party-advance receipts
            r.setRatePerLiter(null);
            r.setAmount(null);
            r.setVendorId(null);
            r.setInvoiceNo(null);
        } else {
            r.setRatePerLiter(req.getRatePerLiter());
            r.setAmount(req.getRatePerLiter() != null
                    ? req.getQuantityLiters().multiply(req.getRatePerLiter()) : null);
            r.setVendorId(req.getVendorId());
            r.setInvoiceNo(req.getInvoiceNo());
        }
        r.setNotes(req.getNotes());
    }

    private void applyUsage(DieselUsage u, DieselUsageRequest req) {
        u.setUsageDate(req.getUsageDate());
        u.setMachineId(req.getMachineId());
        u.setVehicleId(req.getVehicleId());
        u.setQuantityLiters(req.getQuantityLiters());
        u.setRatePerLiter(req.getRatePerLiter());
        u.setNotes(req.getNotes());
    }

    private List<DieselReceiptResponse> enrichReceipts(List<DieselReceipt> list) {
        if (list.isEmpty()) return List.of();
        Map<Long, Vendor> vendors = vendorRepo.findAll().stream()
                .collect(Collectors.toMap(Vendor::getId, v -> v));
        return list.stream().map(r -> {
            DieselReceiptResponse res = new DieselReceiptResponse();
            res.setId(r.getId());
            res.setReceiptDate(r.getReceiptDate());
            res.setSource(r.getSource());
            res.setQuantityLiters(r.getQuantityLiters());
            res.setRatePerLiter(r.getRatePerLiter());
            res.setAmount(r.getAmount());
            res.setVendorId(r.getVendorId());
            res.setInvoiceNo(r.getInvoiceNo());
            res.setNotes(r.getNotes());
            res.setCreatedAt(r.getCreatedAt());
            res.setCreatedByName(r.getCreatedByName());
            res.setUpdatedByName(r.getUpdatedByName());
            res.setAdvancePartyId(r.getAdvancePartyId());
            if (r.getVendorId() != null) {
                Vendor v = vendors.get(r.getVendorId());
                if (v != null) res.setVendorName(v.getName());
            }
            if (r.getAdvancePartyId() != null) {
                Vendor v = vendors.get(r.getAdvancePartyId());
                if (v != null) res.setAdvancePartyName(v.getName());
                // Resolve advance amount from the linked payment
                if (r.getAdvancePaymentId() != null) {
                    paymentRepo.findById(r.getAdvancePaymentId()).ifPresent(p -> {
                        if ("ACTIVE".equals(p.getStatus())) res.setAdvanceAmount(p.getAmount());
                    });
                }
            }
            return res;
        }).collect(Collectors.toList());
    }

    private List<DieselUsageResponse> enrichUsages(List<DieselUsage> list) {
        if (list.isEmpty()) return List.of();
        Map<Long, Machine> machines = machineRepo.findAll().stream()
                .collect(Collectors.toMap(Machine::getId, m -> m));
        Map<Long, Vehicle> vehicles = vehicleRepo.findAll().stream()
                .collect(Collectors.toMap(Vehicle::getId, v -> v));
        Map<Long, Vendor>  vendors  = vendorRepo.findAll().stream()
                .collect(Collectors.toMap(Vendor::getId, v -> v));
        return list.stream().map(u -> {
            DieselUsageResponse res = new DieselUsageResponse();
            res.setId(u.getId());
            res.setUsageDate(u.getUsageDate());
            res.setMachineId(u.getMachineId());
            res.setVehicleId(u.getVehicleId());
            res.setQuantityLiters(u.getQuantityLiters());
            res.setRatePerLiter(u.getRatePerLiter());
            if (u.getRatePerLiter() != null)
                res.setDieselValue(u.getQuantityLiters().multiply(u.getRatePerLiter()));
            res.setNotes(u.getNotes());
            res.setCreatedAt(u.getCreatedAt());
            res.setCreatedByName(u.getCreatedByName());
            res.setUpdatedByName(u.getUpdatedByName());
            res.setHasDieselPayable(u.getDieselPaymentId() != null);
            if (u.getMachineId() != null) {
                Machine m = machines.get(u.getMachineId());
                if (m != null) res.setMachineName(m.getName());
            }
            if (u.getVehicleId() != null) {
                Vehicle v = vehicles.get(u.getVehicleId());
                if (v != null) {
                    res.setVehicleDisplayName(v.getDisplayName());
                    res.setVehiclePlateNumber(v.getPlateNumber());
                    res.setVehicleOwner(v.getOwner());
                    if ("VENDOR".equals(v.getOwner()) && v.getVendorId() != null) {
                        res.setVehicleOwnedByPartyId(v.getVendorId());
                        Vendor owner = vendors.get(v.getVendorId());
                        if (owner != null) res.setVehicleOwnedByPartyName(owner.getName());
                    }
                }
            }
            return res;
        }).collect(Collectors.toList());
    }
}
