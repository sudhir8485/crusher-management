package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.VehicleRequest;
import com.dsp.crusher.dto.VehicleResponse;
import com.dsp.crusher.entity.Machine;
import com.dsp.crusher.entity.Vehicle;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class VehicleService {

    private final VehicleRepository      repo;
    private final MachineRepository      machineRepo;
    private final TripRepository         tripRepo;
    private final DabarEntryRepository   dabarRepo;
    private final DieselUsageRepository  dieselUsageRepo;

    /** Default list — active records only (pickers + master list default). */
    public List<VehicleResponse> listActive() {
        return buildResponses(repo.findByStatusAndIsActiveTrue("ACTIVE"));
    }

    /** All non-deleted records, including is_active=false (admin show-inactive view). */
    public List<VehicleResponse> listAll() {
        return buildResponses(repo.findByStatus("ACTIVE"));
    }

    public VehicleResponse getById(Long id) {
        return buildResponses(List.of(repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Vehicle not found: " + id)))).get(0);
    }

    @Transactional
    public VehicleResponse create(VehicleRequest req) {
        Vehicle v = new Vehicle();
        v.setTenantId(TenantContext.get());
        applyToVehicle(v, req);
        v = repo.save(v);
        syncMachineLink(null, req.getLinkedMachineId(), v.getId());
        return getById(v.getId());
    }

    @Transactional
    public VehicleResponse update(Long id, VehicleRequest req) {
        Vehicle v = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Vehicle not found: " + id));
        Long oldLinkedMachineId = v.getLinkedMachineId();
        applyToVehicle(v, req);
        repo.save(v);
        syncMachineLink(oldLinkedMachineId, req.getLinkedMachineId(), id);
        return getById(id);
    }

    /** Flip is_active — always allowed, no reference checks needed. */
    @Transactional
    public VehicleResponse toggleActive(Long id) {
        Vehicle v = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Vehicle not found: " + id));
        v.setActive(!v.isActive());
        repo.save(v);
        return getById(id);
    }

    /**
     * Permanently soft-delete (status=INACTIVE). Blocked if historical data exists.
     * Suggest Deactivate (toggleActive) instead.
     */
    @Transactional
    public void deactivate(Long id) {
        Vehicle v = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Vehicle not found: " + id));

        // Block if linked to an active machine
        List<Machine> linkedMachines = machineRepo.findByLinkedVehicleIdAndStatus(id, "ACTIVE");
        if (!linkedMachines.isEmpty()) {
            String names = linkedMachines.stream().map(Machine::getName).collect(Collectors.joining(", "));
            throw new IllegalStateException(
                "Vehicle is linked to machine(s): " + names + ". " +
                "Remove the link in Machine settings before deleting.");
        }

        // Block if any historical records reference this vehicle
        if (tripRepo.existsByVehicleId(id) ||
            dabarRepo.existsByVehicleId(id) ||
            dieselUsageRepo.existsByVehicleId(id)) {
            throw new IllegalStateException(
                "This vehicle has historical records (trips, dabar entries, or diesel usage). " +
                "Use the Active/Inactive toggle to hide it instead of deleting.");
        }

        v.setStatus("INACTIVE");
        repo.save(v);
    }

    // ── Machine link sync ────────────────────────────────────────────────────

    public void syncMachineLink(Long oldMachineId, Long newMachineId, Long vehicleId) {
        if (oldMachineId != null && !oldMachineId.equals(newMachineId)) {
            machineRepo.findById(oldMachineId).ifPresent(m -> {
                if (vehicleId.equals(m.getLinkedVehicleId())) {
                    m.setLinkedVehicleId(null);
                    machineRepo.save(m);
                }
            });
        }
        if (newMachineId != null) {
            machineRepo.findById(newMachineId).ifPresent(m -> {
                m.setLinkedVehicleId(vehicleId);
                machineRepo.save(m);
            });
        }
    }

    // ── Response builder ─────────────────────────────────────────────────────

    private List<VehicleResponse> buildResponses(List<Vehicle> vehicles) {
        if (vehicles.isEmpty()) return List.of();
        List<Long> machineIds = vehicles.stream()
                .map(Vehicle::getLinkedMachineId).filter(Objects::nonNull)
                .distinct().collect(Collectors.toList());
        Map<Long, Machine> machinesById = machineIds.isEmpty() ? Map.of() :
                machineRepo.findAllById(machineIds).stream()
                        .collect(Collectors.toMap(Machine::getId, m -> m));

        return vehicles.stream().map(v -> {
            VehicleResponse r = new VehicleResponse();
            r.setId(v.getId());
            r.setTenantId(v.getTenantId());
            r.setOwner(v.getOwner());
            r.setVendorId(v.getVendorId());
            r.setPlateNumber(v.getPlateNumber());
            r.setDisplayName(v.getDisplayName());
            r.setVehicleType(v.getVehicleType());
            r.setStatus(v.getStatus());
            r.setActive(v.isActive());
            r.setLinkedMachineId(v.getLinkedMachineId());
            if (v.getLinkedMachineId() != null) {
                Machine m = machinesById.get(v.getLinkedMachineId());
                if (m != null) r.setLinkedMachineName(m.getName());
            }
            return r;
        }).collect(Collectors.toList());
    }

    private void applyToVehicle(Vehicle v, VehicleRequest req) {
        v.setOwner(req.getOwner());
        v.setVendorId(req.getVendorId());
        v.setPlateNumber(req.getPlateNumber());
        v.setDisplayName(req.getDisplayName());
        v.setVehicleType(req.getVehicleType());
        v.setLinkedMachineId(req.getLinkedMachineId());
    }
}
