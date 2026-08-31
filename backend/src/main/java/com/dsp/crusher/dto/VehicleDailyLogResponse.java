package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class VehicleDailyLogResponse {
    private Long id;
    private LocalDate logDate;
    private Long vehicleId;
    private String vehicleDisplayName;
    private String vehiclePlateNumber;
    private String loadingLocation;
    private String unloadingLocation;
    private BigDecimal openingReading;
    private BigDecimal closingReading;
    private BigDecimal totalKm;
    private Integer tripsDay;
    private Integer tripsNight;
    private Integer totalTrips;
    private String dieselNote;
    private String status;
}
