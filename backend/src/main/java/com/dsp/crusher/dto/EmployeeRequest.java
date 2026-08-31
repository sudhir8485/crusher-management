package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class EmployeeRequest {

    @NotBlank
    private String name;

    private String designation;

    private String wageType = "DAILY";  // DAILY | MONTHLY

    private BigDecimal wageRate;
}
