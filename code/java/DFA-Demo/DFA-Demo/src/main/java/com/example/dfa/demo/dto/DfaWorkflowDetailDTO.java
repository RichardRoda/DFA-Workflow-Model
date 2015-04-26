/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.example.dfa.demo.dto;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

/**
 *
 * @author Richard
 */
public class DfaWorkflowDetailDTO implements Serializable {
    final List<DfaWorkflowsDTO> workflows;
    final Collection<SelectedEventsDTO> selectedEvents;
    final Collection<WorkflowStatesDTO> workflowStates;

    public DfaWorkflowDetailDTO(final Long dfaWorkflowId, Collection<DfaWorkflowsDTO> workflows, Collection<SelectedEventsDTO> selectedEvents, Collection<WorkflowStatesDTO> workflowStates) {
        this.workflows = new ArrayList<>(workflows);
        this.selectedEvents = selectedEvents;
        this.workflowStates = workflowStates;
        final Comparator<DfaWorkflowsDTO> workflowSorter = new Comparator<DfaWorkflowsDTO>() {

            @Override
            public int compare(DfaWorkflowsDTO o1, DfaWorkflowsDTO o2) {
                int diff = (dfaWorkflowId.equals(o2) ? 1 : 0) - (dfaWorkflowId.equals(o1) ? 1 : 0);
                if (diff != 0) {
                    return diff;
                }
                diff = o1.getWorkflowTx().compareTo(o2.getWorkflowTx());
                if (diff != 0) {
                    return diff;
                }
                return o1.getDfaWorkflowId().compareTo(o2.getDfaWorkflowId());
            }
        };
            Collections.sort(this.workflows, workflowSorter);
    }

    public List<DfaWorkflowsDTO> getWorkflows() {
        return workflows;
    }

    public Collection<SelectedEventsDTO> getSelectedEvents() {
        return selectedEvents;
    }

    public Collection<WorkflowStatesDTO> getWorkflowStates() {
        return workflowStates;
    }


}
