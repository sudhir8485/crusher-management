package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class MaterialRequest {
    @NotBlank private String name;
    private String code;
    private String sizeLabel;
    @NotBlank @Pattern(regexp = "BRASS|TON") private String unit;
    /** Default rate when billing by TON */
    private BigDecimal defaultSaleRate;
    /** Default rate when billing by BRASS */
    private BigDecimal defaultSaleRateBrass;
    /** Default transport rate (₹/km/unit) for auto-filling trip form */
    private BigDecimal defaultTransportRate;
    private BigDecimal kgPerBrass;
}
