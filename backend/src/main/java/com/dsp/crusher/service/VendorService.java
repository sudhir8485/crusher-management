package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.VendorBalanceResponse;
import com.dsp.crusher.dto.VendorRequest;
import com.dsp.crusher.dto.VendorResponse;
import com.dsp.crusher.dto.VendorTripBalanceResponse;
import com.dsp.crusher.entity.Trip;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.GstInvoiceRepository;
import com.dsp.crusher.repository.MaterialRepository;
import com.dsp.crusher.repository.TripRepository;
import com.dsp.crusher.repository.VendorPaymentRepository;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class VendorService {

    private final VendorRepository repo;
    private final GstInvoiceRepository invoiceRepo;
    private final VendorPaymentRepository paymentRepo;
    private final TripRepository tripRepo;
    private final MaterialRepository materialRepo;

    public List<VendorResponse> listActive() {
        return repo.findByStatus("ACTIVE").stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    private VendorResponse toResponse(Vendor v) {
        VendorResponse r = new VendorResponse();
        r.setId(v.getId());
        r.setName(v.getName());
        r.setGstin(v.getGstin());
        r.setGstRegistered(v.getGstRegistered());
        r.setContact(v.getContact());
        r.setAddress(v.getAddress());
        r.setStatus(v.getStatus());
        BigDecimal invTotal = invoiceRepo.sumAllGrandTotalByVendorId(v.getId());
        BigDecimal paidTotal = paymentRepo.sumByVendorId(v.getId());
        r.setOutstandingAmount(invTotal.subtract(paidTotal));
        r.setUnpaidInvoiceCount(0);
        return r;
    }

    /** Returns all active vendors with their trip-based outstanding balance and last activity date.
     *  Used by the Accounts > Parties tab to show color-coded balances in one batch (no N+1). */
    public List<VendorBalanceResponse> getBalances() {
        List<Vendor> vendors = repo.findByStatus("ACTIVE");
        if (vendors.isEmpty()) return List.of();

        List<Long> vendorIds = vendors.stream().map(Vendor::getId).collect(Collectors.toList());

        // Batch: total billed per vendor (from trips)
        Map<Long, BigDecimal> billedMap = new java.util.HashMap<>();
        tripRepo.sumTotalBillByVendorIds(vendorIds)
                .forEach(row -> billedMap.put((Long) row[0], (BigDecimal) row[1]));

        // Batch: total paid per vendor (from payments)
        Map<Long, BigDecimal> paidMap = new java.util.HashMap<>();
        paymentRepo.sumByVendorIds(vendorIds)
                .forEach(row -> paidMap.put((Long) row[0], (BigDecimal) row[1]));

        // Batch: last trip date per vendor
        Map<Long, LocalDate> lastTripMap = new java.util.HashMap<>();
        tripRepo.lastTripDateByVendorIds(vendorIds)
                .forEach(row -> lastTripMap.put((Long) row[0], (LocalDate) row[1]));

        // Batch: last payment date per vendor
        Map<Long, LocalDate> lastPaymentMap = new java.util.HashMap<>();
        paymentRepo.lastPaymentDateByVendorIds(vendorIds)
                .forEach(row -> lastPaymentMap.put((Long) row[0], (LocalDate) row[1]));

        List<VendorBalanceResponse> result = new ArrayList<>();
        for (Vendor v : vendors) {
            BigDecimal billed = billedMap.getOrDefault(v.getId(), BigDecimal.ZERO);
            BigDecimal paid   = paidMap.getOrDefault(v.getId(), BigDecimal.ZERO);
            LocalDate lastTrip = lastTripMap.get(v.getId());
            LocalDate lastPay  = lastPaymentMap.get(v.getId());
            LocalDate lastActivity = null;
            if (lastTrip != null && lastPay != null)
                lastActivity = lastTrip.isAfter(lastPay) ? lastTrip : lastPay;
            else if (lastTrip != null) lastActivity = lastTrip;
            else if (lastPay  != null) lastActivity = lastPay;

            VendorBalanceResponse r = new VendorBalanceResponse();
            r.setVendorId(v.getId());
            r.setName(v.getName());
            r.setContact(v.getContact());
            r.setGstin(v.getGstin());
            r.setGstRegistered(v.getGstRegistered());
            r.setOutstanding(billed.subtract(paid));
            r.setLastActivityDate(lastActivity);
            result.add(r);
        }
        return result;
    }

    public Vendor getById(Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Vendor not found: " + id));
    }

    public VendorTripBalanceResponse getTripBalance(Long vendorId) {
        List<Trip> trips = tripRepo.findByVendorIdAndStatusOrderByTripDateAscIdAsc(vendorId, "ACTIVE");
        BigDecimal totalBilled = trips.stream()
                .map(t -> t.getTotalBill() != null ? t.getTotalBill() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalPaid = paymentRepo.sumByVendorId(vendorId);

        Map<Long, String> matNames = materialRepo.findAll().stream()
                .collect(Collectors.toMap(m -> m.getId(), m -> m.getName()));

        List<VendorTripBalanceResponse.TripItem> items = trips.stream().map(t -> {
            VendorTripBalanceResponse.TripItem item = new VendorTripBalanceResponse.TripItem();
            item.setId(t.getId());
            item.setTripDate(t.getTripDate());
            item.setMaterialName(t.getMaterialId() != null ? matNames.getOrDefault(t.getMaterialId(), "—") : "—");
            item.setTotalBill(t.getTotalBill() != null ? t.getTotalBill() : BigDecimal.ZERO);
            return item;
        }).collect(Collectors.toList());

        VendorTripBalanceResponse resp = new VendorTripBalanceResponse();
        resp.setTotalBilled(totalBilled);
        resp.setTotalPaid(totalPaid);
        resp.setOutstanding(totalBilled.subtract(totalPaid));
        resp.setTrips(items);
        return resp;
    }

    @Transactional
    public Vendor create(VendorRequest req) {
        Vendor v = new Vendor();
        v.setTenantId(TenantContext.get());
        v.setName(req.getName());
        v.setGstin(req.getGstin());
        if (req.getGstRegistered() != null) v.setGstRegistered(req.getGstRegistered());
        v.setContact(req.getContact());
        v.setAddress(req.getAddress());
        return repo.save(v);
    }

    @Transactional
    public Vendor update(Long id, VendorRequest req) {
        Vendor v = getById(id);
        v.setName(req.getName());
        v.setGstin(req.getGstin());
        if (req.getGstRegistered() != null) v.setGstRegistered(req.getGstRegistered());
        v.setContact(req.getContact());
        v.setAddress(req.getAddress());
        return repo.save(v);
    }

    @Transactional
    public void deactivate(Long id) {
        Vendor v = getById(id);
        v.setStatus("INACTIVE");
        repo.save(v);
    }
}
