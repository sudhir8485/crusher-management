package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDateTime;

@Entity
@Table(name = "vendors")
@Getter @Setter
public class Vendor {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(length = 20)
    private String gstin;

    /** True when this party is GST-registered. Determines invoice type (Tax Invoice vs Delivery Challan). */
    @Column(name = "gst_registered", nullable = false)
    private Boolean gstRegistered = false;

    /**
     * True = Regular customer (appears in Trip quick-select default list).
     * False = Occasional customer (reachable via search in Trip form, but not in the default list).
     * INDEPENDENT of gstRegistered — these are separate, unrelated flags.
     */
    @Column(name = "is_regular", nullable = false)
    private Boolean isRegular = false;

    @Column(length = 100)
    private String contact;

    @Column(columnDefinition = "TEXT")
    private String address;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(name = "is_active", nullable = false)
    private boolean isActive = true;

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
