package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Getter @Setter
public class VendorTripBalanceResponse {

    private BigDecimal totalBilled;
    private BigDecimal totalPaid;
    private BigDecimal outstanding; // positive = owed; negative = advance/overpaid

    private List<TripItem> trips;

    @Getter @Setter
    public static class TripItem {
        private Long id;
        private LocalDate tripDate;
        private String materialName;
        private BigDecimal totalBill;
    }
}
