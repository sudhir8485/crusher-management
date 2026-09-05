package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "machine_work_logs")
@Getter @Setter
public class MachineWorkLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(name = "site_id", nullable = false)
    private Long siteId;

    @Column(name = "log_date", nullable = false)
    private LocalDate logDate;

    @Column(name = "machine_id", nullable = false)
    private Long machineId;

    @Column(name = "work_description", length = 500)
    private String workDescription;

    @Column(nullable = false, length = 20)
    private String mode = "BUCKET";

    @Column(name = "opening_reading", precision = 10, scale = 2)
    private BigDecimal openingReading;

    @Column(name = "closing_reading", precision = 10, scale = 2)
    private BigDecimal closingReading;

    @Column(name = "total_hours", precision = 8, scale = 2)
    private BigDecimal totalHours;

    @Column(length = 500)
    private String notes;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    // ── Customer Billable fields ──────────────────────────────────────────────

    @Column(name = "work_purpose", nullable = false, length = 20)
    private String workPurpose = "INTERNAL";   // INTERNAL | CUSTOMER_BILLABLE

    @Column(name = "customer_id")
    private Long customerId;

    @Column(precision = 12, scale = 2)
    private BigDecimal rate;

    @Column(name = "rate_status", length = 20)
    private String rateStatus;   // PENDING | SET (null for INTERNAL)

    @Column(name = "total_amount", precision = 14, scale = 2)
    private BigDecimal totalAmount;

    @Column(name = "rate_set_by", length = 200)
    private String rateSetBy;

    @Column(name = "rate_set_at")
    private LocalDateTime rateSetAt;

    @Column(name = "rate_prev", precision = 12, scale = 2)
    private BigDecimal ratePrev;

    /** FK to the auto-generated GST invoice for this entry (null for INTERNAL or non-GST parties). */
    @Column(name = "gst_invoice_id")
    private Long gstInvoiceId;
}
