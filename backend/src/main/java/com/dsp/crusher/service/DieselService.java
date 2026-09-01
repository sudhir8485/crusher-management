package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.*;
import com.dsp.crusher.entity.DieselReceipt;
import com.dsp.crusher.entity.DieselUsage;
import com.dsp.crusher.entity.Machine;
import com.dsp.crusher.entity.Vehicle;
import com.dsp.crusher.entity.Vendor;
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
    private final DieselUsageRepository usageRepo;
    private final VendorRepository vendorRepo;
    private final MachineRepository machineRepo;
    private final VehicleRepository vehicleRepo;

    // ── Balance ──────────────────────────────────────────────────────────────

    public DieselBalanceResponse balance() {
        BigDecimal received = receiptRepo.sumTotalReceived();
        BigDecimal used = usageRepo.sumTotalUsed();
        DieselBalanceResponse r = new DieselBalanceResponse();
        r.setTotalReceivedLiters(received);
        r.setTotalUsedLiters(used);
        r.setBalanceLiters(received.subtract(used));
        return r;
    }

    // ── Receipts ─────────────────────────────────────────────────────────────

    public List<DieselReceiptResponse> listReceipts(LocalDate from, LocalDate to) {
        List<DieselReceipt> list;
        if (from != null && to != null)
            list = receiptRepo.findByReceiptDateBetweenAndStatusOrderByReceiptDateDescIdDesc(from, to, "ACTIVE");
        else if (from != null)
            list = receiptRepo.findByReceiptDateAndStatusOrderByIdAsc(from, "ACTIVE");
        else
            list = receiptRepo.findByStatusOrderByReceiptDateDescIdDesc("ACTIVE");
        return enrichReceipts(list);
    }

    public DieselReceiptResponse getReceipt(Long id) {
        return enrichReceipts(List.of(receiptRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Diesel receipt not found: " + id)))).get(0);
    }

    @Transactional
    public DieselReceiptResponse createReceipt(DieselReceiptRequest req) {
        DieselReceipt r = new DieselReceipt();
        r.setTenantId(TenantContext.get());
        applyReceipt(r, req);
        return enrichReceipts(List.of(receiptRepo.save(r))).get(0);
    }

    @Transactional
    public DieselReceiptResponse updateReceipt(Long id, DieselReceiptRequest req) {
        DieselReceipt r = receiptRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Diesel receipt not found: " + id));
        applyReceipt(r, req);
        return enrichReceipts(List.of(receiptRepo.save(r))).get(0);
    }

    @Transactional
    public void deactivateReceipt(Long id) {
        DieselReceipt r = receiptRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Diesel receipt not found: " + id));
        r.setStatus("INACTIVE");
        receiptRepo.save(r);
    }

    // ── Usages ────────────────────────────────────────────────────────────────

    public List<DieselUsageResponse> listUsages(LocalDate from, LocalDate to) {
        List<DieselUsage> list;
        if (from != null && to != null)
            list = usageRepo.findByUsageDateBetweenAndStatusOrderByUsageDateDescIdDesc(from, to, "ACTIVE");
        else if (from != null)
            list = usageRepo.findByUsageDateAndStatusOrderByIdAsc(from, "ACTIVE");
        else
            list = usageRepo.findByStatusOrderByUsageDateDescIdDesc("ACTIVE");
        return enrichUsages(list);
    }

    public DieselUsageResponse getUsage(Long id) {
        return enrichUsages(List.of(usageRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Diesel usage not found: " + id)))).get(0);
    }

    @Transactional
    public DieselUsageResponse createUsage(DieselUsageRequest req) {
        DieselUsage u = new DieselUsage();
        u.setTenantId(TenantContext.get());
        applyUsage(u, req);
        DieselUsageResponse resp = enrichUsages(List.of(usageRepo.save(u))).get(0);
        BigDecimal balance = receiptRepo.sumTotalReceived().subtract(usageRepo.sumTotalUsed());
        resp.setStockWarning(balance.compareTo(BigDecimal.ZERO) < 0);
        return resp;
    }

    @Transactional
    public DieselUsageResponse updateUsage(Long id, DieselUsageRequest req) {
        DieselUsage u = usageRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Diesel usage not found: " + id));
        applyUsage(u, req);
        return enrichUsages(List.of(usageRepo.save(u))).get(0);
    }

    @Transactional
    public void deactivateUsage(Long id) {
        DieselUsage u = usageRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Diesel usage not found: " + id));
        u.setStatus("INACTIVE");
        usageRepo.save(u);
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private void applyReceipt(DieselReceipt r, DieselReceiptRequest req) {
        r.setReceiptDate(req.getReceiptDate());
        r.setSource(req.getSource());
        r.setQuantityLiters(req.getQuantityLiters());
        r.setRatePerLiter(req.getRatePerLiter());
        r.setAmount(req.getRatePerLiter() != null
                ? req.getQuantityLiters().multiply(req.getRatePerLiter()) : null);
        r.setVendorId(req.getVendorId());
        r.setInvoiceNo(req.getInvoiceNo());
        r.setNotes(req.getNotes());
    }

    private void applyUsage(DieselUsage u, DieselUsageRequest req) {
        u.setUsageDate(req.getUsageDate());
        u.setMachineId(req.getMachineId());
        u.setVehicleId(req.getVehicleId());
        u.setQuantityLiters(req.getQuantityLiters());
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
            if (r.getVendorId() != null) {
                Vendor v = vendors.get(r.getVendorId());
                if (v != null) res.setVendorName(v.getName());
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
        return list.stream().map(u -> {
            DieselUsageResponse res = new DieselUsageResponse();
            res.setId(u.getId());
            res.setUsageDate(u.getUsageDate());
            res.setMachineId(u.getMachineId());
            res.setVehicleId(u.getVehicleId());
            res.setQuantityLiters(u.getQuantityLiters());
            res.setNotes(u.getNotes());
            res.setCreatedAt(u.getCreatedAt());
            if (u.getMachineId() != null) {
                Machine m = machines.get(u.getMachineId());
                if (m != null) res.setMachineName(m.getName());
            }
            if (u.getVehicleId() != null) {
                Vehicle v = vehicles.get(u.getVehicleId());
                if (v != null) {
                    res.setVehicleDisplayName(v.getDisplayName());
                    res.setVehiclePlateNumber(v.getPlateNumber());
                }
            }
            return res;
        }).collect(Collectors.toList());
    }
}
