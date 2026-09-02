package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "materials")
@Getter @Setter
public class Material {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "size_label", length = 50)
    private String sizeLabel;

    @Column(length = 50)
    private String code;

    @Column(nullable = false, length = 10)
    private String unit = "BRASS"; // BRASS | TON

    /** Default rate when selling by TON */
    @Column(name = "default_sale_rate", precision = 10, scale = 2)
    private BigDecimal defaultSaleRate;

    /** Default rate when selling by BRASS */
    @Column(name = "default_sale_rate_brass", precision = 10, scale = 2)
    private BigDecimal defaultSaleRateBrass;

    @Column(name = "kg_per_brass", precision = 10, scale = 3)
    private BigDecimal kgPerBrass;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
