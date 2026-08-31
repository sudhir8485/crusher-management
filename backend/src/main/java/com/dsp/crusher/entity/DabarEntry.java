package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "dabar_entries")
@Getter @Setter
public class DabarEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(name = "entry_date", nullable = false)
    private LocalDate entryDate;

    @Column(name = "vehicle_id")
    private Long vehicleId;

    @Column(name = "vendor_id")
    private Long vendorId;

    @Column(name = "trips_count")
    private Integer tripsCount;

    @Column(name = "quantity_brass", precision = 10, scale = 3)
    private BigDecimal quantityBrass;

    @Column(length = 500)
    private String notes;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
