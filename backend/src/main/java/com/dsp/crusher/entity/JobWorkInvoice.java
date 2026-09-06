package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

// gst_status values (string, not enum): "PENDING" | "SET"

@Entity
@Table(name = "job_work_invoices")
@Getter @Setter
public class JobWorkInvoice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    /** Party to bill — auto-derived from Site.linkedPartyId on create; never changed independently. */
    @Column(name = "vendor_id", nullable = false)
    private Long vendorId;

    /** Client Site that this job-work was performed at. */
    @Column(name = "site_id", nullable = false)
    private Long siteId;

    @Column(name = "invoice_no", nullable = false, length = 50)
    private String invoiceNo;

    @Column(name = "invoice_date", nullable = false)
    private LocalDate invoiceDate;

    /** Optional billing period — used as the date range for auto-quantity calculation. */
    @Column(name = "period_from")
    private LocalDate periodFrom;

    @Column(name = "period_to")
    private LocalDate periodTo;

    @Column(name = "cgst_rate", nullable = false, precision = 5, scale = 2)
    private BigDecimal cgstRate = BigDecimal.ZERO;

    @Column(name = "sgst_rate", nullable = false, precision = 5, scale = 2)
    private BigDecimal sgstRate = BigDecimal.ZERO;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal subtotal = BigDecimal.ZERO;

    @Column(name = "cgst_amount", nullable = false, precision = 14, scale = 2)
    private BigDecimal cgstAmount = BigDecimal.ZERO;

    @Column(name = "sgst_amount", nullable = false, precision = 14, scale = 2)
    private BigDecimal sgstAmount = BigDecimal.ZERO;

    @Column(name = "grand_total", nullable = false, precision = 14, scale = 2)
    private BigDecimal grandTotal = BigDecimal.ZERO;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    /** PENDING = a line item's service had no configured GST rate at creation time.
     *  SET = rate is locked; no automatic changes ever. */
    @Column(name = "gst_status", nullable = false, length = 20)
    private String gstStatus = "SET";

    @Column(name = "gst_recalculated_by", length = 200)
    private String gstRecalculatedBy;

    @Column(name = "gst_recalculated_at")
    private LocalDateTime gstRecalculatedAt;

    @Column(name = "gst_prev_sgst_rate", precision = 5, scale = 2)
    private BigDecimal gstPrevSgstRate;

    @Column(name = "gst_prev_cgst_rate", precision = 5, scale = 2)
    private BigDecimal gstPrevCgstRate;

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @OneToMany(mappedBy = "invoice", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("id ASC")
    private List<JobWorkInvoiceItem> items = new ArrayList<>();
}
