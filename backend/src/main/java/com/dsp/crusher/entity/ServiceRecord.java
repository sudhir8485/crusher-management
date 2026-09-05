package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "services")
@Getter @Setter
public class ServiceRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(length = 50)
    private String code;

    @Column(name = "default_unit", nullable = false, length = 20)
    private String defaultUnit = "TON";

    @Column(name = "default_rate", precision = 12, scale = 2)
    private BigDecimal defaultRate;

    @Column(name = "gst_rate", precision = 5, scale = 2, nullable = false)
    private BigDecimal gstRate = BigDecimal.ZERO;

    /** TRUE once an admin has explicitly configured a GST rate (even 0%).
     *  FALSE = never configured — job-work invoices for this service are PENDING. */
    @Column(name = "gst_rate_configured", nullable = false)
    private boolean gstRateConfigured = false;

    /** SAC code (Service Accounting Code) — equivalent of HSN for goods. */
    @Column(name = "sac_code", length = 20)
    private String sacCode;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
