package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

// gst_status values (not an enum to stay schema-light): "PENDING" | "SET"

@Entity
@Table(name = "gst_invoices")
@Getter @Setter
public class GstInvoice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(name = "vendor_id", nullable = false)
    private Long vendorId;

    @Column(name = "invoice_no", nullable = false, length = 50)
    private String invoiceNo;

    @Column(name = "invoice_date", nullable = false)
    private LocalDate invoiceDate;

    @Column(name = "supply_date")
    private LocalDate supplyDate;

    @Column(name = "po_no", length = 50)
    private String poNo;

    @Column(name = "cgst_rate", nullable = false, precision = 5, scale = 2)
    private BigDecimal cgstRate = new BigDecimal("9.00");

    @Column(name = "sgst_rate", nullable = false, precision = 5, scale = 2)
    private BigDecimal sgstRate = new BigDecimal("9.00");

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

    /** PENDING = GST rate was 0/unconfigured when raised; explicit Recalculate required.
     *  SET = rate is locked — no automatic changes, ever. */
    @Column(name = "gst_status", nullable = false, length = 10)
    private String gstStatus = "SET";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "created_by_name", length = 200)
    private String createdByName;

    @Column(name = "updated_by_name", length = 200)
    private String updatedByName;

    // ── Recalculate-GST audit (mirrors createdByName/updatedByName on Trip) ──
    @Column(name = "gst_recalculated_by", length = 100)
    private String gstRecalculatedBy;

    @Column(name = "gst_recalculated_at")
    private LocalDateTime gstRecalculatedAt;

    @Column(name = "gst_prev_sgst_rate", precision = 5, scale = 2)
    private BigDecimal gstPrevSgstRate;

    @Column(name = "gst_prev_cgst_rate", precision = 5, scale = 2)
    private BigDecimal gstPrevCgstRate;

    @OneToMany(mappedBy = "invoice", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("id ASC")
    private List<GstInvoiceItem> items = new ArrayList<>();
}
