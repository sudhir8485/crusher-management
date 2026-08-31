package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class DabarEntryRequest {
    @NotNull private LocalDate entryDate;
    @NotNull private Long vehicleId;
    private Long vendorId;
    private Integer tripsCount;
    private BigDecimal quantityBrass;
    private String notes;
}
