package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.*;
import com.dsp.crusher.entity.GstInvoice;
import com.dsp.crusher.entity.GstInvoiceItem;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.GstInvoiceRepository;
import com.dsp.crusher.repository.VendorPaymentRepository;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class GstInvoiceService {

    private final GstInvoiceRepository invoiceRepo;
    private final VendorRepository vendorRepo;
    private final VendorPaymentRepository paymentRepo;

    public PageResponse<GstInvoiceResponse> list(Long vendorId, LocalDate from, LocalDate to, int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<GstInvoice> invoicePage;
        if (vendorId != null)
            invoicePage = invoiceRepo.findByVendorIdAndStatusOrderByInvoiceDateDescIdDesc(vendorId, "ACTIVE", pageable);
        else if (from != null && to != null)
            invoicePage = invoiceRepo.findByInvoiceDateBetweenAndStatusOrderByInvoiceDateDescIdDesc(from, to, "ACTIVE", pageable);
        else
            invoicePage = invoiceRepo.findByStatusOrderByInvoiceDateDescIdDesc("ACTIVE", pageable);
        return PageResponse.of(invoicePage, enrich(invoicePage.getContent()));
    }

    public GstInvoiceResponse get(Long id) {
        GstInvoice inv = invoiceRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Invoice not found: " + id));
        return enrich(List.of(inv)).get(0);
    }

    @Transactional
    public GstInvoiceResponse create(GstInvoiceRequest req) {
        GstInvoice inv = new GstInvoice();
        inv.setTenantId(TenantContext.get());
        inv.setInvoiceNo(nextInvoiceNo(req.getInvoiceDate()));
        apply(inv, req);
        return enrich(List.of(invoiceRepo.save(inv))).get(0);
    }

    @Transactional
    public GstInvoiceResponse update(Long id, GstInvoiceRequest req) {
        GstInvoice inv = invoiceRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Invoice not found: " + id));
        inv.getItems().clear();
        apply(inv, req);
        return enrich(List.of(invoiceRepo.save(inv))).get(0);
    }

    @Transactional
    public void deactivate(Long id) {
        GstInvoice inv = invoiceRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Invoice not found: " + id));
        inv.setStatus("INACTIVE");
        invoiceRepo.save(inv);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private void apply(GstInvoice inv, GstInvoiceRequest req) {
        inv.setVendorId(req.getVendorId());
        inv.setInvoiceDate(req.getInvoiceDate());
        inv.setSupplyDate(req.getSupplyDate());
        inv.setPoNo(req.getPoNo());
        inv.setNotes(req.getNotes());

        BigDecimal cgstRate = req.getCgstRate() != null ? req.getCgstRate() : new BigDecimal("9.00");
        BigDecimal sgstRate = req.getSgstRate() != null ? req.getSgstRate() : new BigDecimal("9.00");
        inv.setCgstRate(cgstRate);
        inv.setSgstRate(sgstRate);

        // Validate and rebuild items
        if (req.getItems() == null || req.getItems().isEmpty()) {
            throw new IllegalArgumentException("Invoice must have at least one line item");
        }
        for (GstInvoiceItemRequest ir : req.getItems()) {
            if (ir.getAmount() == null || ir.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
                throw new IllegalArgumentException("Each line item amount must be greater than zero");
            }
            if (ir.getQuantityBrass() != null && ir.getQuantityBrass().compareTo(BigDecimal.ZERO) < 0) {
                throw new IllegalArgumentException("Quantity cannot be negative");
            }
            if (ir.getRate() != null && ir.getRate().compareTo(BigDecimal.ZERO) < 0) {
                throw new IllegalArgumentException("Rate cannot be negative");
            }
            GstInvoiceItem item = new GstInvoiceItem();
            item.setInvoice(inv);
            item.setDescription(ir.getDescription());
            item.setHsn(ir.getHsn());
            item.setQuantityBrass(ir.getQuantityBrass());
            item.setRate(ir.getRate());
            item.setAmount(ir.getAmount());
            inv.getItems().add(item);
        }

        // Compute totals
        BigDecimal subtotal = inv.getItems().stream()
                .map(GstInvoiceItem::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal cgstAmt = subtotal.multiply(cgstRate)
                .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        BigDecimal sgstAmt = subtotal.multiply(sgstRate)
                .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);

        inv.setSubtotal(subtotal);
        inv.setCgstAmount(cgstAmt);
        inv.setSgstAmount(sgstAmt);
        inv.setGrandTotal(subtotal.add(cgstAmt).add(sgstAmt));
    }

    private String nextInvoiceNo(LocalDate date) {
        int year = date.getMonthValue() >= 4 ? date.getYear() : date.getYear() - 1;
        String fy = year + "-" + String.format("%02d", (year + 1) % 100);
        long count = invoiceRepo.countByTenantIdAndInvoiceNoStartingWith(
                TenantContext.get(), "DSP/" + fy + "/");
        return "DSP/" + fy + "/" + (count + 1);
    }

    private List<GstInvoiceResponse> enrich(List<GstInvoice> rows) {
        List<Long> vendorIds = rows.stream()
                .map(GstInvoice::getVendorId).distinct().collect(Collectors.toList());
        Map<Long, Vendor> vendors = vendorRepo.findAllById(vendorIds).stream()
                .collect(Collectors.toMap(Vendor::getId, v -> v));

        return rows.stream().map(inv -> {
            GstInvoiceResponse r = new GstInvoiceResponse();
            r.setId(inv.getId());
            r.setVendorId(inv.getVendorId());
            r.setInvoiceNo(inv.getInvoiceNo());
            r.setInvoiceDate(inv.getInvoiceDate());
            r.setSupplyDate(inv.getSupplyDate());
            r.setPoNo(inv.getPoNo());
            r.setCgstRate(inv.getCgstRate());
            r.setSgstRate(inv.getSgstRate());
            r.setSubtotal(inv.getSubtotal());
            r.setCgstAmount(inv.getCgstAmount());
            r.setSgstAmount(inv.getSgstAmount());
            r.setGrandTotal(inv.getGrandTotal());
            r.setNotes(inv.getNotes());
            r.setStatus(inv.getStatus());

            Vendor v = vendors.get(inv.getVendorId());
            if (v != null) {
                r.setVendorName(v.getName());
                r.setVendorGstin(v.getGstin());
            }

            r.setItems(inv.getItems().stream().map(item -> {
                GstInvoiceItemResponse ir = new GstInvoiceItemResponse();
                ir.setId(item.getId());
                ir.setDescription(item.getDescription());
                ir.setHsn(item.getHsn());
                ir.setQuantityBrass(item.getQuantityBrass());
                ir.setRate(item.getRate());
                ir.setAmount(item.getAmount());
                return ir;
            }).collect(Collectors.toList()));

            // Payment totals
            BigDecimal paid = paymentRepo.sumByInvoiceId(inv.getId());
            BigDecimal outstanding = inv.getGrandTotal().subtract(paid);
            r.setTotalPaid(paid);
            r.setOutstandingAmount(outstanding.compareTo(BigDecimal.ZERO) < 0 ? BigDecimal.ZERO : outstanding);
            if (paid.compareTo(BigDecimal.ZERO) == 0) {
                r.setPaymentStatus("UNPAID");
            } else if (outstanding.compareTo(BigDecimal.valueOf(0.01)) > 0) {
                r.setPaymentStatus("PARTIAL");
            } else {
                r.setPaymentStatus("PAID");
            }

            return r;
        }).collect(Collectors.toList());
    }
}
