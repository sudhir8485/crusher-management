package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class MachineWorkTypeDto {
    private Long id;
    @NotBlank
    private String label;
    private BigDecimal defaultRate;
    private BigDecimal defaultGstRate;
    private String sacCode;
    private int displayOrder;
}
