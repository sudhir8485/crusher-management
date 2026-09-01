package com.dsp.crusher.service;

import com.dsp.crusher.dto.VendorLedgerResponse;
import com.dsp.crusher.dto.VendorLedgerResponse.DetailLine;
import com.dsp.crusher.dto.VendorLedgerResponse.LedgerEntry;
import com.dsp.crusher.entity.GstInvoice;
import com.dsp.crusher.entity.GstInvoiceItem;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.entity.VendorPayment;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.GstInvoiceRepository;
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

@Service
@RequiredArgsConstructor
public class LedgerService {

    private final VendorRepository vendorRepo;
    private final GstInvoiceRepository invoiceRepo;
    private final VendorPaymentRepository paymentRepo;

    public VendorLedgerResponse vendorLedger(Long vendorId, LocalDate from, LocalDate to) {

        Vendor vendor = vendorRepo.findById(vendorId)
                .orElseThrow(() -> new ResourceNotFoundException("Vendor not found: " + vendorId));

        // ── Opening balance: invoices - payments before 'from' date ─────────
        BigDecimal openingDebit  = invoiceRepo.sumGrandTotalByVendorBefore(vendorId, from);
        BigDecimal openingCredit = paymentRepo.sumAmountByVendorBefore(vendorId, from);
        BigDecimal openingBalance = openingDebit.subtract(openingCredit);

        // ── Invoices within range (with items eagerly loaded) ────────────────
        List<GstInvoice> invoices = invoiceRepo.findWithItemsByVendorAndDateRange(vendorId, from, to);

        // ── Payments within range ────────────────────────────────────────────
        List<VendorPayment> payments = paymentRepo
                .findByVendorIdAndPaymentDateBetweenAndStatusOrderByPaymentDateAscIdAsc(
                        vendorId, from, to, "ACTIVE");

        List<LedgerEntry> entries = new ArrayList<>();

        for (GstInvoice inv : invoices) {
            LedgerEntry e = new LedgerEntry();
            e.setDate(inv.getInvoiceDate());
            e.setParticulars("To (as per details)");
            e.setVoucherType("Sales");
            e.setInvoiceNo(inv.getInvoiceNo());
            e.setDebit(inv.getGrandTotal());
            e.setSourceId(inv.getId());

            // Build breakdown detail lines
            List<DetailLine> details = new ArrayList<>();
            for (GstInvoiceItem item : inv.getItems()) {
                DetailLine d = new DetailLine();
                d.setLabel(item.getDescription());
                d.setAmount(item.getAmount());
                details.add(d);
            }
            // SGST / CGST lines
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
            // Round Off = grandTotal - subtotal - sgst - cgst
            BigDecimal computed = inv.getSubtotal().add(inv.getSgstAmount()).add(inv.getCgstAmount());
            BigDecimal roundOff = inv.getGrandTotal().subtract(computed).setScale(2, RoundingMode.HALF_UP);
            DetailLine ro = new DetailLine();
            ro.setLabel("Round Off");
            ro.setAmount(roundOff);
            details.add(ro);

            e.setDetails(details);
            entries.add(e);
        }

        for (VendorPayment pmt : payments) {
            LedgerEntry e = new LedgerEntry();
            e.setDate(pmt.getPaymentDate());
            String particulars = "By " + pmt.getPaymentMode();
            if (pmt.getReferenceNo() != null && !pmt.getReferenceNo().isBlank()) {
                particulars += " – " + pmt.getReferenceNo();
            }
            e.setParticulars(particulars);
            e.setVoucherType("Receipt");
            e.setCredit(pmt.getAmount());
            e.setSourceId(pmt.getId());
            e.setDetails(List.of());
            entries.add(e);
        }

        // Sort: date asc, then invoices before payments on same date
        entries.sort(Comparator
                .comparing(LedgerEntry::getDate)
                .thenComparing(e -> "Receipt".equals(e.getVoucherType()) ? 1 : 0));

        // ── Calculate running balance ─────────────────────────────────────────
        BigDecimal running = openingBalance;
        BigDecimal totalDebit  = BigDecimal.ZERO;
        BigDecimal totalCredit = BigDecimal.ZERO;

        for (LedgerEntry e : entries) {
            if (e.getDebit() != null) {
                running = running.add(e.getDebit());
                totalDebit = totalDebit.add(e.getDebit());
            }
            if (e.getCredit() != null) {
                running = running.subtract(e.getCredit());
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
