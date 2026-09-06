package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "trip_jw_billing",
    uniqueConstraints = @UniqueConstraint(name = "uq_trip_service_billing",
        columnNames = {"trip_id", "service_id"}))
@Getter @Setter @NoArgsConstructor
public class TripJwBilling {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "trip_id", nullable = false)
    private Long tripId;

    @Column(name = "service_id", nullable = false)
    private Long serviceId;

    @Column(name = "job_work_invoice_id", nullable = false)
    private Long jobWorkInvoiceId;

    public TripJwBilling(Long tripId, Long serviceId, Long jobWorkInvoiceId) {
        this.tripId = tripId;
        this.serviceId = serviceId;
        this.jobWorkInvoiceId = jobWorkInvoiceId;
    }
}
