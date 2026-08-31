package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class VehicleDailyLogRequest {

    @NotNull
    private LocalDate logDate;

    @NotNull
    private Long vehicleId;

    private String loadingLocation;
    private String unloadingLocation;
    private BigDecimal openingReading;
    private BigDecimal closingReading;
    private Integer tripsDay;
    private Integer tripsNight;
    private String dieselNote;
}
