package com.dsp.crusher.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Generic wrapper for all 4 operational reports.
 * Each report type uses a subset of fields.
 */
@Data
public class ReportResponse {

    private String reportType;   // VEHICLE_LOG | MACHINE_WORK | DIESEL | TRIPS
    private LocalDate fromDate;
    private LocalDate toDate;

    // Filter context (whichever was selected)
    private String filterLabel;  // e.g. "MH 47 AS 5199" or "All Vehicles"

    // Summary numbers (filled per report type)
    private Summary summary;

    private List<Row> rows;

    @Data
    public static class Summary {
        private int totalRows;

        // Vehicle log
        private BigDecimal totalKm;
        private int totalTrips;

        // Machine work
        private BigDecimal totalHours;
        private BigDecimal bucketHours;
        private BigDecimal breakerHours;

        // Diesel
        private BigDecimal openingStock;
        private BigDecimal totalReceived;
        private BigDecimal totalUsed;
        private BigDecimal closingStock;

        // Trips / Material
        private int tripCount;
        private BigDecimal totalBrass;
    }

    @Data
    public static class Row {
        private LocalDate date;
        private String col1;   // vehicle / machine / source_or_consumer / vehicle
        private String col2;   // loading location / mode / type / material
        private String col3;   // unloading / description / qty_or_liters / qty_brass
        private String col4;   // km / opening reading / running_stock / vendor
        private String col5;   // day trips / closing reading / amount / challan
        private String col6;   // night trips / total hours / notes / channel
        private String col7;   // diesel notes / — / — / loading location
    }
}
