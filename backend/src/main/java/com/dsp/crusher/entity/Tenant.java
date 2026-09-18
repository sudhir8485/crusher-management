package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDateTime;

@Entity
@Table(name = "tenants")
@Getter @Setter
public class Tenant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(length = 20)
    private String gstin;

    @Column(columnDefinition = "TEXT")
    private String address;

    @Column(length = 50)
    private String phone;

    @Column(length = 200)
    private String email;

    @Column(columnDefinition = "TEXT")
    private String logoBase64;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(length = 200)
    private String bankName;

    @Column(length = 50)
    private String bankAccountNo;

    @Column(length = 20)
    private String bankIfsc;

    @Column(length = 20)
    private String invoicePrefix = "INV";

    @Column(columnDefinition = "TEXT")
    private String invoiceTerms;

    @Column
    private LocalDateTime updatedAt;
}
