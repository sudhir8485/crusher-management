package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class MaterialRequest {
    @NotBlank private String name;
    private String sizeLabel;
    @NotBlank @Pattern(regexp = "BRASS|TON") private String unit;
    private BigDecimal defaultSaleRate;
    private BigDecimal kgPerBrass;
}
