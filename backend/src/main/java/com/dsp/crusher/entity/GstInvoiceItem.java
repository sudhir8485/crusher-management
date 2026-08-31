package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Entity
@Table(name = "gst_invoice_items")
@Getter @Setter
public class GstInvoiceItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "invoice_id", nullable = false)
    private GstInvoice invoice;

    @Column(nullable = false, length = 300)
    private String description;

    @Column(length = 20)
    private String hsn;

    @Column(name = "quantity_brass", precision = 12, scale = 3)
    private BigDecimal quantityBrass;

    @Column(precision = 10, scale = 2)
    private BigDecimal rate;

    @Column(nullable = false, precision = 14, scale = 2)
    private BigDecimal amount;
}
