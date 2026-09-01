package com.dsp.crusher.service;

import com.dsp.crusher.dto.VendorLedgerResponse;
import com.dsp.crusher.dto.VendorLedgerResponse.LedgerEntry;
import com.dsp.crusher.entity.GstInvoice;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.entity.VendorPayment;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.GstInvoiceRepository;
import com.dsp.crusher.repository.VendorPaymentRepository;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
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

        // ── Transactions within range ────────────────────────────────────────
        List<GstInvoice> invoices = invoiceRepo
                .findByVendorIdAndInvoiceDateBetweenAndStatusOrderByInvoiceDateAscIdAsc(
                        vendorId, from, to, "ACTIVE");

        List<VendorPayment> payments = paymentRepo
                .findByVendorIdAndPaymentDateBetweenAndStatusOrderByPaymentDateAscIdAsc(
                        vendorId, from, to, "ACTIVE");

        List<LedgerEntry> entries = new ArrayList<>();

        for (GstInvoice inv : invoices) {
            LedgerEntry e = new LedgerEntry();
            e.setDate(inv.getInvoiceDate());
            e.setTxnType("INVOICE");
            e.setReference(inv.getInvoiceNo());
            e.setDescription(inv.getPoNo() != null ? "PO: " + inv.getPoNo() : "GST Invoice");
            e.setDebit(inv.getGrandTotal());
            e.setCredit(null);
            e.setSourceId(inv.getId());
            entries.add(e);
        }

        for (VendorPayment pmt : payments) {
            LedgerEntry e = new LedgerEntry();
            e.setDate(pmt.getPaymentDate());
            e.setTxnType("PAYMENT");
            e.setReference(pmt.getReferenceNo() != null ? pmt.getReferenceNo() : pmt.getPaymentMode());
            e.setDescription(pmt.getNotes() != null ? pmt.getNotes() : "Payment - " + pmt.getPaymentMode());
            e.setDebit(null);
            e.setCredit(pmt.getAmount());
            e.setSourceId(pmt.getId());
            entries.add(e);
        }

        // Sort: by date asc, then invoices before payments on same date
        entries.sort(Comparator
                .comparing(LedgerEntry::getDate)
                .thenComparing(e -> e.getTxnType().equals("INVOICE") ? 0 : 1));

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
