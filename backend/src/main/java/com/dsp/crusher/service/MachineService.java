package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.MachineRequest;
import com.dsp.crusher.dto.MachineResponse;
import com.dsp.crusher.dto.MachineWorkTypeDto;
import com.dsp.crusher.entity.Machine;
import com.dsp.crusher.entity.MachineWorkType;
import com.dsp.crusher.entity.Vehicle;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.MachineRepository;
import com.dsp.crusher.repository.MachineWorkLogRepository;
import com.dsp.crusher.repository.MachineWorkTypeRepository;
import com.dsp.crusher.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MachineService {

    private final MachineRepository        repo;
    private final MachineWorkTypeRepository workTypeRepo;
    private final VehicleRepository         vehicleRepo;
    private final MachineWorkLogRepository  workLogRepo;

    public List<MachineResponse> listActive() {
        return buildResponses(repo.findByStatusAndIsActiveTrue("ACTIVE"));
    }

    public List<MachineResponse> listAll() {
        return buildResponses(repo.findByStatus("ACTIVE"));
    }

    public MachineResponse getById(Long id) {
        Machine m = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Machine not found: " + id));
        return buildResponses(List.of(m)).get(0);
    }

    @Transactional
    public MachineResponse create(MachineRequest req) {
        Machine m = new Machine();
        m.setTenantId(TenantContext.get());
        applyToMachine(m, req);
        m = repo.save(m);
        syncVehicleLink(null, req.getLinkedVehicleId(), m.getId());
        saveWorkTypes(m.getId(), req.getWorkTypes());
        return getById(m.getId());
    }

    @Transactional
    public MachineResponse update(Long id, MachineRequest req) {
        Machine m = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Machine not found: " + id));
        Long oldLinkedVehicleId = m.getLinkedVehicleId();
        applyToMachine(m, req);
        repo.save(m);
        syncVehicleLink(oldLinkedVehicleId, req.getLinkedVehicleId(), id);
        replaceWorkTypes(id, req.getWorkTypes());
        return getById(id);
    }

    @Transactional
    public MachineResponse toggleActive(Long id) {
        Machine m = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Machine not found: " + id));
        m.setActive(!m.isActive());
        repo.save(m);
        return getById(id);
    }

    @Transactional
    public void deactivate(Long id) {
        Machine m = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Machine not found: " + id));
        if (m.getLinkedVehicleId() != null) {
            Vehicle v = vehicleRepo.findById(m.getLinkedVehicleId()).orElse(null);
            if (v != null && "ACTIVE".equals(v.getStatus())) {
                throw new IllegalStateException(
                    "Machine is linked to vehicle '" + vehicleLabel(v) + "'. " +
                    "Remove the link in Machine settings before deleting.");
            }
        }
        if (workLogRepo.existsByMachineId(id)) {
            throw new IllegalStateException(
                "This machine has historical work log entries. " +
                "Use the Active/Inactive toggle to hide it instead of deleting.");
        }
        m.setStatus("INACTIVE");
        repo.save(m);
    }

    // ── Work type helpers ────────────────────────────────────────────────────

    private void saveWorkTypes(Long machineId, List<MachineWorkTypeDto> types) {
        if (types == null || types.isEmpty()) return;
        for (int i = 0; i < types.size(); i++) {
            MachineWorkTypeDto dto = types.get(i);
            MachineWorkType wt = new MachineWorkType();
            wt.setTenantId(TenantContext.get());
            wt.setMachineId(machineId);
            dto.setDisplayOrder(i);
            applyToWorkType(wt, dto);
            workTypeRepo.save(wt);
        }
    }

    private void replaceWorkTypes(Long machineId, List<MachineWorkTypeDto> types) {
        if (types == null) return;
        List<MachineWorkType> existing =
                workTypeRepo.findByMachineIdAndStatusOrderByDisplayOrderAsc(machineId, "ACTIVE");

        Set<Long> toKeep = new HashSet<>();
        for (int i = 0; i < types.size(); i++) {
            MachineWorkTypeDto dto = types.get(i);
            dto.setDisplayOrder(i);
            if (dto.getId() != null) {
                existing.stream()
                        .filter(w -> w.getId().equals(dto.getId()))
                        .findFirst()
                        .ifPresent(w -> {
                            applyToWorkType(w, dto);
                            workTypeRepo.save(w);
                            toKeep.add(w.getId());
                        });
            } else {
                MachineWorkType wt = new MachineWorkType();
                wt.setTenantId(TenantContext.get());
                wt.setMachineId(machineId);
                applyToWorkType(wt, dto);
                workTypeRepo.save(wt);
            }
        }
        // Deactivate work types removed from the list
        existing.stream()
                .filter(w -> !toKeep.contains(w.getId()))
                .forEach(w -> {
                    w.setStatus("INACTIVE");
                    workTypeRepo.save(w);
                });
    }

    private void applyToWorkType(MachineWorkType wt, MachineWorkTypeDto dto) {
        wt.setLabel(dto.getLabel());
        wt.setDefaultRate(dto.getDefaultRate());
        wt.setDefaultGstRate(dto.getDefaultGstRate());
        wt.setSacCode(dto.getSacCode());
        wt.setDisplayOrder(dto.getDisplayOrder());
    }

    // ── Vehicle link sync ────────────────────────────────────────────────────

    private void syncVehicleLink(Long oldVehicleId, Long newVehicleId, Long machineId) {
        // Clear the back-link on the previously linked vehicle
        if (oldVehicleId != null && !oldVehicleId.equals(newVehicleId)) {
            vehicleRepo.findById(oldVehicleId).ifPresent(v -> {
                if (machineId.equals(v.getLinkedMachineId())) {
                    v.setLinkedMachineId(null);
                    vehicleRepo.save(v);
                }
            });
        }
        // Set the back-link on the newly linked vehicle
        if (newVehicleId != null) {
            vehicleRepo.findById(newVehicleId).ifPresent(v -> {
                v.setLinkedMachineId(machineId);
                vehicleRepo.save(v);
            });
        }
    }

    // ── Response builder ─────────────────────────────────────────────────────

    private List<MachineResponse> buildResponses(List<Machine> machines) {
        if (machines.isEmpty()) return List.of();
        List<Long> ids = machines.stream().map(Machine::getId).collect(Collectors.toList());
        Map<Long, List<MachineWorkType>> typesByMachine =
                workTypeRepo.findByMachineIdInAndStatus(ids, "ACTIVE").stream()
                        .collect(Collectors.groupingBy(MachineWorkType::getMachineId));

        List<Long> vehicleIds = machines.stream()
                .map(Machine::getLinkedVehicleId).filter(Objects::nonNull)
                .distinct().collect(Collectors.toList());
        Map<Long, Vehicle> vehiclesById = vehicleIds.isEmpty() ? Map.of() :
                vehicleRepo.findAllById(vehicleIds).stream()
                        .collect(Collectors.toMap(Vehicle::getId, v -> v));

        return machines.stream().map(m -> {
            MachineResponse r = new MachineResponse();
            r.setId(m.getId());
            r.setTenantId(m.getTenantId());
            r.setOwner(m.getOwner());
            r.setVendorId(m.getVendorId());
            r.setName(m.getName());
            r.setMachineType(m.getMachineType());
            r.setStatus(m.getStatus());
            r.setActive(m.isActive());
            r.setLinkedVehicleId(m.getLinkedVehicleId());
            if (m.getLinkedVehicleId() != null) {
                Vehicle v = vehiclesById.get(m.getLinkedVehicleId());
                if (v != null) r.setLinkedVehicleName(vehicleLabel(v));
            }
            List<MachineWorkTypeDto> wts = typesByMachine.getOrDefault(m.getId(), List.of())
                    .stream()
                    .sorted(Comparator.comparingInt(MachineWorkType::getDisplayOrder))
                    .map(this::toDto)
                    .collect(Collectors.toList());
            r.setWorkTypes(wts);
            return r;
        }).collect(Collectors.toList());
    }

    private MachineWorkTypeDto toDto(MachineWorkType wt) {
        MachineWorkTypeDto dto = new MachineWorkTypeDto();
        dto.setId(wt.getId());
        dto.setLabel(wt.getLabel());
        dto.setDefaultRate(wt.getDefaultRate());
        dto.setDefaultGstRate(wt.getDefaultGstRate());
        dto.setSacCode(wt.getSacCode());
        dto.setDisplayOrder(wt.getDisplayOrder());
        return dto;
    }

    private void applyToMachine(Machine m, MachineRequest req) {
        m.setOwner(req.getOwner());
        m.setVendorId(req.getVendorId());
        m.setName(req.getName());
        m.setMachineType(req.getMachineType());
        m.setLinkedVehicleId(req.getLinkedVehicleId());
    }

    private String vehicleLabel(Vehicle v) {
        return v.getDisplayName() != null && !v.getDisplayName().isBlank()
                ? v.getPlateNumber() + " (" + v.getDisplayName() + ")"
                : v.getPlateNumber();
    }
}
