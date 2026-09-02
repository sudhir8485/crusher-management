package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter @Setter
public class TripResponse {

    private Long id;
    private LocalDate tripDate;

    // ── Party ─────────────────────────────────────────────────────────────────
    private String partyType;
    private Long vendorId;
    private String vendorName;
    private String vendorContact;
    private String oneTimeCustomerName;
    private String oneTimeCustomerPhone;
    private String oneTimeCustomerAddr;
    // resolved for UI display regardless of party type
    private String partyDisplayName;
    private String partyPhone;

    // ── Material & Quantity ───────────────────────────────────────────────────
    private Long materialId;
    private String materialName;
    private String quantityUnit;
    private BigDecimal loadedWeightKg;
    private BigDecimal emptyWeightKg;
    private BigDecimal netWeightKg;
    private BigDecimal billableQuantity;
    private BigDecimal saleRate;
    private BigDecimal materialAmount;

    // ── Vehicle & Transportation ──────────────────────────────────────────────
    private String vehicleMode;
    private Long vehicleId;
    private String vehicleDisplayName;
    private String vehiclePlateNumber;
    private BigDecimal distanceKm;
    private BigDecimal transportRatePerKm;
    private BigDecimal transportationCharge;
    private BigDecimal totalBill;

    // ── Documents & Additional ────────────────────────────────────────────────
    private String dspChallanNo;
    private String vendorChallanNo;
    private String channelNo;
    private String loadingLocation;
    private String unloadingLocation;
    private String notes;

    // ── Legacy ────────────────────────────────────────────────────────────────
    private BigDecimal quantityBrass;
    private BigDecimal loadedWeightTon;
    private BigDecimal emptyWeightTon;

    private LocalDateTime createdAt;
}
