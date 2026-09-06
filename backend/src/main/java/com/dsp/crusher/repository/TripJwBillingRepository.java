package com.dsp.crusher.repository;

import com.dsp.crusher.entity.TripJwBilling;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface TripJwBillingRepository extends JpaRepository<TripJwBilling, Long> {

    void deleteByJobWorkInvoiceId(Long jobWorkInvoiceId);

    /** Invoice number that billed a specific trip for a specific service (used for "billed by" info). */
    @Query("SELECT b.jobWorkInvoiceId FROM TripJwBilling b WHERE b.serviceId = :serviceId AND b.tripId IN :tripIds")
    List<Long> findInvoiceIdsByServiceAndTripIds(
            @Param("serviceId") Long serviceId,
            @Param("tripIds") List<Long> tripIds);
}
