package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class TripRequest {

    @NotNull
    private LocalDate tripDate;

    // ── Party ─────────────────────────────────────────────────────────────────
    // partyType: "REGULAR" (default) | "ONE_TIME"
    private String partyType = "REGULAR";
    private Long vendorId;                // required when partyType == REGULAR
    private String oneTimeCustomerName;   // required when partyType == ONE_TIME
    private String oneTimeCustomerPhone;
    private String oneTimeCustomerAddr;

    // ── Material & Quantity ───────────────────────────────────────────────────
    @NotNull
    private Long materialId;

    private String quantityUnit = "BRASS"; // BRASS | TON

    private BigDecimal loadedWeightKg;
    private BigDecimal emptyWeightKg;

    // manual quantity entry when weights are absent or BRASS without kgPerBrass
    private BigDecimal billableQuantity;

    private BigDecimal saleRate;

    // ── Vehicle & Transportation ──────────────────────────────────────────────
    // vehicleMode: "COMPANY" (default) | "OWN_VEHICLE"
    private String vehicleMode = "COMPANY";
    private Long vehicleId;              // required when vehicleMode == COMPANY
    private BigDecimal distanceKm;
    private BigDecimal transportRatePerKm;

    // ── Documents & Additional ────────────────────────────────────────────────
    private String dspChallanNo;
    private String vendorChallanNo;
    private String channelNo;
    private String loadingLocation;
    private String unloadingLocation;
    private String notes;

    // ── Legacy (backward compat) ──────────────────────────────────────────────
    private BigDecimal quantityBrass;
    private BigDecimal loadedWeightTon;
    private BigDecimal emptyWeightTon;
}
