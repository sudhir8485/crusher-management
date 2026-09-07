package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Tracks outgoing transportation payables owed to external vehicle owners.
 * source_type='DABAR' links to dabar_entries.id.
 * source_type='MACHINE_WORK' (future) would link to machine_work_logs.id.
 * Use this single table — do not create a separate payable table for other sources.
 */
@Entity
@Table(name = "transport_payables")
@Getter @Setter
public class TransportPayable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(name = "site_id", nullable = false)
    private Long siteId;

    @Column(name = "entry_date", nullable = false)
    private LocalDate entryDate;

    @Column(name = "source_type", nullable = false, length = 30)
    private String sourceType = "DABAR";

    @Column(name = "source_entry_id", nullable = false)
    private Long sourceEntryId;

    @Column(name = "vehicle_id")
    private Long vehicleId;

    @Column(name = "party_id", nullable = false)
    private Long partyId;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
