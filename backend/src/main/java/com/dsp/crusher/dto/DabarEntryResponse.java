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
    private Long vendorId;
    private String vendorName;
    private Integer tripsCount;
    private BigDecimal quantityBrass;
    private String notes;
    private LocalDateTime createdAt;
}
