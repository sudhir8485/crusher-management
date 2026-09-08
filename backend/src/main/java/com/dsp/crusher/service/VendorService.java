package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.PartyStatementResponse;
import com.dsp.crusher.dto.VendorBalanceResponse;
import com.dsp.crusher.dto.VendorRequest;
import com.dsp.crusher.dto.VendorResponse;
import com.dsp.crusher.dto.VendorTripBalanceResponse;
import com.dsp.crusher.entity.Trip;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.entity.VendorPayment;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.GstInvoiceRepository;
import com.dsp.crusher.repository.JobWorkInvoiceRepository;
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

    private final VendorRepository       repo;
    private final GstInvoiceRepository   invoiceRepo;
    private final VendorPaymentRepository paymentRepo;
    private final TripRepository          tripRepo;
    private final MaterialRepository      materialRepo;
    private final JobWorkInvoiceRepository jobWorkRepo;

    public List<VendorResponse> listActive() {
        return repo.findByStatusAndIsActiveTrue("ACTIVE").stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    public List<VendorResponse> listAll() {
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
        r.setIsRegular(v.getIsRegular());
        r.setContact(v.getContact());
        r.setAddress(v.getAddress());
        r.setStatus(v.getStatus());
        r.setActive(v.isActive());
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
            r.setIsRegular(v.getIsRegular());
            r.setOutstanding(billed.subtract(paid));
            r.setLastActivityDate(lastActivity);
            result.add(r);
        }
        return result;
    }

    /** Khatabook-style unified statement: trips (BILLED) + payments (RECEIVED) with running balance. */
    public PartyStatementResponse getStatement(Long vendorId, LocalDate from, LocalDate to) {
        Vendor v = repo.findById(vendorId)
                .orElseThrow(() -> new ResourceNotFoundException("Vendor not found: " + vendorId));

        // Opening balance = all trip bills before 'from' − all payments before 'from'
        BigDecimal tripsBefore    = tripRepo.sumTotalBillByVendorIdBefore(vendorId, from);
        BigDecimal paymentsBefore = paymentRepo.sumAmountByVendorBefore(vendorId, from);
        BigDecimal opening = tripsBefore.subtract(paymentsBefore);

        // In-period trips
        List<Trip> trips = tripRepo
                .findByVendorIdAndTripDateBetweenAndStatusOrderByTripDateAscIdAsc(vendorId, from, to, "ACTIVE");

        // In-period payments
        List<VendorPayment> payments = paymentRepo
                .findByVendorIdAndPaymentDateBetweenAndStatusOrderByPaymentDateAscIdAsc(vendorId, from, to, "ACTIVE");

        // Resolve material names
        Map<Long, String> matNames = materialRepo.findAll().stream()
                .collect(Collectors.toMap(m -> m.getId(), m -> m.getName()));

        // Merge and sort by date ASC, then ID ASC (trips before payments on same day)
        List<PartyStatementResponse.StatementEntry> entries = new ArrayList<>();
        int ti = 0, pi = 0;
        while (ti < trips.size() || pi < payments.size()) {
            boolean takeTrip;
            if (ti >= trips.size()) takeTrip = false;
            else if (pi >= payments.size()) takeTrip = true;
            else {
                int cmp = trips.get(ti).getTripDate().compareTo(payments.get(pi).getPaymentDate());
                takeTrip = cmp <= 0; // trips first on same date
            }

            PartyStatementResponse.StatementEntry e = new PartyStatementResponse.StatementEntry();
            if (takeTrip) {
                Trip t = trips.get(ti++);
                String mat = t.getMaterialId() != null ? matNames.getOrDefault(t.getMaterialId(), "—") : "—";
                e.setId(t.getId());
                e.setType("BILLED");
                e.setDate(t.getTripDate());
                e.setDescription("Trip — " + mat);
                e.setAmount(t.getTotalBill() != null ? t.getTotalBill() : BigDecimal.ZERO);
                e.setGstRate(t.getGstRate() != null ? t.getGstRate() : BigDecimal.ZERO);
                e.setMaterialAmount(t.getMaterialAmount());
                e.setTransportationCharge(t.getTransportationCharge());
            } else {
                VendorPayment p = payments.get(pi++);
                String mode = p.getPaymentMode() != null ? p.getPaymentMode() : "Cash";
                e.setId(p.getId());
                e.setType("RECEIVED");
                e.setDate(p.getPaymentDate());
                e.setDescription("Payment — " + mode.charAt(0) + mode.substring(1).toLowerCase());
                e.setAmount(p.getAmount() != null ? p.getAmount() : BigDecimal.ZERO);
            }
            entries.add(e);
        }

        // Running balance
        BigDecimal running = opening;
        BigDecimal totalBilled = BigDecimal.ZERO, totalReceived = BigDecimal.ZERO;
        for (PartyStatementResponse.StatementEntry e : entries) {
            if ("BILLED".equals(e.getType())) {
                running = running.add(e.getAmount());
                totalBilled = totalBilled.add(e.getAmount());
            } else {
                running = running.subtract(e.getAmount());
                totalReceived = totalReceived.add(e.getAmount());
            }
            e.setRunningBalance(running);
        }

        PartyStatementResponse resp = new PartyStatementResponse();
        resp.setVendorId(vendorId);
        resp.setVendorName(v.getName());
        resp.setVendorContact(v.getContact());
        resp.setGstRegistered(Boolean.TRUE.equals(v.getGstRegistered()));
        resp.setFrom(from);
        resp.setTo(to);
        resp.setOpeningBalance(opening);
        resp.setTotalBilled(totalBilled);
        resp.setTotalReceived(totalReceived);
        resp.setClosingBalance(opening.add(totalBilled).subtract(totalReceived));
        resp.setEntries(entries);
        return resp;
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
        if (req.getIsRegular() != null) v.setIsRegular(req.getIsRegular());
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
        if (req.getIsRegular() != null) v.setIsRegular(req.getIsRegular());
        v.setContact(req.getContact());
        v.setAddress(req.getAddress());
        return repo.save(v);
    }

    @Transactional
    public VendorResponse toggleActive(Long id) {
        Vendor v = getById(id);
        v.setActive(!v.isActive());
        repo.save(v);
        return toResponse(v);
    }

    @Transactional
    public void deactivate(Long id) {
        Vendor v = getById(id);
        if (tripRepo.existsByVendorId(id) ||
            invoiceRepo.existsByVendorId(id) ||
            paymentRepo.existsByVendorId(id) ||
            jobWorkRepo.existsByVendorId(id)) {
            throw new IllegalStateException(
                "This party has historical records (trips, invoices, or payments). " +
                "Use the Active/Inactive toggle to hide them instead of deleting.");
        }
        v.setStatus("INACTIVE");
        repo.save(v);
    }
}
