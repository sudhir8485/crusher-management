package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "trips")
@Getter @Setter
public class Trip {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(name = "site_id", nullable = false)
    private Long siteId;

    @Column(name = "trip_date", nullable = false)
    private LocalDate tripDate;

    @Column(name = "loading_location", length = 300)
    private String loadingLocation;

    @Column(name = "unloading_location", length = 300)
    private String unloadingLocation;

    @Column(name = "channel_no", length = 50)
    private String channelNo;

    @Column(name = "material_id")
    private Long materialId;

    @Column(name = "quantity_brass", precision = 10, scale = 3)
    private BigDecimal quantityBrass;

    @Column(name = "loaded_weight_ton", precision = 10, scale = 3)
    private BigDecimal loadedWeightTon;

    @Column(name = "empty_weight_ton", precision = 10, scale = 3)
    private BigDecimal emptyWeightTon;

    @Column(name = "vehicle_id")
    private Long vehicleId;

    @Column(name = "vendor_id")
    private Long vendorId;

    @Column(name = "dsp_challan_no", length = 50)
    private String dspChallanNo;

    @Column(name = "vendor_challan_no", length = 50)
    private String vendorChallanNo;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
