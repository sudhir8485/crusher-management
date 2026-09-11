package com.dsp.crusher.repository;

import com.dsp.crusher.entity.TransportPayable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface TransportPayableRepository extends JpaRepository<TransportPayable, Long> {

    Optional<TransportPayable> findBySourceTypeAndSourceEntryIdAndStatus(
            String sourceType, Long sourceEntryId, String status);

    List<TransportPayable> findByPartyIdAndEntryDateBetweenAndStatus(
            Long partyId, LocalDate from, LocalDate to, String status);

    @Query("SELECT COUNT(p) FROM TransportPayable p WHERE p.partyId = :partyId AND p.entryDate < :before AND p.status = 'ACTIVE'")
    long countActiveByPartyBefore(@Param("partyId") Long partyId, @Param("before") LocalDate before);

    // Unsettled payables for a party — shown in the payment form for PAID direction
    List<TransportPayable> findByPartyIdAndSettledFalseAndStatusOrderByEntryDateAsc(
            Long partyId, String status);
}
