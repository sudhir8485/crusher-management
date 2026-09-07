package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter @Setter
public class DabarEntryResponse {
    private Long id;
    private LocalDate entryDate;
    private Long vehicleId;
    private String vehicleDisplayName;
    private String vehiclePlateNumber;
    private String vehicleOwner;           // TENANT | VENDOR
    private Long vehicleOwnedByPartyId;    // null for TENANT vehicles
    private String vehicleOwnedByPartyName;// null for TENANT vehicles
    private Long vendorId;
    private String vendorName;
    private Integer tripsCount;
    private BigDecimal quantityBrass;
    private String notes;
    private LocalDateTime createdAt;

    /** ID of the active transport payable for this entry, or null if no payable. */
    private Long transportPayableId;
    /** True when transport payable tracking is active for this entry. */
    private Boolean transportPayableActive;
}
