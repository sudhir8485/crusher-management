package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Getter @Setter
public class DailyReportResponse {

    private LocalDate date;
    private List<TripResponse> trips;
    private List<MaterialSummary> materialSummaries;
    private BigDecimal grandTotalBrass;

    @Getter @Setter
    public static class MaterialSummary {
        private String materialName;
        private BigDecimal totalBrass;
    }
}
