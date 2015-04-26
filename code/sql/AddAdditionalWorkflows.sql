
drop procedure if exists demo_employee.sp_setupEmployeeConstraints;
delimiter GO
create procedure demo_employee.sp_setupEmployeeConstraints(dfaWorkflowId BIGINT UNSIGNED) 
	MODIFIES SQL DATA	
BEGIN
IF dfaWorkflowId IS NOT NULL and NOT EXISTS (select * from dfa.session_dfa_workflow_state where DFA_WORKFLOW_ID = dfaWorkflowId) THEN
	insert into dfa.session_dfa_workflow_state (DFA_WORKFLOW_ID, DFA_STATE_ID, OUTPUT)
	VALUES (dfaWorkflowId, 1, 0);
END IF;

insert into dfa.session_dfa_field_value (DFA_WORKFLOW_ID, FIELD_ID,INT_VALUE)
select epw.DFA_WORKFLOW_ID, 5, ep.SALARY 
from dfa.session_dfa_workflow_state sdfs 
	JOIN demo_employee.EMPLOYEE_PROSPECT_WORKFLOW epw ON epw.DFA_WORKFLOW_ID = sdfs.DFA_WORKFLOW_ID
	JOIN demo_employee.EMPLOYEE_PROSPECT ep ON epw.EMPLOYEE_ID = ep.EMPLOYEE_ID
	WHERE ep.SALARY IS NOT NULL AND (dfaWorkflowId IS NULL OR sdfs.DFA_WORKFLOW_ID = dfaWorkflowId);
		
END GO
delimiter ;

