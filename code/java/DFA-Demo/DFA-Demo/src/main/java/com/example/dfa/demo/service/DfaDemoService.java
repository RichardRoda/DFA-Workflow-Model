/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.example.dfa.demo.service;

import com.example.dfa.demo.dto.DfaFindDTO;
import com.example.dfa.demo.dto.DfaWorkflowDetailDTO;
import com.example.dfa.demo.dto.DfaWorkflowsDTO;
import com.example.dfa.demo.dto.NextEventDTO;
import java.util.Collection;

/**
 *
 * @author rodare
 */
public interface DfaDemoService {

    Collection<DfaWorkflowsDTO> findWorkflows(DfaFindDTO criteria);

    DfaWorkflowDetailDTO getWorkflowDetail(Long dfaWorkflowId);

    NextEventDTO processWorkflowEvent(NextEventDTO nextEvent);
    
}
