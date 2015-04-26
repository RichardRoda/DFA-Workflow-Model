/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.example.dfa.demo.mvc;

import com.example.dfa.demo.dto.DfaFindDTO;
import com.example.dfa.demo.dto.DfaWorkflowDetailDTO;
import com.example.dfa.demo.dto.DfaWorkflowsDTO;
import com.example.dfa.demo.dto.NextEventDTO;
import com.example.dfa.demo.dto.SelectedEventsDTO;
import com.example.dfa.demo.service.DfaDemoService;
import java.util.Collection;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

/**
 *
 * @author Richard
 */
@Controller
public class WorkflowDetail {
    
    @Autowired DfaDemoService dfaDemoService;
    
    @RequestMapping(value="/workflowDetail", method=RequestMethod.GET)
    public String findWorkflows(@ModelAttribute("nextEvent") NextEventDTO nextEvent, Map<String,Object> model) {
        DfaWorkflowDetailDTO detailDTO = dfaDemoService.getWorkflowDetail(nextEvent.getDfaWorkflowId());
        model.put("workflows", detailDTO.getWorkflows());
        model.put("states", detailDTO.getWorkflowStates());
        model.put("events", detailDTO.getSelectedEvents());
        model.put("dfaWorkflowId", nextEvent.getDfaWorkflowId());
        model.put("employeeId", nextEvent.getEmployeeId());
        return "displayWorkflowDetail";
    } 
    
   @RequestMapping(value="/workflowDetail", method=RequestMethod.POST)
    public String applyEvent(@ModelAttribute("nextEvent") NextEventDTO nextEvent) {
        NextEventDTO result = dfaDemoService.processWorkflowEvent(nextEvent);
        return "redirect:/workflowDetail.htm?employeeId="+nextEvent.getEmployeeId() + "&dfaWorkflowId="+result.getDfaWorkflowId()+"&dfaStateId="+result.getDfaStateId();
    }
}
