package com.dsp.crusher.repository;

import com.dsp.crusher.entity.DabarJwBilling;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface DabarJwBillingRepository extends JpaRepository<DabarJwBilling, Long> {

    void deleteByJobWorkInvoiceId(Long jobWorkInvoiceId);

    @Query("SELECT b.jobWorkInvoiceId FROM DabarJwBilling b WHERE b.serviceId = :serviceId AND b.dabarEntryId IN :entryIds")
    List<Long> findInvoiceIdsByServiceAndEntryIds(
            @Param("serviceId") Long serviceId,
            @Param("entryIds") List<Long> entryIds);
}
