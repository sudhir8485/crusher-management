package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.*;
import com.dsp.crusher.entity.*;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.*;
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
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class JobWorkInvoiceService {

    private final JobWorkInvoiceRepository invoiceRepo;
    private final SiteRepository           siteRepo;
    private final VendorRepository         vendorRepo;
    private final ServiceRepository        serviceRepo;
    private final UserRepository           userRepo;
    private final InvoiceNumberingService  numbering;
    private final TripRepository           tripRepo;
    private final DabarEntryRepository     dabarRepo;
    private final TripJwBillingRepository  tripBillingRepo;
    private final DabarJwBillingRepository dabarBillingRepo;

    public PageResponse<JobWorkInvoiceResponse> list(int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<JobWorkInvoice> p = invoiceRepo.findByStatusOrderByInvoiceDateDescIdDesc("ACTIVE", pageable);
        return PageResponse.of(p, enrich(p.getContent()));
    }

    public JobWorkInvoiceResponse get(Long id) {
        return enrich(List.of(load(id))).get(0);
    }

    @Transactional
    public JobWorkInvoiceResponse create(JobWorkInvoiceRequest req) {
        Site site = siteRepo.findById(req.getSiteId())
                .orElseThrow(() -> new ResourceNotFoundException("Site not found: " + req.getSiteId()));
        if (!"CLIENT_SITE".equals(site.getSiteType())) {
            throw new IllegalArgumentException(
                    "Only Client Sites can be used for Job-Work Invoices. '" + site.getName() + "' is an Own Site.");
        }
        if (site.getLinkedPartyId() == null) {
            throw new IllegalArgumentException(
                    "Site '" + site.getName() + "' has no linked party configured.");
        }

        JobWorkInvoice inv = new JobWorkInvoice();
        inv.setTenantId(TenantContext.get());
        inv.setSiteId(site.getId());
        inv.setVendorId(site.getLinkedPartyId());
        inv.setInvoiceNo(numbering.nextInvoiceNo(req.getInvoiceDate()));
        apply(inv, req);
        inv.setCreatedByName(currentUserName());
        JobWorkInvoice saved = invoiceRepo.save(inv);

        // Mark all auto-calc records as billed by this invoice
        markBillingLinks(saved, req);

        return enrich(List.of(saved)).get(0);
    }

    @Transactional
    public JobWorkInvoiceResponse update(Long id, JobWorkInvoiceRequest req) {
        JobWorkInvoice inv = load(id);

        Site site = siteRepo.findById(req.getSiteId())
                .orElseThrow(() -> new ResourceNotFoundException("Site not found: " + req.getSiteId()));
        if (!"CLIENT_SITE".equals(site.getSiteType())) {
            throw new IllegalArgumentException("Only Client Sites allowed.");
        }
        if (site.getLinkedPartyId() == null) {
            throw new IllegalArgumentException("Site has no linked party.");
        }

        // Release old billing links before re-applying items
        tripBillingRepo.deleteByJobWorkInvoiceId(id);
        dabarBillingRepo.deleteByJobWorkInvoiceId(id);

        inv.setSiteId(site.getId());
        inv.setVendorId(site.getLinkedPartyId());
        inv.getItems().clear();
        apply(inv, req);
        inv.setUpdatedByName(currentUserName());
        JobWorkInvoice saved = invoiceRepo.save(inv);

        // Re-mark billing links with updated period/items
        markBillingLinks(saved, req);

        return enrich(List.of(saved)).get(0);
    }

    @Transactional
    public void deactivate(Long id) {
        JobWorkInvoice inv = load(id);
        // Release billing links so records are available for future invoices
        tripBillingRepo.deleteByJobWorkInvoiceId(id);
        dabarBillingRepo.deleteByJobWorkInvoiceId(id);
        inv.setStatus("INACTIVE");
        invoiceRepo.save(inv);
    }

    // ── Auto-Qty ─────────────────────────────────────────────────────────────────

    /** Compute unbilled auto-quantity for a Job-Work invoice line.
     *  Excludes records already billed by a previous invoice for the same site+service.
     *  Also checks for period overlaps with existing invoices. */
    public AutoQtyResponse calcAutoQty(Long siteId, Long serviceId,
                                        LocalDate from, LocalDate to,
                                        Long excludeInvoiceId) {
        ServiceRecord svc = serviceRepo.findById(serviceId)
                .orElseThrow(() -> new ResourceNotFoundException("Service not found: " + serviceId));
        String source = svc.getAutoCalcSource();
        if ("NONE".equals(source) || source == null) {
            throw new IllegalArgumentException(
                    "Service '" + svc.getName() + "' has no auto-calculate source configured (Manual Entry only).");
        }

        String serviceUnit = svc.getDefaultUnit() != null ? svc.getDefaultUnit() : "BRASS";

        AutoQtyResponse resp = new AutoQtyResponse();
        resp.setSource(source);
        resp.setUnit(serviceUnit);

        if ("TRIP_QUANTITIES".equals(source)) {
            // Unbilled trips — no unit filter; billableQuantity is always set for all trip units.
            // Unit matching was removed because crushers typically use a single unit per site and
            // the service unit may not always match the trip unit after master data changes.
            List<Trip> unbilled = tripRepo.findUnbilledBySiteAndDateRange(siteId, from, to, serviceId, excludeInvoiceId);
            BigDecimal total = unbilled.stream()
                    .map(t -> t.getBillableQuantity() != null ? t.getBillableQuantity() : BigDecimal.ZERO)
                    .reduce(BigDecimal.ZERO, BigDecimal::add)
                    .setScale(3, RoundingMode.HALF_UP);

            List<Map<String, Object>> records = new ArrayList<>();
            for (Trip t : unbilled) {
                Map<String, Object> rec = new LinkedHashMap<>();
                rec.put("id", t.getId());
                rec.put("date", t.getTripDate().toString());
                rec.put("quantity", t.getBillableQuantity() != null ? t.getBillableQuantity() : BigDecimal.ZERO);
                rec.put("unit", t.getQuantityUnit());
                rec.put("vehicleMode", t.getVehicleMode());
                records.add(rec);
            }
            resp.setQuantity(total);
            resp.setCount(unbilled.size());
            resp.setRecords(records);

            // Already-billed in this period
            List<Trip> billed = tripRepo.findBilledBySiteAndDateRange(siteId, from, to, serviceId);
            BigDecimal billedQty = billed.stream()
                    .map(t -> t.getBillableQuantity() != null ? t.getBillableQuantity() : BigDecimal.ZERO)
                    .reduce(BigDecimal.ZERO, BigDecimal::add)
                    .setScale(3, RoundingMode.HALF_UP);
            resp.setBilledCount(billed.size());
            resp.setBilledQuantity(billedQty);
            if (!billed.isEmpty()) {
                List<Long> billedTripIds = billed.stream().map(Trip::getId).collect(Collectors.toList());
                List<Long> invIds = tripBillingRepo.findInvoiceIdsByServiceAndTripIds(serviceId, billedTripIds);
                if (!invIds.isEmpty()) {
                    invoiceRepo.findById(invIds.get(0))
                            .ifPresent(i -> resp.setBilledByInvoiceNo(i.getInvoiceNo()));
                }
            }

        } else { // DABAR_QUANTITIES
            List<DabarEntry> unbilled = dabarRepo.findUnbilledBySiteAndDateRange(siteId, from, to, serviceId, excludeInvoiceId);
            BigDecimal total = unbilled.stream()
                    .map(d -> d.getQuantityBrass() != null ? d.getQuantityBrass() : BigDecimal.ZERO)
                    .reduce(BigDecimal.ZERO, BigDecimal::add)
                    .setScale(3, RoundingMode.HALF_UP);

            List<Map<String, Object>> records = new ArrayList<>();
            for (DabarEntry d : unbilled) {
                Map<String, Object> rec = new LinkedHashMap<>();
                rec.put("id", d.getId());
                rec.put("date", d.getEntryDate().toString());
                rec.put("quantity", d.getQuantityBrass() != null ? d.getQuantityBrass() : BigDecimal.ZERO);
                rec.put("unit", "BRASS");
                if (d.getTripsCount() != null) rec.put("tripsCount", d.getTripsCount());
                records.add(rec);
            }
            resp.setQuantity(total);
            resp.setCount(unbilled.size());
            resp.setRecords(records);

            List<DabarEntry> billed = dabarRepo.findBilledBySiteAndDateRange(siteId, from, to, serviceId);
            BigDecimal billedQty = billed.stream()
                    .map(d -> d.getQuantityBrass() != null ? d.getQuantityBrass() : BigDecimal.ZERO)
                    .reduce(BigDecimal.ZERO, BigDecimal::add)
                    .setScale(3, RoundingMode.HALF_UP);
            resp.setBilledCount(billed.size());
            resp.setBilledQuantity(billedQty);
            if (!billed.isEmpty()) {
                List<Long> billedIds = billed.stream().map(DabarEntry::getId).collect(Collectors.toList());
                List<Long> invIds = dabarBillingRepo.findInvoiceIdsByServiceAndEntryIds(serviceId, billedIds);
                if (!invIds.isEmpty()) {
                    invoiceRepo.findById(invIds.get(0))
                            .ifPresent(i -> resp.setBilledByInvoiceNo(i.getInvoiceNo()));
                }
            }
        }

        // Period overlap check
        List<JobWorkInvoice> overlapping = invoiceRepo.findOverlappingByPeriod(siteId, serviceId, from, to, excludeInvoiceId);
        if (!overlapping.isEmpty()) {
            JobWorkInvoice ov = overlapping.get(0);
            resp.setOverlappingInvoice(new AutoQtyResponse.OverlapInfo(
                    ov.getInvoiceNo(), ov.getPeriodFrom(), ov.getPeriodTo()));
        }

        return resp;
    }

    // ── Billing link management ───────────────────────────────────────────────────

    /** After saving an invoice, mark all auto-calc records in its period as billed. */
    private void markBillingLinks(JobWorkInvoice inv, JobWorkInvoiceRequest req) {
        if (req.getPeriodFrom() == null || req.getPeriodTo() == null) return;

        for (JobWorkInvoiceItem item : inv.getItems()) {
            if (item.getServiceId() == null) continue;
            ServiceRecord svc = serviceRepo.findById(item.getServiceId()).orElse(null);
            if (svc == null || "NONE".equals(svc.getAutoCalcSource()) || svc.getAutoCalcSource() == null) continue;

            if ("TRIP_QUANTITIES".equals(svc.getAutoCalcSource())) {
                List<Trip> toMark = tripRepo.findUnbilledBySiteAndDateRange(
                        inv.getSiteId(), req.getPeriodFrom(), req.getPeriodTo(), item.getServiceId(), null);
                for (Trip t : toMark) {
                    tripBillingRepo.save(new TripJwBilling(t.getId(), item.getServiceId(), inv.getId()));
                }
            } else { // DABAR_QUANTITIES
                List<DabarEntry> toMark = dabarRepo.findUnbilledBySiteAndDateRange(
                        inv.getSiteId(), req.getPeriodFrom(), req.getPeriodTo(), item.getServiceId(), null);
                for (DabarEntry d : toMark) {
                    dabarBillingRepo.save(new DabarJwBilling(d.getId(), item.getServiceId(), inv.getId()));
                }
            }
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────────

    private void apply(JobWorkInvoice inv, JobWorkInvoiceRequest req) {
        inv.setInvoiceDate(req.getInvoiceDate());
        inv.setPeriodFrom(req.getPeriodFrom());
        inv.setPeriodTo(req.getPeriodTo());
        inv.setNotes(req.getNotes());

        if (req.getItems() == null || req.getItems().isEmpty()) {
            throw new IllegalArgumentException("Invoice must have at least one line item");
        }

        boolean anyPending = false;
        BigDecimal firstItemGstRate = null;

        for (JobWorkInvoiceItemRequest ir : req.getItems()) {
            if (ir.getAmount() == null || ir.getAmount().compareTo(BigDecimal.ZERO) <= 0)
                throw new IllegalArgumentException("Each line item amount must be greater than zero");
            if (ir.getDescription() == null || ir.getDescription().isBlank())
                throw new IllegalArgumentException("Each line item must have a description");
            if (ir.getGstRate() != null && ir.getGstRate().compareTo(BigDecimal.ZERO) < 0)
                throw new IllegalArgumentException("GST rate cannot be negative");

            JobWorkInvoiceItem item = new JobWorkInvoiceItem();
            item.setInvoice(inv);
            item.setServiceId(ir.getServiceId());
            item.setDescription(ir.getDescription().trim());
            item.setSacCode(ir.getSacCode());
            item.setQuantity(ir.getQuantity());
            item.setRate(ir.getRate());
            item.setAmount(ir.getAmount());
            item.setGstRate(ir.getGstRate()); // null = PENDING
            inv.getItems().add(item);

            if (ir.getGstRate() == null) {
                anyPending = true;
            } else if (firstItemGstRate == null) {
                firstItemGstRate = ir.getGstRate();
            }
        }

        // Invoice-level rates for PDF display: first non-null item's rate ÷ 2
        BigDecimal halfRate = firstItemGstRate != null
                ? firstItemGstRate.divide(new BigDecimal("2"), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
        inv.setCgstRate(halfRate);
        inv.setSgstRate(halfRate);

        BigDecimal subtotal = inv.getItems().stream()
                .map(JobWorkInvoiceItem::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        // Per-item GST amounts summed (items with null gstRate contribute 0)
        BigDecimal cgstAmt = BigDecimal.ZERO;
        for (JobWorkInvoiceItem item : inv.getItems()) {
            if (item.getGstRate() != null) {
                BigDecimal half = item.getGstRate().divide(new BigDecimal("2"), 4, RoundingMode.HALF_UP);
                cgstAmt = cgstAmt.add(
                        item.getAmount().multiply(half).divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP));
            }
        }
        BigDecimal sgstAmt = cgstAmt;

        inv.setSubtotal(subtotal);
        inv.setCgstAmount(cgstAmt);
        inv.setSgstAmount(sgstAmt);
        inv.setGrandTotal(subtotal.add(cgstAmt).add(sgstAmt));
        inv.setGstStatus(anyPending ? "PENDING" : "SET");
    }

    private String currentUserName() {
        try {
            String principal = SecurityContextHolder.getContext().getAuthentication().getName();
            Long userId = Long.parseLong(principal);
            return userRepo.findById(userId).map(User::getFullName).orElse(principal);
        } catch (Exception e) {
            return null;
        }
    }

    private JobWorkInvoice load(Long id) {
        return invoiceRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Job-Work Invoice not found: " + id));
    }

    private List<JobWorkInvoiceResponse> enrich(List<JobWorkInvoice> rows) {
        List<Long> vendorIds = rows.stream().map(JobWorkInvoice::getVendorId).distinct().collect(Collectors.toList());
        Map<Long, Vendor> vendors = vendorRepo.findAllById(vendorIds).stream()
                .collect(Collectors.toMap(Vendor::getId, v -> v));

        List<Long> siteIds = rows.stream().map(JobWorkInvoice::getSiteId).distinct().collect(Collectors.toList());
        Map<Long, Site> sites = siteRepo.findAllById(siteIds).stream()
                .collect(Collectors.toMap(Site::getId, s -> s));

        // Batch-load service masters for mismatch indicator
        Set<Long> serviceIds = rows.stream().flatMap(inv -> inv.getItems().stream())
                .map(JobWorkInvoiceItem::getServiceId).filter(java.util.Objects::nonNull).collect(java.util.stream.Collectors.toSet());
        Map<Long, ServiceRecord> services = serviceIds.isEmpty() ? Map.of()
                : serviceRepo.findAllById(serviceIds).stream()
                        .collect(Collectors.toMap(ServiceRecord::getId, s -> s));

        return rows.stream().map(inv -> {
            JobWorkInvoiceResponse r = new JobWorkInvoiceResponse();
            r.setId(inv.getId());
            r.setVendorId(inv.getVendorId());
            r.setSiteId(inv.getSiteId());
            r.setInvoiceNo(inv.getInvoiceNo());
            r.setInvoiceDate(inv.getInvoiceDate());
            r.setPeriodFrom(inv.getPeriodFrom());
            r.setPeriodTo(inv.getPeriodTo());
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
            if (v != null) { r.setVendorName(v.getName()); r.setVendorGstin(v.getGstin()); r.setVendorAddress(v.getAddress()); }

            Site s = sites.get(inv.getSiteId());
            if (s != null) r.setSiteName(s.getName());

            r.setItems(inv.getItems().stream().map(item -> {
                JobWorkInvoiceItemResponse ir = new JobWorkInvoiceItemResponse();
                ir.setId(item.getId());
                ir.setServiceId(item.getServiceId());
                ir.setDescription(item.getDescription());
                ir.setSacCode(item.getSacCode());
                ir.setQuantity(item.getQuantity());
                ir.setRate(item.getRate());
                ir.setAmount(item.getAmount());
                ir.setGstRate(item.getGstRate());
                if (item.getServiceId() != null) {
                    ServiceRecord svc = services.get(item.getServiceId());
                    if (svc != null && svc.isGstRateConfigured()) ir.setMasterGstRate(svc.getGstRate());
                }
                return ir;
            }).collect(Collectors.toList()));

            return r;
        }).collect(Collectors.toList());
    }
}
