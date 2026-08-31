package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class EmployeeResponse {
    private Long id;
    private String name;
    private String designation;
    private String wageType;
    private BigDecimal wageRate;
    private String status;
}
