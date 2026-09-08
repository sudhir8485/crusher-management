package com.dsp.crusher.service;

import com.dsp.crusher.dto.VendorLedgerResponse;
import com.dsp.crusher.dto.VendorLedgerResponse.DetailLine;
import com.dsp.crusher.dto.VendorLedgerResponse.LedgerEntry;
import com.dsp.crusher.entity.GstInvoice;
import com.dsp.crusher.entity.GstInvoiceItem;
import com.dsp.crusher.entity.JobWorkInvoice;
import com.dsp.crusher.entity.JobWorkInvoiceItem;
import com.dsp.crusher.entity.Machine;
import com.dsp.crusher.entity.MachineWorkLog;
import com.dsp.crusher.entity.Material;
import com.dsp.crusher.entity.TransportPayable;
import com.dsp.crusher.entity.Trip;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.entity.Vehicle;
import com.dsp.crusher.entity.VendorPayment;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.GstInvoiceRepository;
import com.dsp.crusher.repository.JobWorkInvoiceRepository;
import com.dsp.crusher.repository.MachineRepository;
import com.dsp.crusher.repository.MachineWorkLogRepository;
import com.dsp.crusher.repository.MaterialRepository;
import com.dsp.crusher.repository.TransportPayableRepository;
import com.dsp.crusher.repository.TripRepository;
import com.dsp.crusher.repository.VehicleRepository;
import com.dsp.crusher.repository.VendorPaymentRepository;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class LedgerService {

    private final VendorRepository            vendorRepo;
    private final GstInvoiceRepository        invoiceRepo;
    private final VendorPaymentRepository     paymentRepo;
    private final MachineWorkLogRepository    machineWorkRepo;
    private final MachineRepository           machineRepo;
    private final JobWorkInvoiceRepository    jobWorkInvoiceRepo;
    private final TransportPayableRepository  transportPayableRepo;
    private final VehicleRepository           vehicleRepo;
    private final TripRepository              tripRepo;
    private final MaterialRepository          materialRepo;

    public VendorLedgerResponse vendorLedger(Long vendorId, LocalDate from, LocalDate to) {

        Vendor vendor = vendorRepo.findById(vendorId)
                .orElseThrow(() -> new ResourceNotFoundException("Vendor not found: " + vendorId));

        // ── Opening balance: (invoices + job-work + machine work SET + direct trips) − payments before 'from' ─
        BigDecimal openingDebit  = invoiceRepo.sumGrandTotalByVendorBefore(vendorId, from);
        BigDecimal openingJw     = jobWorkInvoiceRepo.sumGrandTotalByVendorBefore(vendorId, from);
        BigDecimal openingMw     = machineWorkRepo.sumTotalAmountByCustomerBefore(vendorId, from);
        BigDecimal openingTrip   = tripRepo.sumAutoInvoicedDirectByVendorBefore(vendorId, from);
        BigDecimal openingCredit = paymentRepo.sumAmountByVendorBefore(vendorId, from);
        BigDecimal openingBalance = openingDebit.add(openingJw).add(openingMw).add(openingTrip).subtract(openingCredit);

        // ── Invoices within range ────────────────────────────────────────────
        List<GstInvoice> invoices = invoiceRepo.findWithItemsByVendorAndDateRange(vendorId, from, to);

        // ── Payments within range ────────────────────────────────────────────
        List<VendorPayment> payments = paymentRepo
                .findByVendorIdAndPaymentDateBetweenAndStatusOrderByPaymentDateAscIdAsc(
                        vendorId, from, to, "ACTIVE");

        // ── Job-work invoices within range ───────────────────────────────────
        List<JobWorkInvoice> jobWorkInvoices =
                jobWorkInvoiceRepo.findWithItemsByVendorAndDateRange(vendorId, from, to);

        // ── Customer Billable machine work within range ──────────────────────
        List<MachineWorkLog> machineWork =
                machineWorkRepo.findBillableByCustomerAndDateRange(vendorId, from, to);

        // Load machine names for machine work entries
        List<Long> machineIds = machineWork.stream()
                .map(MachineWorkLog::getMachineId).distinct().collect(Collectors.toList());
        Map<Long, Machine> machineMap = machineIds.isEmpty() ? Map.of() :
                machineRepo.findAllById(machineIds).stream()
                        .collect(Collectors.toMap(Machine::getId, m -> m));

        List<LedgerEntry> entries = new ArrayList<>();

        // ── Build machine work entries FIRST so that after the UI reversal
        //    (newest-first display) the GST invoice cards appear above flat
        //    MachineWork cards within the same date. ────────────────────────
        for (MachineWorkLog mwl : machineWork) {
            LedgerEntry e = new LedgerEntry();
            e.setDate(mwl.getLogDate());
            e.setVoucherType("MachineWork");
            e.setSourceId(mwl.getId());
            e.setGstStatus(mwl.getRateStatus());
            e.setTotalHours(mwl.getTotalHours());

            Machine machine = machineMap.get(mwl.getMachineId());
            String machineName = machine != null ? machine.getName() : "Machine";
            String desc = mwl.getWorkDescription();
            e.setParticulars(machineName + (desc != null && !desc.isBlank() ? " — " + desc : ""));

            if ("SET".equals(mwl.getRateStatus()) && mwl.getTotalAmount() != null) {
                e.setDebit(mwl.getTotalAmount());
            }

            List<DetailLine> details = new ArrayList<>();
            if ("PENDING".equals(mwl.getRateStatus())) {
                DetailLine pd = new DetailLine();
                pd.setLabel("Rate: Pending — tap to set rate");
                pd.setAmount(null);
                details.add(pd);
            } else if (mwl.getRate() != null && mwl.getTotalHours() != null) {
                DetailLine rd = new DetailLine();
                rd.setLabel("₹" + mwl.getRate().stripTrailingZeros().toPlainString()
                        + "/hr × " + mwl.getTotalHours().stripTrailingZeros().toPlainString() + " hrs");
                rd.setAmount(mwl.getTotalAmount());
                details.add(rd);
            }
            e.setDetails(details);
            entries.add(e);
        }

        // ── Build invoice entries ────────────────────────────────────────────
        for (GstInvoice inv : invoices) {
            LedgerEntry e = new LedgerEntry();
            e.setDate(inv.getInvoiceDate());
            e.setParticulars("To (as per details)");
            e.setVoucherType("Sales");
            e.setInvoiceNo(inv.getInvoiceNo());
            e.setDebit(inv.getGrandTotal());
            e.setSourceId(inv.getId());
            e.setGstStatus(inv.getGstStatus());

            List<DetailLine> details = new ArrayList<>();
            boolean isPending = "PENDING".equals(inv.getGstStatus());
            boolean hasTax    = inv.getSgstAmount().compareTo(BigDecimal.ZERO) != 0
                             || inv.getCgstAmount().compareTo(BigDecimal.ZERO) != 0;

            for (GstInvoiceItem item : inv.getItems()) {
                if (hasTax && !isPending) {
                    DetailLine ref = new DetailLine();
                    ref.setLabel(item.getDescription());
                    ref.setAmount(null);
                    details.add(ref);
                    DetailLine sales = new DetailLine();
                    sales.setLabel("Sales");
                    sales.setAmount(item.getAmount());
                    details.add(sales);
                } else {
                    DetailLine d = new DetailLine();
                    d.setLabel(item.getDescription());
                    d.setAmount(item.getAmount());
                    details.add(d);
                }
            }

            if (isPending) {
                DetailLine pending = new DetailLine();
                pending.setLabel("GST: Pending — use Recalculate GST to apply current rate");
                pending.setAmount(null);
                details.add(pending);
            } else {
                if (inv.getSgstAmount().compareTo(BigDecimal.ZERO) != 0) {
                    DetailLine sgst = new DetailLine();
                    sgst.setLabel("SGST " + inv.getSgstRate().stripTrailingZeros().toPlainString() + "%");
                    sgst.setAmount(inv.getSgstAmount());
                    details.add(sgst);
                }
                if (inv.getCgstAmount().compareTo(BigDecimal.ZERO) != 0) {
                    DetailLine cgst = new DetailLine();
                    cgst.setLabel("CGST " + inv.getCgstRate().stripTrailingZeros().toPlainString() + "%");
                    cgst.setAmount(inv.getCgstAmount());
                    details.add(cgst);
                }
                BigDecimal computed = inv.getSubtotal().add(inv.getSgstAmount()).add(inv.getCgstAmount());
                BigDecimal roundOff = inv.getGrandTotal().subtract(computed).setScale(2, RoundingMode.HALF_UP);
                DetailLine ro = new DetailLine();
                ro.setLabel("Round Off");
                ro.setAmount(roundOff);
                details.add(ro);
            }

            e.setDetails(details);
            entries.add(e);
        }

        // ── Build job-work invoice entries ───────────────────────────────────
        for (JobWorkInvoice inv : jobWorkInvoices) {
            LedgerEntry e = new LedgerEntry();
            e.setDate(inv.getInvoiceDate());
            e.setParticulars("To (as per details)");
            e.setVoucherType("JobWork");
            e.setInvoiceNo(inv.getInvoiceNo());
            e.setDebit(inv.getGrandTotal());
            e.setSourceId(inv.getId());
            e.setGstStatus(inv.getGstStatus());

            List<DetailLine> details = new ArrayList<>();
            boolean isPending = "PENDING".equals(inv.getGstStatus());
            boolean hasTax = inv.getSgstAmount().compareTo(BigDecimal.ZERO) != 0
                          || inv.getCgstAmount().compareTo(BigDecimal.ZERO) != 0;

            for (JobWorkInvoiceItem item : inv.getItems()) {
                if (hasTax && !isPending) {
                    DetailLine ref = new DetailLine();
                    ref.setLabel(item.getDescription());
                    ref.setAmount(null);
                    details.add(ref);
                    DetailLine sales = new DetailLine();
                    sales.setLabel("Amount");
                    sales.setAmount(item.getAmount());
                    details.add(sales);
                } else {
                    DetailLine d = new DetailLine();
                    d.setLabel(item.getDescription());
                    d.setAmount(item.getAmount());
                    details.add(d);
                }
            }

            if (isPending) {
                DetailLine pd = new DetailLine();
                pd.setLabel("GST: Pending — use Recalculate GST to apply current rate");
                pd.setAmount(null);
                details.add(pd);
            } else {
                if (inv.getSgstAmount().compareTo(BigDecimal.ZERO) != 0) {
                    DetailLine sgst = new DetailLine();
                    sgst.setLabel("SGST " + inv.getSgstRate().stripTrailingZeros().toPlainString() + "%");
                    sgst.setAmount(inv.getSgstAmount());
                    details.add(sgst);
                }
                if (inv.getCgstAmount().compareTo(BigDecimal.ZERO) != 0) {
                    DetailLine cgst = new DetailLine();
                    cgst.setLabel("CGST " + inv.getCgstRate().stripTrailingZeros().toPlainString() + "%");
                    cgst.setAmount(inv.getCgstAmount());
                    details.add(cgst);
                }
                BigDecimal computed = inv.getSubtotal().add(inv.getSgstAmount()).add(inv.getCgstAmount());
                BigDecimal roundOff = inv.getGrandTotal().subtract(computed).setScale(2, RoundingMode.HALF_UP);
                DetailLine ro = new DetailLine();
                ro.setLabel("Round Off");
                ro.setAmount(roundOff);
                details.add(ro);
            }

            e.setDetails(details);
            entries.add(e);
        }

        // ── Build direct trip debit entries (non-GST parties, auto_invoiced=true, V30+) ─
        List<Trip> directTrips = tripRepo.findAutoInvoicedDirectByVendorAndDateRange(vendorId, from, to);

        // Pre-load material names for direct trips
        List<Long> directTripMatIds = directTrips.stream()
                .filter(t -> t.getMaterialId() != null)
                .map(Trip::getMaterialId).distinct().collect(Collectors.toList());
        Map<Long, Material> directTripMaterials = directTripMatIds.isEmpty() ? Map.of() :
                materialRepo.findAllById(directTripMatIds).stream()
                        .collect(Collectors.toMap(Material::getId, m -> m));

        for (Trip trip : directTrips) {
            LedgerEntry e = new LedgerEntry();
            e.setDate(trip.getTripDate());
            e.setVoucherType("Delivery");
            e.setSourceId(trip.getId());
            e.setDebit(trip.getTotalBill());

            Material tripMat = trip.getMaterialId() != null
                    ? directTripMaterials.get(trip.getMaterialId()) : null;
            String matName = tripMat != null ? tripMat.getName() : null;
            e.setParticulars(trip.isMaterialSuppressed() || matName == null
                    ? "Transport Charges" : matName);

            List<DetailLine> details = new ArrayList<>();
            boolean hasMat = !trip.isMaterialSuppressed()
                    && trip.getMaterialAmount() != null
                    && trip.getMaterialAmount().compareTo(BigDecimal.ZERO) > 0;
            boolean hasTrans = trip.getTransportationCharge() != null
                    && trip.getTransportationCharge().compareTo(BigDecimal.ZERO) > 0;

            if (hasMat) {
                DetailLine d = new DetailLine();
                d.setLabel(matName + (trip.getBillableQuantity() != null
                        ? " — " + trip.getBillableQuantity().stripTrailingZeros().toPlainString()
                          + " " + trip.getQuantityUnit() : ""));
                d.setAmount(trip.getMaterialAmount());
                details.add(d);
            }
            if (hasTrans) {
                DetailLine d = new DetailLine();
                d.setLabel("Transport");
                d.setAmount(trip.getTransportationCharge());
                details.add(d);
            }
            e.setDetails(details);
            entries.add(e);
        }

        // ── Build transport payable entries (Dabar) ──────────────────────────
        List<TransportPayable> transportPayables =
                transportPayableRepo.findByPartyIdAndEntryDateBetweenAndStatus(vendorId, from, to, "ACTIVE");

        // Pre-load vehicles for display names
        List<Long> vehicleIds = transportPayables.stream()
                .map(TransportPayable::getVehicleId).distinct().collect(Collectors.toList());
        Map<Long, Vehicle> vehicleMap = vehicleIds.isEmpty() ? Map.of() :
                vehicleRepo.findAllById(vehicleIds).stream()
                        .collect(Collectors.toMap(Vehicle::getId, v -> v));

        for (TransportPayable tp : transportPayables) {
            LedgerEntry e = new LedgerEntry();
            e.setDate(tp.getEntryDate());
            e.setVoucherType("TransportPayable");
            e.setSourceId(tp.getId());
            e.setGstStatus("PENDING"); // no amount set yet — shown as pending

            String vehicleLabel = "Vehicle";
            if (tp.getVehicleId() != null) {
                Vehicle v = vehicleMap.get(tp.getVehicleId());
                if (v != null) vehicleLabel = v.getDisplayName() != null ? v.getDisplayName() : v.getPlateNumber();
            }
            e.setParticulars("Dabar Transport — " + vehicleLabel);

            // No debit/credit until rate is set — tracking entry only
            DetailLine pending = new DetailLine();
            pending.setLabel("Payable: Pending — rate not set");
            pending.setAmount(null);
            e.setDetails(List.of(pending));
            entries.add(e);
        }

        // ── Build payment entries ────────────────────────────────────────────
        for (VendorPayment pmt : payments) {
            LedgerEntry e = new LedgerEntry();
            e.setDate(pmt.getPaymentDate());
            String particulars = switch (pmt.getPaymentMode()) {
                case "DIESEL_ADVANCE"    -> "Diesel Advance";
                case "DIESEL_CREDIT"     -> "Diesel Credit";
                case "TRANSPORT_CREDIT"  -> "Transport (Vehicle Hire)";
                default -> {
                    String base = "By " + pmt.getPaymentMode();
                    yield (pmt.getReferenceNo() != null && !pmt.getReferenceNo().isBlank())
                            ? base + " – " + pmt.getReferenceNo() : base;
                }
            };
            e.setParticulars(particulars);
            e.setVoucherType("Receipt");
            e.setCredit(pmt.getAmount());
            e.setSourceId(pmt.getId());
            e.setDetails(List.of());
            entries.add(e);
        }

        // Sort: date asc, receipts last on same date
        entries.sort(Comparator
                .comparing(LedgerEntry::getDate)
                .thenComparing(e -> "Receipt".equals(e.getVoucherType()) ? 1 : 0));

        // ── Running balance ──────────────────────────────────────────────────
        BigDecimal running     = openingBalance;
        BigDecimal totalDebit  = BigDecimal.ZERO;
        BigDecimal totalCredit = BigDecimal.ZERO;

        for (LedgerEntry e : entries) {
            if (e.getDebit() != null) {
                running    = running.add(e.getDebit());
                totalDebit = totalDebit.add(e.getDebit());
            }
            if (e.getCredit() != null) {
                running     = running.subtract(e.getCredit());
                totalCredit = totalCredit.add(e.getCredit());
            }
            e.setRunningBalance(running);
        }

        VendorLedgerResponse res = new VendorLedgerResponse();
        res.setVendorId(vendorId);
        res.setVendorName(vendor.getName());
        res.setFromDate(from);
        res.setToDate(to);
        res.setOpeningBalance(openingBalance);
        res.setTotalDebit(totalDebit);
        res.setTotalCredit(totalCredit);
        res.setClosingBalance(openingBalance.add(totalDebit).subtract(totalCredit));
        res.setEntries(entries);
        return res;
    }
}
