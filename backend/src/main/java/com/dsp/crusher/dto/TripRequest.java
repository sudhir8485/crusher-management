package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class TripRequest {
    @NotNull private LocalDate tripDate;
    private String loadingLocation;
    private String unloadingLocation;
    private String channelNo;
    @NotNull private Long materialId;
    private BigDecimal quantityBrass;
    private BigDecimal loadedWeightTon;
    private BigDecimal emptyWeightTon;
    @NotNull private Long vehicleId;
    @NotNull private Long vendorId;
    private String dspChallanNo;
    private String vendorChallanNo;
}
