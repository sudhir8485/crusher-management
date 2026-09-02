package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "trips")
@Getter @Setter
public class Trip {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(name = "site_id", nullable = false)
    private Long siteId;

    @Column(name = "trip_date", nullable = false)
    private LocalDate tripDate;

    // ── Party / Customer ──────────────────────────────────────────────────────

    @Column(name = "party_type", nullable = false, length = 20)
    private String partyType = "REGULAR"; // REGULAR | ONE_TIME

    @Column(name = "vendor_id")
    private Long vendorId; // null for ONE_TIME

    @Column(name = "one_time_customer_name", length = 200)
    private String oneTimeCustomerName;

    @Column(name = "one_time_customer_phone", length = 50)
    private String oneTimeCustomerPhone;

    @Column(name = "one_time_customer_addr", columnDefinition = "TEXT")
    private String oneTimeCustomerAddr;

    // ── Material & Quantity ───────────────────────────────────────────────────

    @Column(name = "material_id")
    private Long materialId;

    @Column(name = "quantity_unit", nullable = false, length = 10)
    private String quantityUnit = "BRASS"; // BRASS | TON

    @Column(name = "loaded_weight_kg", precision = 12, scale = 2)
    private BigDecimal loadedWeightKg;

    @Column(name = "empty_weight_kg", precision = 12, scale = 2)
    private BigDecimal emptyWeightKg;

    @Column(name = "net_weight_kg", precision = 12, scale = 2)
    private BigDecimal netWeightKg;

    @Column(name = "billable_quantity", precision = 12, scale = 3)
    private BigDecimal billableQuantity;

    @Column(name = "sale_rate", precision = 10, scale = 2)
    private BigDecimal saleRate;

    @Column(name = "material_amount", precision = 14, scale = 2)
    private BigDecimal materialAmount;

    // ── Vehicle & Transportation ──────────────────────────────────────────────

    @Column(name = "vehicle_mode", nullable = false, length = 20)
    private String vehicleMode = "COMPANY"; // COMPANY | OWN_VEHICLE

    @Column(name = "vehicle_id")
    private Long vehicleId; // null for OWN_VEHICLE

    /** CALCULATE = dist × rate, DIRECT = user-entered total */
    @Column(name = "transport_mode", nullable = false, length = 20)
    private String transportMode = "CALCULATE";

    @Column(name = "distance_km", precision = 8, scale = 2)
    private BigDecimal distanceKm;

    @Column(name = "transport_rate_per_km", precision = 10, scale = 2)
    private BigDecimal transportRatePerKm;

    @Column(name = "transportation_charge", nullable = false, precision = 14, scale = 2)
    private BigDecimal transportationCharge = BigDecimal.ZERO;

    @Column(name = "total_bill", precision = 14, scale = 2)
    private BigDecimal totalBill;

    // ── Documents & Additional ────────────────────────────────────────────────

    @Column(name = "dsp_challan_no", length = 50)
    private String dspChallanNo;

    @Column(name = "vendor_challan_no", length = 50)
    private String vendorChallanNo;

    @Column(name = "channel_no", length = 50)
    private String channelNo;

    @Column(name = "loading_location", length = 300)
    private String loadingLocation;

    @Column(name = "unloading_location", length = 300)
    private String unloadingLocation;

    @Column(columnDefinition = "TEXT")
    private String notes;

    // ── Legacy fields (kept for backward compatibility) ────────────────────────

    @Column(name = "quantity_brass", precision = 10, scale = 3)
    private BigDecimal quantityBrass;

    @Column(name = "loaded_weight_ton", precision = 10, scale = 3)
    private BigDecimal loadedWeightTon;

    @Column(name = "empty_weight_ton", precision = 10, scale = 3)
    private BigDecimal emptyWeightTon;

    // ── Audit ─────────────────────────────────────────────────────────────────

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
