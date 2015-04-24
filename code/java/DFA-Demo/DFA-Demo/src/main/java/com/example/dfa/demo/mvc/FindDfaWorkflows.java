/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.example.dfa.demo.mvc;

import com.example.dfa.demo.dto.DfaFindDTO;
import com.example.dfa.demo.dto.DfaWorkflowsDTO;
import com.example.dfa.demo.service.DfaDemoService;
import java.util.Collection;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;

/**
 *
 * @author rodare
 */
@RequestMapping("/findWorkflows")
@Controller
public class FindDfaWorkflows {
    @Autowired DfaDemoService dfaDemoService;
    
    @RequestMapping(method=RequestMethod.GET)
    public String findWorkflows(@ModelAttribute DfaFindDTO query, Map<String,Object> model) {
        Collection<DfaWorkflowsDTO> workflows = dfaDemoService.findWorkflows(query);
        model.put("workflows", workflows);
        return "displayWorkflowList";
    } 
}
