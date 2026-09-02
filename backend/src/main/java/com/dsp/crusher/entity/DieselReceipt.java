package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "diesel_receipts")
@Getter @Setter
public class DieselReceipt {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(name = "site_id", nullable = false)
    private Long siteId;

    @Column(name = "receipt_date", nullable = false)
    private LocalDate receiptDate;

    @Column(nullable = false, length = 20)
    private String source;   // PUMP | DIRECT

    @Column(name = "quantity_liters", nullable = false, precision = 10, scale = 2)
    private BigDecimal quantityLiters;

    @Column(name = "rate_per_liter", precision = 10, scale = 2)
    private BigDecimal ratePerLiter;

    @Column(precision = 12, scale = 2)
    private BigDecimal amount;

    @Column(name = "vendor_id")
    private Long vendorId;

    @Column(name = "invoice_no", length = 50)
    private String invoiceNo;

    @Column(length = 500)
    private String notes;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
