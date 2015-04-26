/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.example.dfa.demo.mvc;

import com.example.dfa.demo.dto.EmployeeProspectDTO;
import com.example.dfa.demo.service.DfaDemoService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;

/**
 *
 * @author Richard
 */
@Controller
@RequestMapping("/addNewEmployeeProspect")
public class AddNewEmployeeProspect {
    @Autowired DfaDemoService dfaDemoService;
    
    @RequestMapping(method=RequestMethod.POST)    
    public String addNewEmployeeProspect(@ModelAttribute("employeeProspect") EmployeeProspectDTO newEmployee) {
        dfaDemoService.addNewProspect(newEmployee);
        return "redirect:/findWorkflows.htm";
    }

    @RequestMapping(method=RequestMethod.GET)    
    public String addNewEmployeeProspectDisplay(@ModelAttribute("employeeProspect") EmployeeProspectDTO newEmployee) {
        return "newEmployeeProspect";
    }
}
