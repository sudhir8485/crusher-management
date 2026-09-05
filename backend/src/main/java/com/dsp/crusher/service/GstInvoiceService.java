package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.*;
import com.dsp.crusher.entity.GstInvoice;
import com.dsp.crusher.entity.GstInvoiceItem;
import com.dsp.crusher.entity.Material;
import com.dsp.crusher.entity.ServiceRecord;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.GstInvoiceRepository;
import com.dsp.crusher.repository.MaterialRepository;
import com.dsp.crusher.repository.ServiceRepository;
import com.dsp.crusher.repository.UserRepository;
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
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class GstInvoiceService {

    private final GstInvoiceRepository invoiceRepo;
    private final VendorRepository     vendorRepo;
    private final VendorPaymentRepository paymentRepo;
    private final MaterialRepository   materialRepo;
    private final ServiceRepository    serviceRepo;
    private final UserRepository       userRepo;
    private final InvoiceNumberingService numbering;

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
        inv.setInvoiceNo(numbering.nextInvoiceNo(req.getInvoiceDate()));
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

    /**
     * Explicit Recalculate GST action — only valid when gst_status = PENDING.
     * Pulls each item's current Material or Service GST rate, recomputes totals,
     * locks the invoice as SET, and writes an audit record.
     */
    @Transactional
    public GstInvoiceResponse recalculateGst(Long id) {
        GstInvoice inv = invoiceRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Invoice not found: " + id));

        if (!"PENDING".equals(inv.getGstStatus())) {
            throw new IllegalStateException(
                    "GST is already locked (SET) for invoice " + inv.getInvoiceNo()
                    + ". Recalculate is only available for PENDING invoices.");
        }

        // Pull rate from first configured material item, then fall back to service item
        BigDecimal newGstRate = inv.getItems().stream()
                .filter(i -> i.getMaterialId() != null)
                .map(i -> materialRepo.findById(i.getMaterialId()).orElse(null))
                .filter(m -> m != null)
                .map(Material::getGstRate)
                .findFirst()
                .orElseGet(() -> inv.getItems().stream()
                        .filter(i -> i.getServiceId() != null)
                        .map(i -> serviceRepo.findById(i.getServiceId()).orElse(null))
                        .filter(s -> s != null && s.isGstRateConfigured())
                        .map(ServiceRecord::getGstRate)
                        .findFirst()
                        .orElse(BigDecimal.ZERO));

        BigDecimal newHalf = newGstRate.divide(new BigDecimal("2"), 2, RoundingMode.HALF_UP);

        inv.setGstPrevSgstRate(inv.getSgstRate());
        inv.setGstPrevCgstRate(inv.getCgstRate());
        inv.setGstRecalculatedBy(getCurrentUserName());
        inv.setGstRecalculatedAt(LocalDateTime.now());

        inv.setSgstRate(newHalf);
        inv.setCgstRate(newHalf);

        BigDecimal subtotal = inv.getItems().stream()
                .map(GstInvoiceItem::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal sgstAmt = subtotal.multiply(newHalf).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        BigDecimal cgstAmt = subtotal.multiply(newHalf).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);

        inv.setSubtotal(subtotal);
        inv.setSgstAmount(sgstAmt);
        inv.setCgstAmount(cgstAmt);
        inv.setGrandTotal(subtotal.add(sgstAmt).add(cgstAmt));
        inv.setGstStatus("SET");

        return enrich(List.of(invoiceRepo.save(inv))).get(0);
    }

    /**
     * Set a specific GST rate directly on a PENDING invoice.
     * totalGstRate is the combined rate (e.g. 18 → SGST 9% + CGST 9%). Locks as SET.
     */
    @Transactional
    public GstInvoiceResponse setGstRate(Long id, BigDecimal totalGstRate) {
        GstInvoice inv = invoiceRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Invoice not found: " + id));

        if (!"PENDING".equals(inv.getGstStatus())) {
            throw new IllegalStateException(
                    "GST is already locked (SET) for invoice " + inv.getInvoiceNo()
                    + ". Rate can only be changed on PENDING invoices.");
        }

        BigDecimal half = totalGstRate.divide(new BigDecimal("2"), 2, RoundingMode.HALF_UP);

        inv.setGstPrevSgstRate(inv.getSgstRate());
        inv.setGstPrevCgstRate(inv.getCgstRate());
        inv.setGstRecalculatedBy(getCurrentUserName());
        inv.setGstRecalculatedAt(LocalDateTime.now());

        inv.setSgstRate(half);
        inv.setCgstRate(half);

        BigDecimal subtotal = inv.getItems().stream()
                .map(GstInvoiceItem::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal sgstAmt = subtotal.multiply(half).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        BigDecimal cgstAmt = subtotal.multiply(half).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);

        inv.setSubtotal(subtotal);
        inv.setSgstAmount(sgstAmt);
        inv.setCgstAmount(cgstAmt);
        inv.setGrandTotal(subtotal.add(sgstAmt).add(cgstAmt));
        inv.setGstStatus("SET");

        return enrich(List.of(invoiceRepo.save(inv))).get(0);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private void apply(GstInvoice inv, GstInvoiceRequest req) {
        inv.setVendorId(req.getVendorId());
        inv.setInvoiceDate(req.getInvoiceDate());
        inv.setSupplyDate(req.getSupplyDate());
        inv.setPoNo(req.getPoNo());
        inv.setNotes(req.getNotes());

        if (req.getItems() == null || req.getItems().isEmpty()) {
            throw new IllegalArgumentException("Invoice must have at least one line item");
        }

        boolean anyPending = false;
        for (GstInvoiceItemRequest ir : req.getItems()) {
            if (ir.getAmount() == null || ir.getAmount().compareTo(BigDecimal.ZERO) <= 0)
                throw new IllegalArgumentException("Each line item amount must be greater than zero");
            if (ir.getQuantityBrass() != null && ir.getQuantityBrass().compareTo(BigDecimal.ZERO) < 0)
                throw new IllegalArgumentException("Quantity cannot be negative");
            if (ir.getRate() != null && ir.getRate().compareTo(BigDecimal.ZERO) < 0)
                throw new IllegalArgumentException("Rate cannot be negative");

            GstInvoiceItem item = new GstInvoiceItem();
            item.setInvoice(inv);
            item.setDescription(ir.getDescription());
            item.setHsn(ir.getHsn());
            item.setQuantityBrass(ir.getQuantityBrass());
            item.setRate(ir.getRate());
            item.setAmount(ir.getAmount());
            item.setMaterialId(ir.getMaterialId());
            item.setServiceId(ir.getServiceId());
            inv.getItems().add(item);

            // PENDING if linked to a material without a configured GST rate
            if (ir.getMaterialId() != null) {
                Material mat = materialRepo.findById(ir.getMaterialId()).orElse(null);
                if (mat != null && !mat.isGstRateConfigured()) anyPending = true;
            }
            // PENDING if linked to a service without a configured GST rate
            if (ir.getServiceId() != null) {
                ServiceRecord svc = serviceRepo.findById(ir.getServiceId()).orElse(null);
                if (svc != null && !svc.isGstRateConfigured()) anyPending = true;
            }
        }

        // Rate resolution — explicit > material master > service master > fallback 9%
        BigDecimal cgstRate;
        BigDecimal sgstRate;
        if (req.getCgstRate() != null && req.getSgstRate() != null) {
            cgstRate = req.getCgstRate();
            sgstRate = req.getSgstRate();
        } else {
            BigDecimal fromMaterial = inv.getItems().stream()
                    .filter(i -> i.getMaterialId() != null)
                    .map(i -> materialRepo.findById(i.getMaterialId()).orElse(null))
                    .filter(m -> m != null && m.isGstRateConfigured())
                    .map(Material::getGstRate)
                    .findFirst().orElse(null);

            BigDecimal fromService = fromMaterial == null
                    ? inv.getItems().stream()
                            .filter(i -> i.getServiceId() != null)
                            .map(i -> serviceRepo.findById(i.getServiceId()).orElse(null))
                            .filter(s -> s != null && s.isGstRateConfigured())
                            .map(ServiceRecord::getGstRate)
                            .findFirst().orElse(null)
                    : null;

            BigDecimal resolved = fromMaterial != null ? fromMaterial : fromService;
            if (resolved != null) {
                BigDecimal half = resolved.divide(new BigDecimal("2"), 2, RoundingMode.HALF_UP);
                cgstRate = half;
                sgstRate = half;
            } else {
                // Neither material nor service has a configured rate — use 9% as placeholder
                cgstRate = new BigDecimal("9.00");
                sgstRate = new BigDecimal("9.00");
            }
        }
        inv.setCgstRate(cgstRate);
        inv.setSgstRate(sgstRate);

        BigDecimal subtotal = inv.getItems().stream()
                .map(GstInvoiceItem::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal cgstAmt = subtotal.multiply(cgstRate).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        BigDecimal sgstAmt = subtotal.multiply(sgstRate).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);

        inv.setSubtotal(subtotal);
        inv.setCgstAmount(cgstAmt);
        inv.setSgstAmount(sgstAmt);
        inv.setGrandTotal(subtotal.add(cgstAmt).add(sgstAmt));
        inv.setGstStatus(anyPending ? "PENDING" : "SET");
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
            r.setGstStatus(inv.getGstStatus());
            r.setGstRecalculatedBy(inv.getGstRecalculatedBy());
            r.setGstRecalculatedAt(inv.getGstRecalculatedAt());
            r.setGstPrevSgstRate(inv.getGstPrevSgstRate());
            r.setGstPrevCgstRate(inv.getGstPrevCgstRate());

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
                ir.setMaterialId(item.getMaterialId());
                ir.setServiceId(item.getServiceId());
                return ir;
            }).collect(Collectors.toList()));

            BigDecimal paid = paymentRepo.sumByInvoiceId(inv.getId());
            BigDecimal outstanding = inv.getGrandTotal().subtract(paid);
            r.setTotalPaid(paid);
            r.setOutstandingAmount(outstanding.compareTo(BigDecimal.ZERO) < 0 ? BigDecimal.ZERO : outstanding);
            if (paid.compareTo(BigDecimal.ZERO) == 0)        r.setPaymentStatus("UNPAID");
            else if (outstanding.compareTo(BigDecimal.valueOf(0.01)) > 0) r.setPaymentStatus("PARTIAL");
            else                                               r.setPaymentStatus("PAID");

            return r;
        }).collect(Collectors.toList());
    }
}
