package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDateTime;

@Entity
@Table(name = "sites")
@Getter @Setter
public class Site {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String location;

    /** OWN = DSP's own site (internal). CLIENT_SITE = operated for a client party. */
    @Column(name = "site_type", nullable = false, length = 20)
    private String siteType = "OWN";

    /** For CLIENT_SITE only: the vendor/party that owns or contracted this site. */
    @Column(name = "linked_party_id")
    private Long linkedPartyId;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
