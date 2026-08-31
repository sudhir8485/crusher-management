package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class DieselBalanceResponse {
    private BigDecimal totalReceivedLiters;
    private BigDecimal totalUsedLiters;
    private BigDecimal balanceLiters;
}
