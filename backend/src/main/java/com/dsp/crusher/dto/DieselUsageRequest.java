package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class DieselUsageRequest {
    @NotNull private LocalDate usageDate;
    private Long machineId;
    private Long vehicleId;
    @NotNull private BigDecimal quantityLiters;
    private String notes;
}
