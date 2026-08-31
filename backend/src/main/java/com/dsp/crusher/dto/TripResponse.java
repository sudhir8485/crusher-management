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
    private String loadingLocation;
    private String unloadingLocation;
    private String channelNo;
    private Long materialId;
    private String materialName;
    private BigDecimal quantityBrass;
    private BigDecimal loadedWeightTon;
    private BigDecimal emptyWeightTon;
    private Long vehicleId;
    private String vehicleDisplayName;
    private String vehiclePlateNumber;
    private Long vendorId;
    private String vendorName;
    private String dspChallanNo;
    private String vendorChallanNo;
    private LocalDateTime createdAt;
}
