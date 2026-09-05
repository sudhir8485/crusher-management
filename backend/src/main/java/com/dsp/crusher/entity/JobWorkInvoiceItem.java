package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Entity
@Table(name = "job_work_invoice_items")
@Getter @Setter
public class JobWorkInvoiceItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "invoice_id", nullable = false)
    private JobWorkInvoice invoice;

    /** Optional link to Service Master — used by Recalculate GST to pull current rate. */
    @Column(name = "service_id")
    private Long serviceId;

    /** Snapshot of service name at invoice creation time — immune to Service Master changes. */
    @Column(nullable = false, length = 300)
    private String description;

    @Column(name = "sac_code", length = 20)
    private String sacCode;

    @Column(precision = 12, scale = 3)
    private BigDecimal quantity;

    @Column(precision = 10, scale = 2)
    private BigDecimal rate;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal amount;
}
