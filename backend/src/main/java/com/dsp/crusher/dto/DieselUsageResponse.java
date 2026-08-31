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
    private String notes;
    private LocalDateTime createdAt;
}
