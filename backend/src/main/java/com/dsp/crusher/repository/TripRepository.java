package com.dsp.crusher.repository;

import com.dsp.crusher.entity.Trip;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface TripRepository extends JpaRepository<Trip, Long> {
    List<Trip> findByStatusOrderByTripDateDescIdDesc(String status);
    List<Trip> findByTripDateAndStatusOrderByIdAsc(LocalDate date, String status);
    List<Trip> findByTripDateBetweenAndStatusOrderByTripDateDescIdDesc(LocalDate from, LocalDate to, String status);

    long countByTripDateAndStatus(LocalDate date, String status);

    @Query("SELECT COALESCE(SUM(t.quantityBrass), 0) FROM Trip t WHERE t.tripDate = :date AND t.status = 'ACTIVE'")
    BigDecimal sumBrassByDate(@Param("date") LocalDate date);

    @Query("SELECT COALESCE(SUM(t.quantityBrass), 0) FROM Trip t WHERE t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE'")
    BigDecimal sumBrassByDateRange(@Param("from") LocalDate from, @Param("to") LocalDate to);

    @Query("SELECT t.materialId, COUNT(t), COALESCE(SUM(t.quantityBrass), 0) FROM Trip t WHERE t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' GROUP BY t.materialId")
    List<Object[]> summarizeByMaterial(@Param("from") LocalDate from, @Param("to") LocalDate to);

    // for reports — ASC order, with optional filters
    List<Trip> findByTripDateBetweenAndStatusOrderByTripDateAscIdAsc(LocalDate from, LocalDate to, String status);

    List<Trip> findByVehicleIdAndTripDateBetweenAndStatusOrderByTripDateAscIdAsc(Long vehicleId, LocalDate from, LocalDate to, String status);

    List<Trip> findByMaterialIdAndTripDateBetweenAndStatusOrderByTripDateAscIdAsc(Long materialId, LocalDate from, LocalDate to, String status);

    List<Trip> findByVendorIdAndTripDateBetweenAndStatusOrderByTripDateAscIdAsc(Long vendorId, LocalDate from, LocalDate to, String status);

    // Site-aware queries (siteId IS NULL → all sites for admin)
    @Query("SELECT t FROM Trip t WHERE t.tripDate = :date AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId) ORDER BY t.id ASC")
    List<Trip> findByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    @Query("SELECT t FROM Trip t WHERE t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId) ORDER BY t.tripDate DESC, t.id DESC")
    List<Trip> findByDateRangeAndSite(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT t FROM Trip t WHERE t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId) ORDER BY t.tripDate ASC, t.id ASC")
    List<Trip> findByDateRangeAndSiteAsc(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT t FROM Trip t WHERE t.vehicleId = :vehicleId AND t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId) ORDER BY t.tripDate ASC, t.id ASC")
    List<Trip> findByVehicleIdAndDateRangeAndSite(@Param("vehicleId") Long vehicleId, @Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT t FROM Trip t WHERE t.materialId = :materialId AND t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId) ORDER BY t.tripDate ASC, t.id ASC")
    List<Trip> findByMaterialIdAndDateRangeAndSite(@Param("materialId") Long materialId, @Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT t FROM Trip t WHERE t.vendorId = :vendorId AND t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId) ORDER BY t.tripDate ASC, t.id ASC")
    List<Trip> findByVendorIdAndDateRangeAndSite(@Param("vendorId") Long vendorId, @Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT COUNT(t) FROM Trip t WHERE t.tripDate = :date AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId)")
    long countByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    @Query("SELECT COALESCE(SUM(t.quantityBrass), 0) FROM Trip t WHERE t.tripDate = :date AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId)")
    BigDecimal sumBrassByDateAndSite(@Param("date") LocalDate date, @Param("siteId") Long siteId);

    @Query("SELECT t.materialId, COUNT(t), COALESCE(SUM(t.quantityBrass), 0) FROM Trip t WHERE t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' AND (:siteId IS NULL OR t.siteId = :siteId) GROUP BY t.materialId")
    List<Object[]> summarizeByMaterialAndSite(@Param("from") LocalDate from, @Param("to") LocalDate to, @Param("siteId") Long siteId);

    @Query("SELECT t.vendorId, COALESCE(SUM(t.totalBill), 0) FROM Trip t WHERE t.vendorId IN :vendorIds AND t.status = 'ACTIVE' GROUP BY t.vendorId")
    List<Object[]> sumTotalBillByVendorIds(@Param("vendorIds") List<Long> vendorIds);

    @Query("SELECT t.vendorId, MAX(t.tripDate) FROM Trip t WHERE t.vendorId IN :vendorIds AND t.status = 'ACTIVE' GROUP BY t.vendorId")
    List<Object[]> lastTripDateByVendorIds(@Param("vendorIds") List<Long> vendorIds);

    List<Trip> findByVendorIdAndStatusOrderByTripDateAscIdAsc(Long vendorId, String status);

    /** Sum of all trip bills for a vendor strictly before 'before' date (for opening balance). */
    @Query("SELECT COALESCE(SUM(t.totalBill), 0) FROM Trip t WHERE t.vendorId = :vendorId AND t.tripDate < :before AND t.status = 'ACTIVE'")
    BigDecimal sumTotalBillByVendorIdBefore(@Param("vendorId") Long vendorId, @Param("before") LocalDate before);

    /** All active trips at a specific site in a date range — for auto-qty calculation in Job-Work invoices. */
    @Query("SELECT t FROM Trip t WHERE t.siteId = :siteId AND t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' ORDER BY t.tripDate ASC, t.id ASC")
    List<Trip> findBySiteAndDateRange(@Param("siteId") Long siteId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    /** Unbilled trips: excludes those already linked in trip_jw_billing for this service.
     *  When excludeInvoiceId is non-null (edit mode), records linked to THAT invoice are treated as available. */
    @Query("SELECT t FROM Trip t WHERE t.siteId = :siteId AND t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' " +
           "AND t.id NOT IN (" +
           "  SELECT b.tripId FROM TripJwBilling b WHERE b.serviceId = :serviceId " +
           "  AND (:excludeInvoiceId IS NULL OR b.jobWorkInvoiceId <> :excludeInvoiceId)" +
           ") ORDER BY t.tripDate ASC, t.id ASC")
    List<Trip> findUnbilledBySiteAndDateRange(
            @Param("siteId") Long siteId,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to,
            @Param("serviceId") Long serviceId,
            @Param("excludeInvoiceId") Long excludeInvoiceId);

    /** Already-billed trips at a site in date range for a service. */
    @Query("SELECT t FROM Trip t WHERE t.siteId = :siteId AND t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' " +
           "AND t.id IN (SELECT b.tripId FROM TripJwBilling b WHERE b.serviceId = :serviceId) " +
           "ORDER BY t.tripDate ASC, t.id ASC")
    List<Trip> findBilledBySiteAndDateRange(
            @Param("siteId") Long siteId,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to,
            @Param("serviceId") Long serviceId);

    // ── Auto-invoiced direct debit queries (non-GST parties, V30+) ──────────

    /** Ledger: direct debit entries for non-GST parties after auto-invoice logic ran. */
    @Query("SELECT t FROM Trip t WHERE t.vendorId = :vendorId AND t.autoInvoiced = true AND t.gstInvoiceId IS NULL AND t.totalBill > 0 AND t.tripDate BETWEEN :from AND :to AND t.status = 'ACTIVE' ORDER BY t.tripDate ASC, t.id ASC")
    List<Trip> findAutoInvoicedDirectByVendorAndDateRange(@Param("vendorId") Long vendorId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    /** Ledger: opening balance contribution for non-GST direct trips before a date. */
    @Query("SELECT COALESCE(SUM(t.totalBill), 0) FROM Trip t WHERE t.vendorId = :vendorId AND t.autoInvoiced = true AND t.gstInvoiceId IS NULL AND t.totalBill > 0 AND t.tripDate < :before AND t.status = 'ACTIVE'")
    BigDecimal sumAutoInvoicedDirectByVendorBefore(@Param("vendorId") Long vendorId, @Param("before") LocalDate before);

    /** Accounts list: batch outstanding for non-GST direct trips per vendor. */
    @Query("SELECT t.vendorId, COALESCE(SUM(t.totalBill), 0) FROM Trip t WHERE t.vendorId IN :vendorIds AND t.autoInvoiced = true AND t.gstInvoiceId IS NULL AND t.totalBill > 0 AND t.status = 'ACTIVE' GROUP BY t.vendorId")
    List<Object[]> sumAutoInvoicedDirectByVendorIds(@Param("vendorIds") List<Long> vendorIds);

    /** Accounts list: last activity date for non-GST direct trips per vendor. */
    @Query("SELECT t.vendorId, MAX(t.tripDate) FROM Trip t WHERE t.vendorId IN :vendorIds AND t.autoInvoiced = true AND t.gstInvoiceId IS NULL AND t.status = 'ACTIVE' GROUP BY t.vendorId")
    List<Object[]> lastAutoInvoicedDirectDateByVendorIds(@Param("vendorIds") List<Long> vendorIds);

    // Reference-check for delete guard
    boolean existsByVehicleId(Long vehicleId);
    boolean existsByVendorId(Long vendorId);
}
