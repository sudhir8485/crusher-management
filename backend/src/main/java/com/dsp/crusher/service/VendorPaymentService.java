package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.PageResponse;
import com.dsp.crusher.repository.UserRepository;
import com.dsp.crusher.dto.VendorPaymentRequest;
import com.dsp.crusher.dto.VendorPaymentResponse;
import com.dsp.crusher.entity.GstInvoice;
import com.dsp.crusher.entity.TransportPayable;
import com.dsp.crusher.entity.Trip;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.entity.VendorPayment;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.GstInvoiceRepository;
import com.dsp.crusher.repository.MaterialRepository;
import com.dsp.crusher.repository.TransportPayableRepository;
import com.dsp.crusher.repository.TripRepository;
import com.dsp.crusher.repository.VendorPaymentRepository;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class VendorPaymentService {

    private final VendorPaymentRepository repo;
    private final VendorRepository vendorRepo;
    private final GstInvoiceRepository invoiceRepo;
    private final TripRepository tripRepo;
    private final MaterialRepository materialRepo;
    private final TransportPayableRepository transportPayableRepo;
    private final UserRepository userRepo;

    public PageResponse<VendorPaymentResponse> list(Long vendorId, LocalDate from, LocalDate to, int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<VendorPayment> paymentPage;
        if (vendorId != null)
            paymentPage = repo.findByVendorIdAndStatusOrderByPaymentDateDescIdDesc(vendorId, "ACTIVE", pageable);
        else if (from != null && to != null)
            paymentPage = repo.findByPaymentDateBetweenAndStatusOrderByPaymentDateDescIdDesc(from, to, "ACTIVE", pageable);
        else
            paymentPage = repo.findByStatusOrderByPaymentDateDescIdDesc("ACTIVE", pageable);
        return PageResponse.of(paymentPage, enrich(paymentPage.getContent()));
    }

    public VendorPaymentResponse get(Long id) {
        VendorPayment p = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("VendorPayment not found: " + id));
        return enrich(List.of(p)).get(0);
    }

    @Transactional
    public VendorPaymentResponse create(VendorPaymentRequest req) {
        VendorPayment p = new VendorPayment();
        p.setTenantId(TenantContext.get());
        apply(p, req);
        p.setCreatedByName(getCurrentUserName());
        p.setAllocationSummary(computeAllocationSummary(req.getVendorId(), req.getAmount()));
        return enrich(List.of(repo.save(p))).get(0);
    }

    @Transactional
    public VendorPaymentResponse update(Long id, VendorPaymentRequest req) {
        VendorPayment p = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("VendorPayment not found: " + id));
        apply(p, req);
        p.setUpdatedByName(getCurrentUserName());
        return enrich(List.of(repo.save(p))).get(0);
    }

    @Transactional
    public void deactivate(Long id) {
        VendorPayment p = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("VendorPayment not found: " + id));
        p.setStatus("INACTIVE");
        repo.save(p);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    public List<VendorPaymentResponse> listByInvoice(Long invoiceId) {
        return enrich(repo.findByInvoiceIdAndStatusOrderByPaymentDateAscIdAsc(invoiceId, "ACTIVE"));
    }

    private void apply(VendorPayment p, VendorPaymentRequest req) {
        if (req.getAmount() == null || req.getAmount().compareTo(java.math.BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Payment amount must be greater than zero");
        }
        if (req.getInvoiceId() != null) {
            GstInvoice inv = invoiceRepo.findById(req.getInvoiceId())
                    .orElseThrow(() -> new IllegalArgumentException("Invoice not found: " + req.getInvoiceId()));
            if (!inv.getVendorId().equals(req.getVendorId())) {
                throw new IllegalArgumentException("Invoice " + req.getInvoiceId() + " does not belong to the selected vendor");
            }
        }
        // Validate and settle transport payable when direction=PAID
        if (req.getTransportPayableId() != null) {
            TransportPayable tp = transportPayableRepo.findById(req.getTransportPayableId())
                    .orElseThrow(() -> new IllegalArgumentException("Transport payable not found: " + req.getTransportPayableId()));
            if (!tp.getPartyId().equals(req.getVendorId())) {
                throw new IllegalArgumentException("Transport payable does not belong to the selected party");
            }
            if (tp.isSettled()) {
                throw new IllegalArgumentException("Transport payable " + req.getTransportPayableId() + " is already settled");
            }
            tp.setAmount(req.getAmount());
            tp.setSettled(true);
            transportPayableRepo.save(tp);
        }
        p.setVendorId(req.getVendorId());
        p.setPaymentDate(req.getPaymentDate());
        p.setAmount(req.getAmount());
        p.setPaymentMode(req.getPaymentMode() != null ? req.getPaymentMode() : "CASH");
        p.setReferenceNo(req.getReferenceNo());
        p.setNotes(req.getNotes());
        p.setInvoiceId(req.getInvoiceId());
        p.setDirection(req.getDirection() != null ? req.getDirection() : "RECEIVED");
        p.setTransportPayableId(req.getTransportPayableId());
    }

    private List<VendorPaymentResponse> enrich(List<VendorPayment> rows) {
        List<Long> vendorIds = rows.stream()
                .map(VendorPayment::getVendorId).distinct().collect(Collectors.toList());
        Map<Long, Vendor> vendors = vendorRepo.findAllById(vendorIds).stream()
                .collect(Collectors.toMap(Vendor::getId, v -> v));

        List<Long> invoiceIds = rows.stream()
                .map(VendorPayment::getInvoiceId).filter(id -> id != null)
                .distinct().collect(Collectors.toList());
        Map<Long, GstInvoice> invoices = invoiceIds.isEmpty() ? Map.of()
                : invoiceRepo.findAllById(invoiceIds).stream()
                        .collect(Collectors.toMap(GstInvoice::getId, i -> i));

        return rows.stream().map(p -> {
            VendorPaymentResponse r = new VendorPaymentResponse();
            r.setId(p.getId());
            r.setVendorId(p.getVendorId());
            r.setInvoiceId(p.getInvoiceId());
            r.setPaymentDate(p.getPaymentDate());
            r.setAmount(p.getAmount());
            r.setPaymentMode(p.getPaymentMode());
            r.setReferenceNo(p.getReferenceNo());
            r.setNotes(p.getNotes());
            r.setStatus(p.getStatus());
            Vendor v = vendors.get(p.getVendorId());
            if (v != null) r.setVendorName(v.getName());
            if (p.getInvoiceId() != null) {
                GstInvoice inv = invoices.get(p.getInvoiceId());
                if (inv != null) r.setInvoiceNo(inv.getInvoiceNo());
            }
            r.setAllocationSummary(p.getAllocationSummary());
            r.setDirection(p.getDirection() != null ? p.getDirection() : "RECEIVED");
            r.setTransportPayableId(p.getTransportPayableId());
            r.setCreatedAt(p.getCreatedAt());
            r.setCreatedByName(p.getCreatedByName());
            r.setUpdatedByName(p.getUpdatedByName());
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

    // ── FIFO allocation summary ───────────────────────────────────────────────

    private String computeAllocationSummary(Long vendorId, BigDecimal paymentAmount) {
        if (vendorId == null || paymentAmount == null) return null;

        List<Trip> trips = tripRepo.findByVendorIdAndStatusOrderByTripDateAscIdAsc(vendorId, "ACTIVE");
        if (trips.isEmpty()) return "Unallocated — Advance";

        // Total paid BEFORE this payment (existing payments)
        BigDecimal alreadyPaid = repo.sumByVendorId(vendorId);

        Map<Long, String> matNames = materialRepo.findAll().stream()
                .collect(Collectors.toMap(m -> m.getId(), m -> m.getName()));

        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("d MMM");
        List<String> lines = new ArrayList<>();
        BigDecimal remaining = paymentAmount;
        BigDecimal cumulativeBilled = BigDecimal.ZERO;
        BigDecimal cumulativeCovered = alreadyPaid; // how much already covered by prior payments

        for (Trip t : trips) {
            BigDecimal bill = t.getTotalBill() != null ? t.getTotalBill() : BigDecimal.ZERO;
            if (bill.compareTo(BigDecimal.ZERO) == 0) continue;
            cumulativeBilled = cumulativeBilled.add(bill);

            // How much of this trip was already paid before this payment
            BigDecimal prevCovered = cumulativeCovered.min(cumulativeBilled);
            BigDecimal alreadySettled = prevCovered.subtract(cumulativeBilled.subtract(bill)).max(BigDecimal.ZERO);
            BigDecimal tripDue = bill.subtract(alreadySettled);
            if (tripDue.compareTo(BigDecimal.ZERO) <= 0) continue; // fully covered by earlier payments

            if (remaining.compareTo(BigDecimal.ZERO) <= 0) break;

            String matName = t.getMaterialId() != null ? matNames.getOrDefault(t.getMaterialId(), "—") : "—";
            String dateStr = t.getTripDate().format(fmt);

            if (remaining.compareTo(tripDue) >= 0) {
                lines.add(dateStr + " — " + matName + " ₹" + tripDue.stripTrailingZeros().toPlainString() + " → Paid in full");
                remaining = remaining.subtract(tripDue);
            } else {
                BigDecimal stillDue = tripDue.subtract(remaining);
                lines.add(dateStr + " — " + matName + " ₹" + tripDue.stripTrailingZeros().toPlainString() + " → Partial (₹" + stillDue.stripTrailingZeros().toPlainString() + " still due)");
                remaining = BigDecimal.ZERO;
            }
        }

        if (remaining.compareTo(BigDecimal.ZERO) > 0) {
            if (lines.isEmpty()) {
                return "Unallocated — Advance ₹" + remaining.stripTrailingZeros().toPlainString();
            }
            lines.add("Remaining ₹" + remaining.stripTrailingZeros().toPlainString() + " held as Advance");
        }

        return lines.isEmpty() ? "Unallocated — Advance" : String.join("\n", lines);
    }
}
