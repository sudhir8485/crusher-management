package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
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
        r.setContact(v.getContact());
        r.setAddress(v.getAddress());
        r.setStatus(v.getStatus());
        BigDecimal invTotal = invoiceRepo.sumAllGrandTotalByVendorId(v.getId());
        BigDecimal paidTotal = paymentRepo.sumByVendorId(v.getId());
        r.setOutstandingAmount(invTotal.subtract(paidTotal));
        r.setUnpaidInvoiceCount(0); // computed from outstanding; kept for future
        return r;
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

        // Resolve material names in bulk
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
        v.setContact(req.getContact());
        v.setAddress(req.getAddress());
        return repo.save(v);
    }

    @Transactional
    public Vendor update(Long id, VendorRequest req) {
        Vendor v = getById(id);
        v.setName(req.getName());
        v.setGstin(req.getGstin());
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
