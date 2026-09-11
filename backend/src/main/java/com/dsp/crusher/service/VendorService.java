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
import com.dsp.crusher.repository.MachineWorkLogRepository;
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

    private final VendorRepository              repo;
    private final GstInvoiceRepository          invoiceRepo;
    private final VendorPaymentRepository       paymentRepo;
    private final TripRepository                tripRepo;
    private final MaterialRepository            materialRepo;
    private final JobWorkInvoiceRepository      jobWorkRepo;
    private final MachineWorkLogRepository      machineWorkRepo;
    private final com.dsp.crusher.repository.TransportPayableRepository transportPayableRepo;
    private final com.dsp.crusher.repository.VehicleRepository          vehicleRepo;

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

    /** Returns all active vendors with their outstanding balance and last activity date.
     *  Outstanding = GST invoices + Job-Work invoices + billable Machine Work (SET, not yet invoiced) − payments.
     *  Matches the same sources used by LedgerService so the list and detail always agree. */
    public List<VendorBalanceResponse> getBalances() {
        List<Vendor> vendors = repo.findByStatus("ACTIVE");
        if (vendors.isEmpty()) return List.of();

        List<Long> vendorIds = vendors.stream().map(Vendor::getId).collect(Collectors.toList());

        // Batch: GST invoice totals per vendor
        Map<Long, BigDecimal> gstMap = new java.util.HashMap<>();
        invoiceRepo.sumGrandTotalByVendorIds(vendorIds)
                .forEach(row -> gstMap.put((Long) row[0], (BigDecimal) row[1]));

        // Batch: Job-Work invoice totals per vendor
        Map<Long, BigDecimal> jwMap = new java.util.HashMap<>();
        jobWorkRepo.sumGrandTotalByVendorIds(vendorIds)
                .forEach(row -> jwMap.put((Long) row[0], (BigDecimal) row[1]));

        // Batch: billable machine work totals per vendor (SET rate, not yet converted to invoice)
        Map<Long, BigDecimal> mwMap = new java.util.HashMap<>();
        machineWorkRepo.sumBillableAmountByCustomerIds(vendorIds)
                .forEach(row -> mwMap.put((Long) row[0], (BigDecimal) row[1]));

        // Batch: auto-invoiced direct trip totals per vendor (non-GST parties, V30+)
        Map<Long, BigDecimal> tripDirectMap = new java.util.HashMap<>();
        tripRepo.sumAutoInvoicedDirectByVendorIds(vendorIds)
                .forEach(row -> tripDirectMap.put((Long) row[0], (BigDecimal) row[1]));

        // Batch: RECEIVED payments per vendor (party pays DSP, or system credits like TRANSPORT_CREDIT)
        Map<Long, BigDecimal> paidMap = new java.util.HashMap<>();
        paymentRepo.sumByVendorIds(vendorIds)
                .forEach(row -> paidMap.put((Long) row[0], (BigDecimal) row[1]));

        // Batch: PAID payments per vendor (DSP pays party to settle a payable)
        Map<Long, BigDecimal> paidOutMap = new java.util.HashMap<>();
        paymentRepo.sumPaidByVendorIds(vendorIds)
                .forEach(row -> paidOutMap.put((Long) row[0], (BigDecimal) row[1]));

        // Batch: last dates per vendor (for last-activity display)
        Map<Long, LocalDate> lastGstMap = new java.util.HashMap<>();
        invoiceRepo.lastInvoiceDateByVendorIds(vendorIds)
                .forEach(row -> lastGstMap.put((Long) row[0], (LocalDate) row[1]));

        Map<Long, LocalDate> lastJwMap = new java.util.HashMap<>();
        jobWorkRepo.lastInvoiceDateByVendorIds(vendorIds)
                .forEach(row -> lastJwMap.put((Long) row[0], (LocalDate) row[1]));

        Map<Long, LocalDate> lastMwMap = new java.util.HashMap<>();
        machineWorkRepo.lastLogDateByCustomerIds(vendorIds)
                .forEach(row -> lastMwMap.put((Long) row[0], (LocalDate) row[1]));

        Map<Long, LocalDate> lastTripDirectMap = new java.util.HashMap<>();
        tripRepo.lastAutoInvoicedDirectDateByVendorIds(vendorIds)
                .forEach(row -> lastTripDirectMap.put((Long) row[0], (LocalDate) row[1]));

        Map<Long, LocalDate> lastPayMap = new java.util.HashMap<>();
        paymentRepo.lastPaymentDateByVendorIds(vendorIds)
                .forEach(row -> lastPayMap.put((Long) row[0], (LocalDate) row[1]));

        List<VendorBalanceResponse> result = new ArrayList<>();
        for (Vendor v : vendors) {
            BigDecimal gst        = gstMap.getOrDefault(v.getId(), BigDecimal.ZERO);
            BigDecimal jw         = jwMap.getOrDefault(v.getId(), BigDecimal.ZERO);
            BigDecimal mw         = mwMap.getOrDefault(v.getId(), BigDecimal.ZERO);
            BigDecimal tripDirect = tripDirectMap.getOrDefault(v.getId(), BigDecimal.ZERO);
            BigDecimal received   = paidMap.getOrDefault(v.getId(), BigDecimal.ZERO);
            BigDecimal paidOut    = paidOutMap.getOrDefault(v.getId(), BigDecimal.ZERO);

            LocalDate lastActivity = latestDate(
                    lastGstMap.get(v.getId()),
                    lastJwMap.get(v.getId()),
                    lastMwMap.get(v.getId()),
                    lastTripDirectMap.get(v.getId()),
                    lastPayMap.get(v.getId()));

            VendorBalanceResponse r = new VendorBalanceResponse();
            r.setVendorId(v.getId());
            r.setName(v.getName());
            r.setContact(v.getContact());
            r.setGstin(v.getGstin());
            r.setGstRegistered(v.getGstRegistered());
            r.setIsRegular(v.getIsRegular());
            // outstanding = receivable sources − received payments + paid-out settlements
            r.setOutstanding(gst.add(jw).add(mw).add(tripDirect).subtract(received).add(paidOut));
            r.setLastActivityDate(lastActivity);
            result.add(r);
        }
        return result;
    }

    private static LocalDate latestDate(LocalDate... dates) {
        LocalDate max = null;
        for (LocalDate d : dates) {
            if (d != null && (max == null || d.isAfter(max))) max = d;
        }
        return max;
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
        // Use same formula as LedgerService + getBalances() so the Record Payment modal
        // always shows the same outstanding as the ledger banner for the same party.
        BigDecimal gst        = invoiceRepo.sumAllGrandTotalByVendorId(vendorId);
        BigDecimal jw         = jobWorkRepo.sumAllGrandTotalByVendorId(vendorId);
        BigDecimal mw         = machineWorkRepo.sumAllBillableByCustomerId(vendorId);
        BigDecimal tripDirect = tripRepo.sumAllAutoInvoicedDirectByVendorId(vendorId);
        BigDecimal received   = paymentRepo.sumReceivedByVendorId(vendorId);
        BigDecimal paidOut    = paymentRepo.sumPaidByVendorId(vendorId);
        BigDecimal outstanding = gst.add(jw).add(mw).add(tripDirect).subtract(received).add(paidOut);

        // Trip list is provided for the FIFO allocation preview in the payment form.
        // It reflects actual trips (non-GST direct parties), for other party types
        // the preview may be approximate since invoices are the primary source.
        List<Trip> trips = tripRepo.findByVendorIdAndStatusOrderByTripDateAscIdAsc(vendorId, "ACTIVE");
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
        resp.setTotalBilled(gst.add(jw).add(mw).add(tripDirect));
        resp.setTotalPaid(received.subtract(paidOut));
        resp.setOutstanding(outstanding);
        resp.setTrips(items);
        return resp;
    }

    /** Unsettled transport payables for a party — shown in the PAID payment form. */
    public List<Map<String, Object>> getUnsettledTransportPayables(Long partyId) {
        var payables = transportPayableRepo
                .findByPartyIdAndSettledFalseAndStatusOrderByEntryDateAsc(partyId, "ACTIVE");
        return payables.stream().map(tp -> {
            Map<String, Object> m = new java.util.LinkedHashMap<>();
            m.put("id", tp.getId());
            m.put("entryDate", tp.getEntryDate());
            m.put("vehicleId", tp.getVehicleId());
            String vLabel = "Vehicle";
            if (tp.getVehicleId() != null) {
                vehicleRepo.findById(tp.getVehicleId()).ifPresent(v -> {
                    String label = v.getDisplayName() != null ? v.getDisplayName() : v.getPlateNumber();
                    m.put("vehicleLabel", label);
                });
            }
            if (!m.containsKey("vehicleLabel")) m.put("vehicleLabel", vLabel);
            m.put("sourceType", tp.getSourceType());
            m.put("sourceEntryId", tp.getSourceEntryId());
            return m;
        }).collect(Collectors.toList());
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
