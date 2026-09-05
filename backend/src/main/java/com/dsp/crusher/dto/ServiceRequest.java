package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class ServiceRequest {
    @NotBlank private String name;
    private String code;
    /** TON | BRASS */
    @NotBlank private String defaultUnit;
    private BigDecimal defaultRate;
    /** GST rate as a whole-number percentage (e.g. 18, 5, 0). */
    private BigDecimal gstRate;
    /** SAC code — Service Accounting Code (equivalent of HSN for goods). */
    private String sacCode;
}
