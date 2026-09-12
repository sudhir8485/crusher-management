package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Getter @Setter
public class SiteStaffDashboardResponse {

    private LocalDate asOf;

    // Today's operational summary
    private int todayTripCount;
    private BigDecimal todayTotalBrass;
    private BigDecimal dieselBalanceLiters;
    private int todayAttendancePresent;
    private int todayAttendanceTotal;
    private BigDecimal todayMachineHours;

    // Needs Attention (operational only — no financial)
    private long ratePendingMachineWorkCount;
    private long unbilledTripsCount;

    // Today's recent trips (up to 5, most recent first)
    private List<RecentTrip> recentTrips;

    @Getter @Setter
    public static class RecentTrip {
        private Long id;
        private String materialName;
        private BigDecimal quantity;
        private String quantityUnit;
        private String partyName;
    }
}
