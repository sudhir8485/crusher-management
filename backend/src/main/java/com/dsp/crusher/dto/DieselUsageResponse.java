package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter @Setter
public class DieselUsageResponse {
    private Long id;
    private LocalDate usageDate;
    private Long machineId;
    private String machineName;
    private Long vehicleId;
    private String vehicleDisplayName;
    private String vehiclePlateNumber;
    private BigDecimal quantityLiters;
    private BigDecimal ratePerLiter;
    private BigDecimal dieselValue;        // quantityLiters × ratePerLiter (if both set)
    // Vehicle ownership enrichment (for display and payable feedback)
    private String vehicleOwner;           // TENANT | VENDOR
    private Long vehicleOwnedByPartyId;
    private String vehicleOwnedByPartyName;
    private boolean hasDieselPayable;      // true when a VendorPayment was auto-created
    private String notes;
    private LocalDateTime createdAt;
    private boolean stockWarning;          // true when balance goes negative after this usage
}
