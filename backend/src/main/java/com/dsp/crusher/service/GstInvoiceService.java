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
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class GstInvoiceService {

    private final GstInvoiceRepository invoiceRepo;
    private final VendorRepository     vendorRepo;
    private final VendorPaymentRepository paymentRepo;
    private final MaterialRepository        materialRepo;
    private final ServiceRepository         serviceRepo;
    private final UserRepository            userRepo;
    private final InvoiceNumberingService   numbering;

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
        inv.setCreatedByName(getCurrentUserName());
        return enrich(List.of(invoiceRepo.save(inv))).get(0);
    }

    @Transactional
    public GstInvoiceResponse update(Long id, GstInvoiceRequest req) {
        GstInvoice inv = invoiceRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Invoice not found: " + id));
        inv.getItems().clear();
        apply(inv, req);
        inv.setUpdatedByName(getCurrentUserName());
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

        if (req.getItems() == null || req.getItems().isEmpty()) {
            throw new IllegalArgumentException("Invoice must have at least one line item");
        }

        boolean anyPending = false;
        BigDecimal firstItemGstRate = null;

        for (GstInvoiceItemRequest ir : req.getItems()) {
            if (ir.getAmount() == null || ir.getAmount().compareTo(BigDecimal.ZERO) <= 0)
                throw new IllegalArgumentException("Each line item amount must be greater than zero");
            if (ir.getQuantityBrass() != null && ir.getQuantityBrass().compareTo(BigDecimal.ZERO) < 0)
                throw new IllegalArgumentException("Quantity cannot be negative");
            if (ir.getRate() != null && ir.getRate().compareTo(BigDecimal.ZERO) < 0)
                throw new IllegalArgumentException("Rate cannot be negative");
            if (ir.getGstRate() != null && ir.getGstRate().compareTo(BigDecimal.ZERO) < 0)
                throw new IllegalArgumentException("GST rate cannot be negative");

            GstInvoiceItem item = new GstInvoiceItem();
            item.setInvoice(inv);
            item.setDescription(ir.getDescription());
            item.setHsn(ir.getHsn());
            item.setQuantityBrass(ir.getQuantityBrass());
            item.setRate(ir.getRate());
            item.setAmount(ir.getAmount());
            item.setMaterialId(ir.getMaterialId());
            item.setServiceId(ir.getServiceId());
            item.setGstRate(ir.getGstRate()); // null = PENDING for this item
            inv.getItems().add(item);

            if (ir.getGstRate() == null) {
                anyPending = true;
            } else if (firstItemGstRate == null) {
                firstItemGstRate = ir.getGstRate();
            }
        }

        // Invoice-level CGST/SGST rate: first non-null item's rate ÷ 2 (for PDF display)
        BigDecimal halfRate = firstItemGstRate != null
                ? firstItemGstRate.divide(new BigDecimal("2"), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
        inv.setCgstRate(halfRate);
        inv.setSgstRate(halfRate);

        // Subtotal = sum of all item amounts
        BigDecimal subtotal = inv.getItems().stream()
                .map(GstInvoiceItem::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        // Per-item GST amounts summed for invoice totals (items with null gstRate = 0 tax)
        BigDecimal cgstAmt = BigDecimal.ZERO;
        for (GstInvoiceItem item : inv.getItems()) {
            if (item.getGstRate() != null) {
                BigDecimal half = item.getGstRate().divide(new BigDecimal("2"), 4, RoundingMode.HALF_UP);
                cgstAmt = cgstAmt.add(
                        item.getAmount().multiply(half).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP));
            }
        }
        BigDecimal sgstAmt = cgstAmt; // always 50/50

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

        // Batch-load material and service masters for the mismatch indicator
        Set<Long> materialIds = rows.stream().flatMap(inv -> inv.getItems().stream())
                .map(GstInvoiceItem::getMaterialId).filter(Objects::nonNull).collect(Collectors.toSet());
        Set<Long> serviceIds = rows.stream().flatMap(inv -> inv.getItems().stream())
                .map(GstInvoiceItem::getServiceId).filter(Objects::nonNull).collect(Collectors.toSet());
        Map<Long, Material> materials = materialIds.isEmpty() ? Map.of()
                : materialRepo.findAllById(materialIds).stream()
                        .collect(Collectors.toMap(Material::getId, m -> m));
        Map<Long, ServiceRecord> services = serviceIds.isEmpty() ? Map.of()
                : serviceRepo.findAllById(serviceIds).stream()
                        .collect(Collectors.toMap(ServiceRecord::getId, s -> s));

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
            r.setCreatedAt(inv.getCreatedAt());
            r.setCreatedByName(inv.getCreatedByName());
            r.setUpdatedByName(inv.getUpdatedByName());

            Vendor v = vendors.get(inv.getVendorId());
            if (v != null) {
                r.setVendorName(v.getName());
                r.setVendorGstin(v.getGstin());
                r.setVendorAddress(v.getAddress());
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
                ir.setGstRate(item.getGstRate());
                // Master rate (for informational mismatch indicator — only when configured)
                if (item.getMaterialId() != null) {
                    Material m = materials.get(item.getMaterialId());
                    if (m != null && m.isGstRateConfigured()) ir.setMasterGstRate(m.getGstRate());
                }
                if (item.getServiceId() != null) {
                    ServiceRecord s = services.get(item.getServiceId());
                    if (s != null && s.isGstRateConfigured()) ir.setMasterGstRate(s.getGstRate());
                }
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
