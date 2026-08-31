package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "vehicle_daily_logs")
@Getter @Setter
public class VehicleDailyLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(name = "log_date", nullable = false)
    private LocalDate logDate;

    @Column(name = "vehicle_id", nullable = false)
    private Long vehicleId;

    @Column(name = "loading_location", length = 300)
    private String loadingLocation;

    @Column(name = "unloading_location", length = 300)
    private String unloadingLocation;

    @Column(name = "opening_reading", precision = 10, scale = 1)
    private BigDecimal openingReading;

    @Column(name = "closing_reading", precision = 10, scale = 1)
    private BigDecimal closingReading;

    @Column(name = "total_km", precision = 10, scale = 1)
    private BigDecimal totalKm;

    @Column(name = "trips_day", nullable = false)
    private Integer tripsDay = 0;

    @Column(name = "trips_night", nullable = false)
    private Integer tripsNight = 0;

    @Column(name = "total_trips", nullable = false)
    private Integer totalTrips = 0;

    @Column(name = "diesel_note", length = 500)
    private String dieselNote;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
