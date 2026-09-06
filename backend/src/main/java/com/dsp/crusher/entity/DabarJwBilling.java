package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "dabar_jw_billing",
    uniqueConstraints = @UniqueConstraint(name = "uq_dabar_service_billing",
        columnNames = {"dabar_entry_id", "service_id"}))
@Getter @Setter @NoArgsConstructor
public class DabarJwBilling {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "dabar_entry_id", nullable = false)
    private Long dabarEntryId;

    @Column(name = "service_id", nullable = false)
    private Long serviceId;

    @Column(name = "job_work_invoice_id", nullable = false)
    private Long jobWorkInvoiceId;

    public DabarJwBilling(Long dabarEntryId, Long serviceId, Long jobWorkInvoiceId) {
        this.dabarEntryId = dabarEntryId;
        this.serviceId = serviceId;
        this.jobWorkInvoiceId = jobWorkInvoiceId;
    }
}
